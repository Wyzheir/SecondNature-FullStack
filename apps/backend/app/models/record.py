"""
app/models/record.py

核心数据流向：映射关系型数据表 health_records 到 Python 实例操作。
核心逻辑：摒弃自增采用前端生成的物理主键 client_msg_id，提供高度灵活但 nullable=True 防破坏的细粒度打卡字段。
具体职责：大体量流水登记核心表，包容饮食、睡眠、运动全维度的行为审计记录，建立针对性复合索引支持高效按日聚合。
"""
from sqlalchemy import Column, String, Numeric, TIMESTAMP, text, Index
from app.db.base import Base


class HealthRecord(Base):
    """
    健康打卡记录表（登记员模式）：
    不再使用自增 ID，直接以前端生成的 UUID (client_msg_id) 作为物理主键。
    """
    __tablename__ = "health_records"

    # 🌟 物理主键：前端 UUID
    client_msg_id = Column(
        String(36),
        primary_key=True,
        nullable=False,
        comment="前端生成的唯一UUID，既是业务ID也是物理主键"
    )

    # 租户隔离
    user_id = Column(String(64), nullable=False, index=True, comment="关联用户中心的主键")

    # 🌟 业务字段更新：加入 WEIGHT 类型说明
    record_type = Column(
        String(20),
        nullable=False,
        comment="类型: DIET(饮食), EXERCISE(运动), SLEEP(睡眠), WEIGHT(体重)"
    )

    # 🌟 数值精度：(10, 2) 足够覆盖 0.01 到 99,999,999.99，非常稳
    record_value = Column(Numeric(10, 2), nullable=False, comment="数值：热量(kcal)、时长(小时)或体重(kg)")

    # 🌟 单位说明更新：加入 kg
    unit = Column(String(10), nullable=False, comment="单位：如 kcal, hours, kg")
    duration = Column(Numeric(10, 2), nullable=True, comment="补充时长(数值)，如运动分钟数")
    # 🌟 新增：精细化饮食打卡字段 (向下兼容，全设为 nullable=True)
    meal_type = Column(String(20), nullable=True, comment="餐别: BREAKFAST, LUNCH, DINNER, SNACK")
    food_name = Column(String(100), nullable=True, comment="食物名称")
    carbs_g = Column(Numeric(6, 2), nullable=True, comment="碳水化合物(g)")
    protein_g = Column(Numeric(6, 2), nullable=True, comment="蛋白质(g)")
    fat_g = Column(Numeric(6, 2), nullable=True, comment="脂肪(g)")
    # 🆕 运动名称（仅 EXERCISE 类型使用）
    exercise_name = Column(String(100), nullable=True, comment="运动名称（仅EXERCISE类型使用）")
    notes = Column(String(255), nullable=True, comment="用户附加备注")

    # 时间审计
    record_date = Column(TIMESTAMP, nullable=False, comment="实际打卡发生的业务时间")
    created_at = Column(
        TIMESTAMP,
        server_default=text("CURRENT_TIMESTAMP"),
        comment="记录入库的审计时间"
    )

    # 🚀 复合索引优化
    __table_args__ = (
        Index("idx_user_date_type", "user_id", "record_date", "record_type"),
    )