"""
app/db/session.py

核心数据流向：配置信息加载 -> 构建异步 Engine 线程池 -> 封装为 async_sessionmaker -> 交由 API 层开启事务。
核心逻辑：拉起基于 pool_size 配置的高效复用协程连接池，关闭 expire_on_commit 防止异步脱离上下文报 MissingGreenlet 错误。
具体职责：数据库动力泵，负责全站的数据流通管道连接建立、资源管控与性能池化释放。
"""
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

SQLALCHEMY_DATABASE_URL = settings.SQLALCHEMY_DATABASE_URL

# 1. 创建异步数据库引擎
engine = create_async_engine(
    SQLALCHEMY_DATABASE_URL,
    pool_pre_ping=True,
    pool_size=10,
    max_overflow=20,
    echo=False
)

# 2. 创建异步的 Session 工厂
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False # 🚀 核心救命参数：关闭提交后自动过期机制，彻底消灭 MissingGreenlet 报错！
)