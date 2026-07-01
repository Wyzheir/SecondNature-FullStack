"""
app/services/context_builder.py

核心数据流向：根据 session_id 从 DB 提取倒序历史 -> 过滤违规拦截记录 -> 基于 MAX_HISTORY_CHARS 实施滑动窗口截断 -> 翻转正序后拼接最新 User Prompts -> 交与模型。
核心逻辑：实施基于字符数阈值的限流滑动窗口机制，智能识别过滤系统硬拦截对话以防止向 LLM 喂送“脏记忆”。
具体职责：上下文剪裁师，把控大模型推理能耗边界与长期记忆逻辑流贯穿的有效整合。
"""

import logging
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
from app.models.chat import ChatMessage

logger = logging.getLogger(__name__)

# 历史消息最大字符数（避免 token 溢出）
MAX_HISTORY_CHARS = 1800


async def build_history_context(
    session_id: str,
    system_prompt: str,
    current_message: str,
    db: AsyncSession
) -> list[dict]:
    """
    构建包含系统提示、近期历史、当前消息的完整 messages 列表。
    - 自动跳过被系统安全拦截的用户/助手消息对，防止污染上下文。
    - 返回的列表可直接用于 OpenAI 兼容的 chat.completions.create 调用。
    """
    # 查询最近 30 条消息
    hist_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(desc(ChatMessage.created_at))
        .limit(30)
    )
    all_history = hist_result.scalars().all()

    char_count = 0
    clean_history = []
    skip_toxic_user = False

    # 从倒数第二条开始处理（最后一条是刚存入的用户消息，将在末尾加入）
    if len(all_history) > 1:
        for msg in all_history[1:]:
            # 识别系统拦截消息，并跳过对应的违规用户消息
            if not msg.is_user and "【系统安全拦截】" in msg.content:
                skip_toxic_user = True
                continue
            if skip_toxic_user and msg.is_user:
                skip_toxic_user = False
                continue
            # 容错：若标记混乱则重置
            if skip_toxic_user and not msg.is_user:
                skip_toxic_user = False

            msg_len = len(msg.content)
            if char_count + msg_len > MAX_HISTORY_CHARS:
                break
            clean_history.insert(0, msg)  # 保持时间正序
            char_count += msg_len

    # 组装标准 messages 格式
    messages = [{"role": "system", "content": system_prompt}]
    for msg in clean_history:
        role = "user" if msg.is_user else "assistant"
        messages.append({"role": role, "content": msg.content})
    messages.append({"role": "user", "content": current_message})

    return messages