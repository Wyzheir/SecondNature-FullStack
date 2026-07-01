import logging
from datetime import date
from decimal import Decimal
from typing import Dict, Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func, case, cast, Date, select, desc, update

from app.models.record import HealthRecord
from app.models.user import UserProfile
from app.schemas.record import BatchSyncRecordRequest, BatchSyncResponse, SyncResultData
from app.schemas.goal import GoalCreateRequest
from app.services.goal_service import calculate_health_strategy
from app.core.exceptions import HealthRiskException

logger = logging.getLogger(__name__)


# --- 1. 批量同步逻辑（重构后：单事务内完成记录同步 + 连带目标重算）---
async def batch_sync_records(
    db: AsyncSession,
    request: BatchSyncRecordRequest,
    user_id: str
) -> BatchSyncResponse:
    """
    批量同步健康记录，并在单数据库事务内完成以下操作：
    1. 对每条记录按 client_msg_id 执行 Upsert（新增或更新）
    2. 若批次中包含体重记录，则立刻重算用户每日营养目标并写回 UserProfile
    3. 统一提交。任何环节失败均触发整体回滚，保证数据一致性。

    异常处理：
    - 目标重算时若 BMI 过低等健康风险触发 HealthRiskException，会原样抛出，
      由全局异常处理器返回 {"code": 400, "message": "..."} 给前端。
    - 其他异常也会导致回滚并重新抛出，返回 500。
    """
    synced_count = 0
    incoming_ids = [str(r.client_msg_id) for r in request.records]

    # 查询已存在的记录 ID（用于判断新增/更新）
    stmt = select(HealthRecord).where(HealthRecord.client_msg_id.in_(incoming_ids))
    result = await db.execute(stmt)
    existing_ids = {r.client_msg_id for r in result.scalars().all()}

    has_weight_in_batch = False

    # 第一步：逐条处理记录 Upsert（先不提交）
    for item in request.records:
        client_id_str = str(item.client_msg_id)
        if item.record_type == "WEIGHT":
            has_weight_in_batch = True

        if client_id_str in existing_ids:
            # 更新已有记录
            upd_stmt = (
                update(HealthRecord)
                .where(HealthRecord.client_msg_id == client_id_str)
                .values(
                    record_value=item.record_value,
                    duration=item.duration,
                    meal_type=item.meal_type,
                    food_name=item.food_name,
                    carbs_g=item.carbs_g,
                    protein_g=item.protein_g,
                    fat_g=item.fat_g,
                    notes=item.notes,
                    record_date=item.record_date
                )
            )
            await db.execute(upd_stmt)
        else:
            # 新增记录
            new_rec = HealthRecord(
                client_msg_id=client_id_str,
                user_id=user_id,
                record_type=item.record_type,
                record_value=item.record_value,
                unit=item.unit,
                duration=item.duration,
                meal_type=item.meal_type,
                food_name=item.food_name,
                carbs_g=item.carbs_g,
                protein_g=item.protein_g,
                fat_g=item.fat_g,
                record_date=item.record_date,
                notes=item.notes
            )
            db.add(new_rec)
        synced_count += 1

    # 第二步：若包含体重记录，在同一事务内执行连带目标重算
    if has_weight_in_batch:
        try:
            # 2.1 查询当前用户最新的体重记录（刚刚插入/更新的那条会在结果内）
            weight_stmt = (
                select(HealthRecord)
                .where(
                    HealthRecord.user_id == user_id,
                    HealthRecord.record_type == "WEIGHT"
                )
                .order_by(desc(HealthRecord.record_date))
                .limit(1)
            )
            weight_res = await db.execute(weight_stmt)
            latest_weight_record = weight_res.scalars().first()

            # 2.2 获取用户档案（需要身高、性别等静态数据）
            profile_res = await db.execute(
                select(UserProfile).where(UserProfile.user_id == user_id)
            )
            user_profile = profile_res.scalars().first()

            # 防御性检查：缺少必要数据则跳过重算
            if not latest_weight_record or not user_profile:
                logger.warning(f"体重记录或用户档案缺失，跳过目标重算 user={user_id}")
            elif not user_profile.height or not user_profile.gender:
                logger.warning(f"用户 {user_id} 缺少身高或性别，无法重算目标")
            else:
                # 记录体重变化（用于日志）
                old_weight = user_profile.weight  # Decimal 或 None
                new_weight = latest_weight_record.record_value
                weight_change = (
                    float(new_weight - old_weight) if old_weight is not None else 0.0
                )

                # 2.3 构造临时请求，调用 Mifflin-St Jeor 公式重算
                safe_target_weight = getattr(user_profile, 'target_weight', None)
                safe_goal_type = getattr(user_profile, 'goal_type', "MAINTAIN")

                engine_req = GoalCreateRequest(
                    gender=user_profile.gender,
                    age=user_profile.age,
                    height=float(user_profile.height),
                    weight=float(new_weight),
                    target_weight=float(safe_target_weight or new_weight),
                    activity_level=float(getattr(user_profile, 'activity_level', 1.2)),
                    goal_type=safe_goal_type
                )

                new_targets = calculate_health_strategy(engine_req)

                # 2.4 将结果写回 UserProfile（同一 Session，尚未提交）
                user_profile.weight = new_weight
                user_profile.target_kcal = new_targets["recommended_diet_kcal"]
                user_profile.carbs_g = new_targets["carbs_g"]
                user_profile.protein_g = new_targets["protein_g"]
                user_profile.fat_g = new_targets["fat_g"]

                logger.info(
                    f"体重更新触发目标重算: user_id={user_id}, "
                    f"体重变化 {weight_change:+.1f}kg, "
                    f"新目标热量={new_targets['recommended_diet_kcal']}kcal"
                )

        except HealthRiskException:
            # 健康风控异常：原样抛出，由全局 handler 返回 400
            await db.rollback()
            raise
        except Exception as e:
            # 其他异常：回滚并抛出，最终返回 500
            logger.error(f"目标重算失败 user={user_id}: {e}")
            await db.rollback()
            raise

    # 第三步：统一提交整个事务（记录 Upsert + 可能的目标更新）
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        raise

    return BatchSyncResponse(
        message="同步完成",
        data=SyncResultData(synced_count=synced_count, skipped_count=0)
    )


