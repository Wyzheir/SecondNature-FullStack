"""
app/schemas/assistant.py

定义助手模块所有的请求/响应数据契约。
已扩展支持图像上传、地区信息、用户姓名、今日饮食/运动/睡眠明细，均为可选字段，不影响旧客户端。
"""

from pydantic import BaseModel, Field, AliasChoices
from typing import List, Optional
from datetime import datetime


class DietItem(BaseModel):
    """单条饮食记录，由前端从本地数据库组装并上报"""
    food_name: str = Field(..., description="食物名称")
    meal_type: str = Field(..., description="餐别: BREAKFAST/LUNCH/DINNER/SNACK")
    record_value: float = Field(..., ge=0, description="热量(kcal)")
    carbs_g: Optional[float] = Field(None, ge=0, description="碳水(g)")
    protein_g: Optional[float] = Field(None, ge=0, description="蛋白质(g)")
    fat_g: Optional[float] = Field(None, ge=0, description="脂肪(g)")


class ExerciseItem(BaseModel):
    """单条运动记录，由前端组装并上报"""
    exercise_name: str = Field(..., description="运动名称")
    duration: float = Field(
        ...,
        validation_alias=AliasChoices('duration', 'duration_min'),   # 👈 同时接受两个名称
        ge=0,
        description="运动时长（分钟）"
    )
    burn_kcal: Optional[float] = Field(
        None,
        validation_alias=AliasChoices('burn_kcal', 'burn_kcal_min'),  # 同理，如果需要
        ge=0,
        description="消耗热量（kcal）"
    )


class ContextData(BaseModel):
    """前端状态机注入的真实生理流水上下文"""
    target_kcal: float = Field(..., description="目标热量(kcal)")
    current_weight: float = Field(..., description="当前体重(kg)")
    recent_diet_kcal: float = Field(..., description="今日已摄入饮食(kcal)")
    recent_burn_kcal: float = Field(..., description="今日已运动消耗(kcal)")
    # 可选字段，用于个性化称呼和地区匹配
    name: Optional[str] = Field(None, description="用户称呼，不传则默认使用'用户'")
    locale: Optional[str] = Field(None, description="地区码，如 zh-CN，用于匹配心理援助热线")
    # 今日明细
    today_diet_items: Optional[List[DietItem]] = Field(None, description="今日饮食明细（最多15条）")
    today_exercise_items: Optional[List[ExerciseItem]] = Field(None, description="今日运动明细（最多10条）")
    today_sleep_hours: Optional[float] = Field(None, ge=0, description="今日睡眠总时长（小时）")


class ChatRequest(BaseModel):
    """前端发起的聊天请求，支持文本和可选的图片、地区信息"""
    session_id: str = Field(..., description="当前的会话ID(UUID)")
    message: str = Field(..., min_length=1, max_length=1000, description="用户的提问")
    context: ContextData = Field(..., description="前端注入的健康状态上下文")
    # 可选字段
    image_url: Optional[str] = Field(None, description="用户上传的图片链接(base64或URL)，用于多模态分析")
    locale: Optional[str] = Field(None, description="用户地区码，用于匹配心理援助资源，不传则默认 zh-CN")


class ChatMessageItem(BaseModel):
    """单条消息格式契约"""
    content: str
    is_user: bool


class ChatHistoryResponse(BaseModel):
    """单场会话的历史流水记录返回外壳"""
    code: int = Field(default=200)
    message: str = Field(default="success")
    data: List[ChatMessageItem]


class SessionCreateResponse(BaseModel):
    """创建新话题成功后的响应"""
    code: int = Field(default=200)
    message: str = Field(default="新话题创建成功")
    session_id: str = Field(..., description="后端签发或确认的会话ID")


class SessionListItem(BaseModel):
    """单个历史话题的摘要信息"""
    session_id: str
    title: str
    updated_at: datetime


class SessionListResponse(BaseModel):
    """话题列表返回外壳"""
    code: int = Field(default=200)
    message: str = Field(default="success")
    data: List[SessionListItem]