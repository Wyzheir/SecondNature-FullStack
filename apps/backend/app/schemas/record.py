from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional, Literal
from uuid import UUID
from decimal import Decimal
from datetime import datetime, date as dt_date

# --- 1. 基础原子模型 (核心字段) ---
class RecordBase(BaseModel):
    """
    健康记录的基础字段，确保所有相关模型字段对齐
    """
    record_type: Literal["DIET", "EXERCISE", "SLEEP", "WEIGHT"] = Field(..., description="记录类型")
    record_value: Decimal = Field(..., ge=0, max_digits=10, decimal_places=2)
    unit: str = Field(..., max_length=10, description="单位：如 kcal, hours")
    record_date: datetime = Field(..., description="业务发生的实际时间 (UTC ISO8601)")
    notes: Optional[str] = Field(None, max_length=255, description="备注信息")
    duration: Optional[Decimal] = Field(None, ge=0, description="补充时长（主要用于运动）")
    # 🌟 新增：精细化饮食打卡契约
    meal_type: Optional[str] = Field(None, max_length=20, description="餐别，如 BREAKFAST")
    food_name: Optional[str] = Field(None, max_length=100, description="食物名称")
    carbs_g: Optional[Decimal] = Field(None, ge=0, max_digits=6, decimal_places=2, description="碳水(g)")
    protein_g: Optional[Decimal] = Field(None, ge=0, max_digits=6, decimal_places=2, description="蛋白质(g)")
    fat_g: Optional[Decimal] = Field(None, ge=0, max_digits=6, decimal_places=2, description="脂肪(g)")

# --- 2. 写入/同步请求契约 (前端 -> 后端) ---
class RecordCreateItem(RecordBase):
    """
    单条打卡记录入参：登记员模式核心，必须携带 UUID
    """
    # 使用 UUID 类型确保前端传来的 36 位字符串格式合法
    client_msg_id: UUID = Field(..., description="前端生成的唯一UUID，作为物理主键")

class BatchSyncRecordRequest(BaseModel):
    """
    批量同步请求：去掉 user_id，改由后端从 Token 自动注入
    """
    records: List[RecordCreateItem] = Field(
        ...,
        min_length=1,
        max_length=100,
        description="打卡记录列表，单次同步上限100条"
    )

# --- 3. 响应反馈契约 (后端 -> 前端) ---
class SyncResultData(BaseModel):
    """
    同步结果统计详情
    """
    synced_count: int = Field(0, description="成功入库的数量")
    skipped_count: int = Field(0, description="因重复(幂等)被跳过的数量")

class BatchSyncResponse(BaseModel):
    """
    批量同步响应外壳
    """
    code: int = Field(default=200)
    message: str
    data: SyncResultData

# --- 4. 统计报表契约 (分析引擎专用) ---
class DailyStatisticItem(BaseModel):
    """
    单日数据聚合单元，专为前端折线图量身定制
    """
    date: dt_date = Field(..., description="统计日期 (YYYY-MM-DD)")
    diet_kcal: Decimal = Field(default=Decimal("0.00"), description="当日总饮食摄入")
    exercise_mins: Decimal = Field(default=Decimal("0.00"), description="当日总运动消耗/时长")
    carbs_g: Decimal = Field(default=Decimal("0.00"), description="当日总碳水(g)")
    protein_g: Decimal = Field(default=Decimal("0.00"), description="当日总蛋白(g)")
    fat_g: Decimal = Field(default=Decimal("0.00"), description="当日总脂肪(g)")

class StatisticsData(BaseModel):
    """
    统计数据包装体
    """
    synced_days: int = Field(..., description="实际跨越的天数")
    statistics: List[DailyStatisticItem] = Field(..., description="按天聚合的列表")

class StatisticsResponse(BaseModel):
    """
    统计查询统一返回
    """
    code: int = Field(default=200)
    message: str = Field(default="统计聚合完成")
    data: StatisticsData

# --- 5. 历史漫游下发契约 (全量同步回显) ---
class RecordSyncResponse(BaseModel):
    """
    端云漫游同步 - 全量下发返回外壳
    """
    code: int = Field(default=200)
    message: str = Field(default="获取成功")
    # 直接复用 RecordCreateItem，确保下发的数据结构与上传时完全对称
    data: List[RecordCreateItem]

    model_config = ConfigDict(from_attributes=True)