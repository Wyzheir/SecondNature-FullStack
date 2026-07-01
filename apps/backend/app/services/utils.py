"""
services/utils.py

提供异步落盘 AI 回复消息的通用函数，避免在各处重复数据库操作。
"""

import logging
from app.db.session import AsyncSessionLocal
from app.models.chat import ChatMessage

logger = logging.getLogger(__name__)


async def save_ai_message(session_id: str, user_id: str, content: str):
    """
    以独立的数据库会话保存一条 AI 回复。
    适用于流式输出结束后的最终落盘，或拦截消息的立即落盘。
    """
    async with AsyncSessionLocal() as db:
        db.add(ChatMessage(
            session_id=session_id,
            user_id=user_id,
            content=content,
            is_user=False
        ))
        await db.commit()