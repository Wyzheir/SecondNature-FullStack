"""
app/api/v1/records.py

核心数据流向：客户端批量推送打卡或查询图表请求 -> API 层校验模型完整性 -> 交接至 record_service 执行库级事务 -> 格式化输出。
核心逻辑：利用 Depends 自动抽取当前执行人身份，调度底层服务的单事务批处理（Batch Upsert）及按日时间维度的数据降维聚合逻辑。
具体职责：打卡流水总控接口，承担高频核心业务的端云全量同步任务及仪表盘数据可视化所需的指标分发。
"""

from datetime import date
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc

from app.schemas.record import (
    BatchSyncRecordRequest, BatchSyncResponse,
    StatisticsResponse, StatisticsData, RecordSyncResponse
)
from app.services.record_service import batch_sync_records, get_daily_statistics
from app.models.record import HealthRecord
from app.api.deps import get_db
from app.core.security import get_current_user

router = APIRouter()

@router.post("/batch_sync", response_model=BatchSyncResponse)
async def sync_health_records(
    request: BatchSyncRecordRequest,
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    # 💡 增加 await
    return await batch_sync_records(db=db, request=request, user_id=current_user)

@router.get("", response_model=RecordSyncResponse)
async def get_user_records(
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    # 💡 异步 Select 拉取
    result = await db.execute(
        select(HealthRecord)
        .where(HealthRecord.user_id == current_user)
        .order_by(desc(HealthRecord.record_date))
    )
    records = result.scalars().all()

    if not records:
        return JSONResponse(status_code=200, content={"code": 200, "message": "获取成功", "data": []})

    response_data = []
    for r in records:
        response_data.append({
            "client_msg_id": str(r.client_msg_id),
            "record_type": r.record_type,
            "record_value": float(r.record_value or 0.0),
            "unit": r.unit,
            "duration": float(r.duration) if r.duration is not None else None,
            "meal_type": r.meal_type,
            "food_name": r.food_name,
            "carbs_g": float(r.carbs_g) if r.carbs_g is not None else None,
            "protein_g": float(r.protein_g) if r.protein_g is not None else None,
            "fat_g": float(r.fat_g) if r.fat_g is not None else None,
            "record_date": r.record_date.strftime('%Y-%m-%dT%H:%M:%S'),
            "notes": r.notes
        })

    return JSONResponse(status_code=200, content={"code": 200, "message": "获取成功", "data": response_data})

@router.get("/statistics", response_model=StatisticsResponse)
async def get_statistics(
    start_date: date = Query(...),
    end_date: date = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    try:
        # 💡 增加 await
        result = await get_daily_statistics(db=db, user_id=current_user, start_date=start_date, end_date=end_date)
        return StatisticsResponse(message="统计聚合完成", data=StatisticsData(**result))
    except ValueError as e:
        return JSONResponse(status_code=400, content={"code": 400, "message": str(e), "data": None})