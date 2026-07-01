"""
app/main.py

核心数据流向：接收外部 HTTP 请求 -> 穿透 CORS 中间件 -> 触发异常拦截（若有）或分配至具体 API 路由 -> 返回标准 JSON 契约。
核心逻辑：实例化 FastAPI，注册跨域策略（CORSMiddleware），挂载全局异常拦截器（风控、鉴权、格式校验），并基于 prefix 组装各业务子路由。
具体职责：应用生命周期的起点，负责基础生态中间件编排、路由网关组装及全局错误把控。
"""


from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from starlette.middleware.cors import CORSMiddleware

from app.api.v1.goals import router as goals_router
from app.api.v1.records import router as records_router
# --- 新增：引入鉴权路由 ---
from app.api.v1.auth import router as auth_router
from app.api.v1.assistant import router as assistant_router
from app.models.chat import ChatMessage

from app.core.exceptions import (
    HealthRiskException,
    health_risk_exception_handler,
    validation_exception_handler,
    AuthException,
    auth_exception_handler
)
from app.api.v1.foods import router as foods_router
app = FastAPI(title="Health Management API", version="1.0.0")
# 🚀 第二步：在 app 实例化之后，立刻添加 CORS 中间件
# 这段代码必须在 include_router 之前运行
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 允许所有来源（手机 IP、电脑 IP 等）
    allow_credentials=False,
    allow_methods=["*"],  # 允许所有方法（POST, GET, OPTIONS 等）
    allow_headers=["*"],  # 允许所有请求头
)

app.add_exception_handler(HealthRiskException, health_risk_exception_handler)
app.add_exception_handler(RequestValidationError, validation_exception_handler)
app.add_exception_handler(AuthException, auth_exception_handler)

# 挂载业务路由
app.include_router(goals_router, prefix="/api/v1/goals", tags=["Health Goals"])
app.include_router(records_router, prefix="/api/v1/records", tags=["Health Records"])
# --- 新增：挂载鉴权路由 ---
app.include_router(auth_router, prefix="/api/v1/auth", tags=["Auth"])
app.include_router(foods_router, prefix="/api/v1/foods", tags=["Food Dictionary"])

app.include_router(assistant_router, prefix="/api/v1/assistant", tags=["AI Assistant"])
# 生产模式启动（关闭 reload，指定工作进程数）
# uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
# 第一步：自动生成迁移脚本（比对差异）
#
# Bash
# alembic revision --autogenerate -m "init_health_tables"
# 这行命令会让 Alembic 扫描我们在 models 里写的 Python 类，并和当前 MySQL 数据库里的表做对比，自动在 alembic/versions/ 目录下生成一段包含 op.create_table(...) 的 Python 脚本。
#
# 第二步：执行建表（真正入库）
#
# Bash
# alembic upgrade head

#ollama pull qwen2.5:3b
