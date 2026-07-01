"""
app/models/goal.py

核心数据流向：映射关系型数据表 health_goals 到 Python 实例操作。
核心逻辑：基于 client_msg_id 的幂等标识防并发污染，利用复合索引加速用户在激活状态下（is_active）的目标快照获取。
具体职责：承载动态化健康目标流水历史变迁版本控制表，保障用户调整计划后的宏量营养素记录可追溯。
"""
from sqlalchemy import Column, BigInteger, String, Integer, Numeric, Boolean, TIMESTAMP, text, Index
from app.db.base import Base


class HealthGoal(Base):
    """
    健康目标表 (映射 health_goals)
    """
    __tablename__ = "health_goals"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(64), nullable=False)
    # 同样的幂等性保障
    client_msg_id = Column(String(36), nullable=False, unique=True)

    goal_type = Column(String(20), nullable=False, comment="LOSE:减脂, GAIN:增肌, MAINTAIN:维持")
    target_weight = Column(Numeric(5, 2), nullable=False)
    daily_calorie_target = Column(Integer, nullable=False, comment="算法得出的每日推荐摄入热量(kcal)")
    daily_burn_target = Column(Integer, nullable=False, comment="算法得出的每日推荐运动消耗(kcal)")
    is_active = Column(Boolean, default=True, comment="是否为当前执行目标")

    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))

    # 复合索引：加速查询用户当前 active 的目标
    __table_args__ = (
        Index("idx_user_active", "user_id", "is_active"),
    )