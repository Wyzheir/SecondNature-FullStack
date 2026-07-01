"""
app/api/v1/assistant.py

核心数据流向：前端发起多模态请求 -> 路由层鉴权并注入上下文 -> 转发请求至 assistant_service 编排 -> 返回流式或标准化结果。
核心逻辑：定义对话统一入口（/chat），提供会话（Session）的生成、查询、删除以及历史消息游标拉取等基础能力。
具体职责：AI 助手模块的 API 控制器，仅负责接收参数验证、越权拦截，不包含任何大模型核心组装逻辑。
"""
import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, Query
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc, func, delete

from app.schemas.assistant import (
    ChatRequest, ChatHistoryResponse, ChatMessageItem,
    SessionCreateResponse, SessionListResponse, SessionListItem
)
from app.models.chat import ChatSession, ChatMessage
from app.core.security import get_current_user
from app.api.deps import get_db
from app.services.assistant_service import handle_chat_request

import logging
logger = logging.getLogger(__name__)
from app.api.deps import chat_rate_limiter
router = APIRouter()


# ==================== 核心对话接口 ====================
@router.post(
    "/chat",
    summary="SecondNature 多模态健康伙伴",
    dependencies=[Depends(chat_rate_limiter)]  # 🌟 2. 核心大闸挂载！请求进来必须先过 Redis 计数
)
async def chat_with_assistant(
    request: ChatRequest,
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    """
    所有对话（文本/图片）的统一入口，由 assistant_service 编排。
    已被 Redis 令牌桶死死锁住：同一个 IP 一分钟内最多请求 10 次，超限直接爆 429。
    """
    # 能够安全走到这里，说明该 IP 在 Redis 里的计数完全健康，直接放行给大模型服务
    return await handle_chat_request(request, db, current_user)

# ==================== 会话管理 ====================
@router.post("/sessions", response_model=SessionCreateResponse)
async def create_session(
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    new_id = str(uuid.uuid4())
    db.add(ChatSession(session_id=new_id, user_id=current_user, title="新对话"))
    await db.commit()
    return SessionCreateResponse(session_id=new_id)


@router.get("/sessions", response_model=SessionListResponse)
async def list_sessions(
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    result = await db.execute(
        select(ChatSession)
        .where(ChatSession.user_id == current_user)
        .order_by(desc(ChatSession.updated_at))
    )
    sessions = result.scalars().all()
    return SessionListResponse(
        data=[
            SessionListItem(
                session_id=s.session_id,
                title=s.title,
                updated_at=s.updated_at
            )
            for s in sessions
        ]
    )


@router.delete("/sessions/{session_id}")
async def delete_session(
    session_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    result = await db.execute(
        select(ChatSession).where(ChatSession.session_id == session_id)
    )
    session = result.scalars().first()
    if not session or session.user_id != current_user:
        return JSONResponse(status_code=403, content={"code": 403, "message": "越权或目标不存在"})

    await db.execute(delete(ChatMessage).where(ChatMessage.session_id == session_id))
    await db.delete(session)
    await db.commit()
    return {"code": 200, "message": "话题已清除"}


@router.get("/history", response_model=ChatHistoryResponse)
async def get_history(
    session_id: str = Query(...),
    db: AsyncSession = Depends(get_db),
    current_user: str = Depends(get_current_user)
):
    # 验证会话所属权
    session_result = await db.execute(
        select(ChatSession).where(ChatSession.session_id == session_id)
    )
    if not session_result.scalars().first():
        return JSONResponse(status_code=403, content={"code": 403, "message": "越权", "data": []})

    msg_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at.asc())
    )
    messages = msg_result.scalars().all()
    return ChatHistoryResponse(
        data=[
            ChatMessageItem(content=m.content, is_user=m.is_user)
            for m in messages
        ]
    )