# --- 2. 统计聚合逻辑（无变化）---
async def get_daily_statistics(
    db: AsyncSession,
    user_id: str,
    start_date: date,
    end_date: date
) -> Dict[str, Any]:
    """完全异步化的多列聚合函数"""
    if (end_date - start_date).days > 30:
        raise ValueError("查询跨度不能超过30天")
    if start_date > end_date:
        raise ValueError("开始日期不能晚于结束日期")

    date_expr = cast(HealthRecord.record_date, Date)
    actual_exercise_duration = func.coalesce(HealthRecord.duration, HealthRecord.record_value)
    actual_sleep_duration = func.coalesce(HealthRecord.duration, HealthRecord.record_value)

    stmt = (
        select(
            date_expr.label("stat_date"),
            func.sum(case(
                (HealthRecord.record_type == "DIET", HealthRecord.record_value), else_=0
            )).label("total_diet"),
            func.sum(case(
                (HealthRecord.record_type == "EXERCISE", actual_exercise_duration), else_=0
            )).label("total_exercise"),
            func.sum(case(
                (HealthRecord.record_type == "SLEEP", actual_sleep_duration), else_=0
            )).label("total_sleep"),
            func.sum(case(
                (HealthRecord.record_type == "DIET", HealthRecord.carbs_g), else_=0
            )).label("total_carbs"),
            func.sum(case(
                (HealthRecord.record_type == "DIET", HealthRecord.protein_g), else_=0
            )).label("total_protein"),
            func.sum(case(
                (HealthRecord.record_type == "DIET", HealthRecord.fat_g), else_=0
            )).label("total_fat"),
        )
        .where(
            HealthRecord.user_id == user_id,
            date_expr >= start_date,
            date_expr <= end_date,
        )
        .group_by(date_expr)
        .order_by(date_expr.asc())
    )

    result = await db.execute(stmt)
    rows = result.all()

    stats_list = []
    for row in rows:
        stats_list.append({
            "date": row.stat_date,
            "diet_kcal": row.total_diet or Decimal("0.00"),
            "exercise_mins": row.total_exercise or Decimal("0.00"),
            "sleep_hours": row.total_sleep or Decimal("0.00"),
            "carbs_g": row.total_carbs or Decimal("0.00"),
            "protein_g": row.total_protein or Decimal("0.00"),
            "fat_g": row.total_fat or Decimal("0.00"),
        })

    return {"synced_days": len(stats_list), "statistics": stats_list}