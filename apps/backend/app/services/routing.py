"""
services/routing.py

利用模型对用户消息进行意图分类，决定后续走简单闲聊还是专家咨询。
返回 SIMPLE 或 COMPLEX。
"""

import logging
from app.core.clients import deepseek_client, DEEPSEEK_MODEL

logger = logging.getLogger(__name__)


async def get_intent_category(user_text: str) -> str:
    prompt = f"""判断用户意图，仅输出 SIMPLE 或 COMPLEX。
- SIMPLE: 纯粹的日常问候、感谢（如“你好”、“谢谢”），不涉及任何具体饮食、体重或健康话题。
- COMPLEX: 健康咨询、饮食分析、运动计划、热量计算、或者任何与食物/体重/摄入有关的问题。
用户输入: {user_text}
意图:"""

    try:
        resp = await deepseek_client.chat.completions.create(
            model=DEEPSEEK_MODEL,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=5,
            temperature=0.0
        )
        result = resp.choices[0].message.content.strip().upper()
        return "COMPLEX" if "COMPLEX" in result else "SIMPLE"
    except Exception as e:
        logger.error(f"意图路由失败，默认升级为专家处理: {e}")
        return "COMPLEX"