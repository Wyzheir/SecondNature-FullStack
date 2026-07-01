"""
services/title_generator.py

为新会话的首条用户消息即时生成标题，采用多级兜底策略：
1. 本地小模型 (qwen2.5:0.5b)
2. 云端专家模型 (deepseek-chat)
3. 关键词提取规则
4. 固定默认标题 "健康咨询"

使用 asyncio 后台任务 + 去重锁，避免重复生成。
"""

import re
import asyncio
import logging
from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.chat import ChatSession
from app.core.clients import ollama_client, deepseek_client, LOCAL_MODEL, DEEPSEEK_MODEL

logger = logging.getLogger(__name__)

# 防止同一个 session 并发生成标题
_title_generation_locks = set()


def _extract_keywords(text: str) -> str:
    """
    简单关键词提取：过滤停用词，取首个有意义的词或短语。
    若失败则截取文本前 8 个字符。
    """
    stopwords = {
        "我", "想", "问", "一下", "怎么", "什么", "如何", "为什么",
        "的", "了", "吗", "呢", "是", "不", "个", "这", "那",
        "可以", "能", "有", "在", "你", "他", "她"
    }
    cleaned = re.sub(r'[^\w\s]', '', text)
    words = cleaned.split()
    for w in words:
        if w not in stopwords and len(w) >= 2:
            return w
    meaningful = [w for w in words if len(w) >= 2]
    if meaningful:
        return " ".join(meaningful[:2])
    return cleaned[:8] if cleaned else "健康咨询"


async def _try_model_title(client, model: str, prompt: str) -> str | None:
    """尝试用指定模型生成 10 字以内的标题，成功返回标题，失败返回 None"""
    try:
        resp = await client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "生成一个8字以内的对话标题，不加标点，直接输出标题。"},
                {"role": "user", "content": prompt}
            ],
            stream=False,
            max_tokens=15,
            temperature=0.3
        )
        # 🔒 安全获取 content，防止 None.strip() 引发 AttributeError
        raw_content = resp.choices[0].message.content
        if not raw_content:
            return None
        title = raw_content.strip().replace('"', '').replace("'", "")
        if title and len(title) <= 10:
            return title
    except Exception as e:
        logger.warning(f"模型 {model} 标题生成失败: {e}")
    return None


async def generate_title_immediately(session_id: str, user_first_msg: str):
    """
    后台任务：立即为会话生成并持久化标题。
    适用于首条用户消息后调用。
    """
    # 去重：如果该会话已在处理中，直接退出
    if session_id in _title_generation_locks:
        return
    _title_generation_locks.add(session_id)

    try:
        # 1. 直接尝试 DeepSeek
        title = await _try_model_title(deepseek_client, DEEPSEEK_MODEL, user_first_msg)

        # 2. 关键词提取
        if not title:
            title = _extract_keywords(user_first_msg)

        # 3. 最终兜底
        if not title:
            title = "健康咨询"

        async with AsyncSessionLocal() as db:
            result = await db.execute(
                select(ChatSession).where(ChatSession.session_id == session_id)
            )
            session = result.scalars().first()
            if session and session.title in ("新对话", "新_对话"):
                session.title = title
                await db.commit()
                logger.info(f"📝 标题已更新: {session_id} -> {title}")

    except Exception as e:
        logger.error(f"标题生成任务整体失败: {e}")
    finally:
        _title_generation_locks.discard(session_id)