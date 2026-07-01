"""
app/services/assistant_service.py

核心数据流向：鉴权请求包 -> 即时触发生成标题（异步分支） -> 视觉预处理 -> 意图分支（聊天或专家） -> 检索/注入日活状态 -> 推送 SSE 数据流。
核心逻辑：基于大模型流式生成 (stream=True) 并发编排上下文构建机制，处理异常回退，记录回复最终落盘。
具体职责：作为大脑中枢，对子服务（RAG/视觉/上下文/路由）执行调度编排，向前端输出带生理感知觉的 AI 对答引擎。
"""

import json
import logging
import asyncio
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from fastapi.responses import StreamingResponse, JSONResponse

from app.models.chat import ChatSession, ChatMessage
from app.core.rag_engine import rag_engine
from app.core.prompts import SIMPLE_SYSTEM_PROMPT, EXPERT_SYSTEM_TEMPLATE
from app.core.clients import deepseek_client,  DEEPSEEK_MODEL

from app.services.routing import get_intent_category
from app.services.title_generator import generate_title_immediately
from app.services.vision import analyze_image, check_image_safety
from app.services.context_builder import build_history_context
from app.services.utils import save_ai_message

logger = logging.getLogger(__name__)


async def handle_chat_request(
    request,            # ChatRequest 实例
    db: AsyncSession,
    current_user: str
) -> StreamingResponse:
    """
    主流程：
    1. 鉴权，保存用户消息
    2. 若为首条消息则触发即时标题生成
    3. 若有图片则进行安全审核并多模态分析
    4. 意图路由 → 简单闲聊/专家咨询（注入当日饮食/运动/睡眠明细）
    返回 SSE 流式响应。
    """

    # ========== 1. 鉴权 & 保存用户消息 ==========
    result = await db.execute(
        select(ChatSession).where(ChatSession.session_id == request.session_id)
    )
    session = result.scalars().first()
    if not session or session.user_id != current_user:
        return JSONResponse(status_code=403, content={"code": 403, "message": "非法会话"})

    user_msg = ChatMessage(
        session_id=request.session_id,
        user_id=current_user,
        content=request.message,
        is_user=True
    )
    db.add(user_msg)
    session.updated_at = datetime.now()
    await db.commit()

    # ========== 2. 即时标题生成（仅首条） ==========
    count_result = await db.execute(
        select(func.count()).where(ChatMessage.session_id == request.session_id)
    )
    msg_count = count_result.scalar()
    if msg_count == 1 and session.title in ("新对话", "新_对话"):
        asyncio.create_task(generate_title_immediately(request.session_id, request.message))

    # ========== 3. 图像预处理 ==========
    image_url = getattr(request, 'image_url', None)
    effective_message = request.message

    if image_url and image_url.strip():
        # 图片安全审核（可后续接入真实 API）
        if not await check_image_safety(image_url):
            block_msg = "> ⚠️ **【图像安全拦截】** \n> 图片内容涉嫌违规，无法处理。"
            await save_ai_message(request.session_id, current_user, block_msg)

            async def image_block_stream():
                yield f"data: {json.dumps({'chunk': block_msg}, ensure_ascii=False)}\n\n"
                yield "data: [DONE]\n\n"
            return StreamingResponse(image_block_stream(), media_type="text/event-stream")

        # 多模态分析
        img_desc = await analyze_image(image_url, request.message)
        if not img_desc:
            img_desc = "（图像分析暂时不可用，请稍后重试）"
        effective_message = f"[用户上传了图片，内容描述：{img_desc}] 用户补充说明：{request.message}"

    # ========== 4. 正常内容的意图路由 ==========
    intent = await get_intent_category(effective_message)
    logger.info(f"🔍 路由结果: {intent}")

    # ---------- 简单闲聊 ----------
    if intent == "SIMPLE":
        async def simple_stream():
            reply = ""
            try:
                ctx = await build_history_context(
                    session_id=request.session_id,
                    system_prompt=SIMPLE_SYSTEM_PROMPT,
                    current_message=effective_message,
                    db=db
                )
                resp = await deepseek_client.chat.completions.create(
                    model=DEEPSEEK_MODEL,
                    messages=ctx,
                    max_tokens=100,
                    temperature=0.8
                )
                reply = resp.choices[0].message.content.strip() or "在呢！想聊什么健康话题？😊"
            except Exception as e:
                logger.error(f"简单闲聊生成失败: {e}")
                reply = "抱歉，我刚刚走神了，可以再说一遍吗？"
            finally:
                await save_ai_message(request.session_id, current_user, reply)
                yield f"data: {json.dumps({'chunk': reply}, ensure_ascii=False)}\n\n"
                yield "data: [DONE]\n\n"
        return StreamingResponse(simple_stream(), media_type="text/event-stream")

    # ---------- 专家咨询 ----------
    # === 构建饮食明细文本 ===
    diet_items = getattr(request.context, 'today_diet_items', None) or []
    diet_text = ""
    if diet_items:
        items = diet_items[:15]  # 限制最多 15 条
        lines = []
        for item in items:
            lines.append(
                f"- [{item.meal_type}] {item.food_name} "
                f"({item.record_value:.0f}kcal, C:{item.carbs_g or 0:.1f}g, "
                f"P:{item.protein_g or 0:.1f}g, F:{item.fat_g or 0:.1f}g)"
            )
        diet_text = "用户今日已记录饮食：\n" + "\n".join(lines)

    # === 构建运动明细文本 ===
    exercise_items = getattr(request.context, 'today_exercise_items', None) or []
    exercise_text = ""
    if exercise_items:
        lines = []
        for item in exercise_items[:10]:  # 限制最多 10 条
            kcal_str = f", 消耗{item.burn_kcal:.0f}kcal" if item.burn_kcal is not None else ""
            lines.append(f"- {item.exercise_name}: {item.duration:.0f}分钟{kcal_str}")
        exercise_text = "用户今日运动记录：\n" + "\n".join(lines)

    # === 构建睡眠数据文本 ===
    sleep_text = ""
    if request.context.today_sleep_hours is not None:
        sleep_text = f"用户今日睡眠时长：{request.context.today_sleep_hours:.1f}小时"

    # === 构建最终 system prompt ===
    reference_docs = rag_engine.search_knowledge(effective_message, top_k=3)
    knowledge_text = "\n".join(reference_docs) if reference_docs else "暂无直接匹配知识"
    user_name = getattr(request.context, 'name', '用户') if hasattr(request, 'context') else '用户'
    expert_system = EXPERT_SYSTEM_TEMPLATE.format(
        user_name=user_name,
        current_weight=request.context.current_weight if hasattr(request, 'context') else '未知',
        target_kcal=request.context.target_kcal if hasattr(request, 'context') else '未设置',
        knowledge_base=knowledge_text
    )
    # 注入饮食明细
    if diet_text:
        expert_system += "\n\n### 用户今日饮食记录\n" + diet_text
    # 注入运动与睡眠
    if exercise_text or sleep_text:
        expert_system += "\n\n### 用户今日运动与恢复\n"
        if exercise_text:
            expert_system += exercise_text + "\n"
        if sleep_text:
            expert_system += sleep_text

    async def expert_stream():
        full_reply = ""
        try:
            ctx = await build_history_context(
                session_id=request.session_id,
                system_prompt=expert_system,
                current_message=effective_message,
                db=db
            )
            response = await deepseek_client.chat.completions.create(
                model=DEEPSEEK_MODEL,
                messages=ctx,
                stream=True,
                temperature=0.3
            )
            async for chunk in response:
                if chunk.choices and chunk.choices[0].delta.content:
                    content = chunk.choices[0].delta.content
                    full_reply += content
                    yield f"data: {json.dumps({'chunk': content}, ensure_ascii=False)}\n\n"
            yield "data: [DONE]\n\n"

        except asyncio.CancelledError:
            logger.warning("前端连接断开，专家流中止")
        except Exception as e:
            logger.error(f"DeepSeek 专家调用异常: {e}")
            fallback = "\n\n> ⚠️ 专家服务暂时连接不上，请稍后重试或和我聊聊别的。"
            full_reply += fallback
            yield f"data: {json.dumps({'chunk': fallback}, ensure_ascii=False)}\n\n"
            yield "data: [DONE]\n\n"
        finally:
            if full_reply:
                await save_ai_message(request.session_id, current_user, full_reply)

    return StreamingResponse(expert_stream(), media_type="text/event-stream")