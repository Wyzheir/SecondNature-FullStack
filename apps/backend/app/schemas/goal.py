from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from decimal import Decimal

class GoalType(str, Enum):
    LOSE = "LOSE"          # 减脂
    MAINTAIN = "MAINTAIN"  # 维持
    GAIN = "GAIN"          # 增肌


from pydantic import BaseModel, Field



class GoalCreateRequest(BaseModel):
    gender: int = Field(..., ge=1, le=2, description="1: 男, 2: 女")

    # 🌟 物理常数约束升级
    age: int = Field(..., ge=12, le=100, description="年龄 (12-100)")

    height: float = Field(..., ge=100.0, le=250.0, description="身高 cm")

    weight: float = Field(..., ge=30.0, le=300.0, description="当前体重 kg")

    target_weight: float = Field(..., ge=30.0, le=300.0, description="目标体重 kg")

    activity_level: float = Field(
        default=1.2,
        ge=1.2,
        le=2.5,
        description="活动系数 (1.2-2.5)"
    )

    goal_type: str = Field(..., description="LOSE | MAINTAIN | GAIN")


class GoalResponse(BaseModel):
    """
    算力中心输出结果（包含宏量营养素建议）
    """
    bmr: float
    tdee: float
    recommended_diet_kcal: float
    recommended_exercise_mins: int
    bmi: float
    status: str = "Healthy"

    # 🌟 新增：三大宏量营养素推荐摄入量 (克)
    carbs_g: float = Field(..., description="推荐碳水摄入量(g)")
    protein_g: float = Field(..., description="推荐蛋白摄入量(g)")
    fat_g: float = Field(..., description="推荐脂肪摄入量(g)")


class GoalCalcData(BaseModel):
    """
    前端仪表盘渲染所需的核心指标
    """
    user_id: str = Field(..., description="用户ID")
    target_kcal: float = Field(..., description="目标热量(kcal)")
    carbs_g: float = Field(..., description="推荐碳水摄入量(g)")
    protein_g: float = Field(..., description="推荐蛋白摄入量(g)")
    fat_g: float = Field(..., description="推荐脂肪摄入量(g)")

class GoalStandardResponse(BaseModel):
    """
    生理画像录入 - 标准统一返回外壳
    """
    code: int = Field(default=200)
    message: str = Field(default="success")
    data: GoalCalcData


