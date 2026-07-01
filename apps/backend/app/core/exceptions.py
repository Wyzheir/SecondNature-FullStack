"""
app/core/exceptions.py

核心数据流向：业务层/鉴权层主动 raise 异常 -> 触发现场拦截 -> 通过全局 exception_handler 组装标准 HTTP Code 及 JSON -> 送达客户端。
核心逻辑：将底层验证错误及复杂的业务阻断（如指标危险）重新包装，抹平 FastAPI 默认错误输出的层级差异。
具体职责：自定义系统级防线，负责向外界输送无感知、契约对齐的健康风控预警及鉴权剥夺响应。
"""
import logging
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

logger = logging.getLogger(__name__)


class HealthRiskException(Exception):
    """
    健康风险异常：专门用于触发 400 状态码的自定义异常。
    当计算出的目标热量等指标触发风控红线时抛出。
    """

    def __init__(self, message: str):
        self.message = message
        super().__init__(self.message)

class AuthException(Exception):
    """
    自定义鉴权异常：当 Token 缺失、解析失败或过期时抛出。
    用于绕过 FastAPI 默认的非标准 401 响应。
    """
    pass

async def auth_exception_handler(request: Request, exc: AuthException) -> JSONResponse:
    """
    全局拦截 AuthException，严格输出契约规定的 JSON 结构。
    """
    logger.warning(f"鉴权失败拦截 | Path: {request.url.path}")
    return JSONResponse(
        status_code=401,
        content={
            "code": 401,
            "message": "Token无效或已过期",  # 严格对齐前端契约
            "data": None
        }
    )


async def health_risk_exception_handler(request: Request, exc: HealthRiskException) -> JSONResponse:
    """
    捕获 HealthRiskException，强制返回 HTTP 400 状态码及统一契约结构。
    """
    logger.warning(f"触发健康风控阻断: {exc.message} | Path: {request.url.path}")
    return JSONResponse(
        status_code=400,
        content={
            "code": 400,
            "message": exc.message,
            "data": None  # JSON 序列化时自动转换为 null
        }
    )


async def validation_exception_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    """
    覆盖 FastAPI 默认的 RequestValidationError。
    屏蔽底层复杂的错误数组（防止内部字段结构泄露给调用方），
    统一返回 HTTP 422 状态码及精简的提示信息。
    """
    # 生产环境中建议将详细的 exc.errors() 打印到日志中，便于后端排查，但不对外暴露
    logger.error(f"参数校验失败: {exc.errors()} | Path: {request.url.path}")

    return JSONResponse(
        status_code=422,
        content={
            "code": 422,
            "message": "参数校验失败",
            "data": None
        }
    )