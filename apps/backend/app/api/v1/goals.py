"""
app/api/v1/goals.py

核心数据流向：接收生理画像表单 -> 传入 goal_service 引擎解析计算 -> 得到 BMR/TDEE 等营养指标 -> 异步更新回写 UserProfile 表 -> 响应前端。
核心逻辑：桥接业务算力中心与数据库持久层，支持用户体征更新与动态目标回写同步，支持画像只读下发。
具体职责：用户核心健康策略暴露层，处理个人目标设定、画像留存以及量化指标拉取。
"""
from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.api.deps import get_db
from app.core.security import get_current_user
from app.schemas.goal import GoalCreateRequest, GoalStandardResponse, GoalCalcData
from app.services.goal_service import calculate_health_strategy
from app.models.user import UserProfile

router = APIRouter()

@router.post("/calculate_and_save", response_model=GoalStandardResponse)
async def save_user_goal(
        request: GoalCreateRequest,
        db: AsyncSession = Depends(get_db), # 💡 异步 Session
        current_user: str = Depends(get_current_user)
):
    results = calculate_health_strategy(request)

    # 💡 SQLAlchemy 2.0 异步 Update 语法
    stmt = (
        update(UserProfile)
        .where(UserProfile.user_id == current_user)
        .values(
            gender=request.gender,
            age=request.age,
            height=request.height,
            weight=request.weight,
            activity_level=request.activity_level,
            goal_type=request.goal_type,
            target_kcal=results["recommended_diet_kcal"],
            carbs_g=results["carbs_g"],
            protein_g=results["protein_g"],
            fat_g=results["fat_g"]
        )
    )
    await db.execute(stmt)
    await db.commit() # 💡 异步提交

    return GoalStandardResponse(
        code=200,
        message="success",
        data=GoalCalcData(
            user_id=current_user,
            target_kcal=results["recommended_diet_kcal"],
            carbs_g=results["carbs_g"],
            protein_g=results["protein_g"],
            fat_g=results["fat_g"]
        )
    )

@router.get("/")
async def get_user_goal(
        db: AsyncSession = Depends(get_db),
        current_user: str = Depends(get_current_user)
):
    # 💡 异步 Select 语法
    result = await db.execute(select(UserProfile).where(UserProfile.user_id == current_user))
    user = result.scalars().first()

    if not user or user.weight is None:
        return JSONResponse(status_code=200, content={"code": 200, "message": "尚未填写生理画像", "data": None})

    return JSONResponse(
        status_code=200,
        content={
            "code": 200,
            "message": "success",
            "data": {
                "user_id": current_user,
                "gender": user.gender,
                "age": user.age,
                "height": float(user.height or 0.0),
                "weight": float(user.weight or 0.0),
                "activity_level": float(user.activity_level or 1.2),
                "goal_type": user.goal_type,
                "target_kcal": float(user.target_kcal or 0.0),
                "carbs_g": float(user.carbs_g or 0.0),
                "protein_g": float(user.protein_g or 0.0),
                "fat_g": float(user.fat_g or 0.0)
            }
        }
    )