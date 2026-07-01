"""
app/models/chat.py

核心数据流向：映射关系型数据表 chat_sessions 和 chat_messages 到 Python 实例操作。
核心逻辑：定义外键依赖、自增主键、复合索引以及基于 SQLAlchemy 约束的时间审计机制。
具体职责：持久化 AI 对话上下文流水，保障单租户用户在不同话题树下的历史留痕规范化。
"""
from sqlalchemy import Column, BigInteger, String, Boolean, TIMESTAMP, text, ForeignKey
from app.db.base import Base


class ChatSession(Base):
    """
    智能助理会话表：一个用户可以拥有多个独立的话题会话
    """
    __tablename__ = "chat_sessions"

    # 使用 UUID 字符串作为主键，防止前端并发生成或清洗时发生冲突
    session_id = Column(String(36), primary_key=True, comment="会话唯一ID(UUID)")
    user_id = Column(String(64), nullable=False, index=True, comment="所属用户ID")
    title = Column(String(50), nullable=False, default="新对话", comment="会话动态标题")

    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"), comment="创建时间")
    # 用于历史记录列表排序，每次有新聊天时可以更新此时间，让最近聊过的话题排在最上面
    updated_at = Column(
        TIMESTAMP,
        server_default=text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
        index=True,
        comment="最后活跃时间"
    )


class ChatMessage(Base):
    """
    聊天消息流水表：所有的消息现在必须归属于某一个具体的会话
    """
    __tablename__ = "chat_messages"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    # 建立逻辑或物理外键，深度绑定会话
    session_id = Column(String(36), nullable=False, index=True, comment="所属会话ID")
    user_id = Column(String(64), nullable=False, comment="用户ID")
    content = Column(String(4000), nullable=False, comment="消息文本内容")
    is_user = Column(Boolean, nullable=False, comment="1:用户发送, 0:AI回复")

    created_at = Column(TIMESTAMP, server_default=text("CURRENT_TIMESTAMP"), index=True, comment="发送时间")