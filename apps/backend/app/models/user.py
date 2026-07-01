"""
app/models/user.py

核心数据流向：映射关系型数据表 user_profiles 和 verification_codes 到 Python 实例操作。
核心逻辑：配置唯一性约束防止重复注册，整合当前正在执行的关键目标快照至主表以削减高频业务查询的 JOIN 消耗。
具体职责：用户信息及身份枢纽，提供账号鉴权比对的哈希锚点、生理状态静态底库以及验证码安全凭据承载。
"""
from sqlalchemy import Column, BigInteger, String, Integer, Numeric, TIMESTAMP, text
from sqlalchemy.dialects.mysql import TINYINT
from app.db.base import Base


class UserProfile(Base):
    __tablename__ = "user_profiles"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(String(64), nullable=False, unique=True)
    client_msg_id = Column(String(36), nullable=False, unique=True)

    # --- 核心物理防线：增加 unique=True 唯一索引 ---
    username = Column(String(64), nullable=False, unique=True, comment="用户名")
    hashed_password = Column(String(255), nullable=False, comment="哈希密码")
    email = Column(String(128), nullable=True, comment="邮箱")

    # 资料字段（允许后续完善）
    gender = Column(TINYINT, nullable=True, comment="1:男, 2:女")
    age = Column(Integer, nullable=True)
    height = Column(Numeric(5, 2), nullable=True)
    weight = Column(Numeric(5, 2), nullable=True)
    activity_level = Column(Numeric(3, 2), nullable=True)

    # 🌟 核心升级：持久化目标与营养素快照
    target_weight = Column(Numeric(10, 2), nullable=True, comment="用户设定的目标体重")
    goal_type = Column(String(20), nullable=True, comment="目标类型")
    target_kcal = Column(Numeric(10, 2), nullable=True, comment="目标热量")
    carbs_g = Column(Numeric(10, 2), nullable=True, comment="碳水(g)")
    protein_g = Column(Numeric(10, 2), nullable=True, comment="蛋白质(g)")
    fat_g = Column(Numeric(10, 2), nullable=True, comment="脂肪(g)")

    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))
    updated_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"))

from sqlalchemy import Column, Integer, String, TIMESTAMP, text
# ... 原来的导入 ...

class VerificationCode(Base):
    """
    验证码记录表
    """
    __tablename__ = "verification_codes"

    id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(128), nullable=False, index=True, comment="接收邮箱")
    code = Column(String(10), nullable=False, comment="6位验证码")
    expires_at = Column(TIMESTAMP, nullable=False, comment="过期时间")
    is_used = Column(TINYINT, default=0, comment="0:未使用, 1:已使用")
    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"))