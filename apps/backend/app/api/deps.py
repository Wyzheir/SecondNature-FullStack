import logging
from typing import AsyncGenerator
from fastapi import HTTPException, status, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import AsyncSessionLocal
from app.core.clients import redis_client  # 🌟 引入咱们刚刚在 core 里配置好的异步 Redis 客户端

# 初始化日志记录器，方便在本地控制台和阿里云后台监控刷量行为
logger = logging.getLogger(__name__)


# ==========================================
# 🛡️ 模块一：分布式高并发限流铁闸（Redis 驱动）
# ==========================================

async def chat_rate_limiter(request: Request):
    """
    基于 Redis 异步连接池的用户每分钟接口限流阀门。

    【核心流向】：
    HTTP 请求打入 -> 触发此依赖 -> 提取客户端 IP/User ->
    去阿里云 Docker 内部的 Redis 计数 -> 判定是否超限 -> 放行或无情拦截。

    【具体规则】：
    限制每个客户端 IP 地址，一分钟内最多只能请求 10 次。
    """
    # 1. 提取客户端唯一标识（这里为了省事用真实 IP，后期有 JWT 登录可以换成 current_user.id）
    client_ip = request.client.host

    # 2. 组装该客户端在 Redis 中的唯一监控 Key
    # 加上 rate_limit 前缀，便于以后在宝塔的 Docker 缓存里统一进行可视化清洗与隔离
    redis_key = f"rate_limit:chat:{client_ip}"

    try:
        # 3. 异步通过隧道向阿里云的 Redis 内存索要这个 IP 在这一分钟内的点击次数
        current_count = await redis_client.get(redis_key)

        # 4. 判断是否达到拦截红线（一分钟 10 次）
        if current_count and int(current_count) >= 10:
            logger.warning(f"🚨 拦截警告：IP [{client_ip}] 访问已达 {current_count} 次，触发防刷机制，已无情降维打击！")

            # 大厂规范：超过频率限制必须无条件抛出 HTTP 429 Too Many Requests 状态码
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": 429,
                    "message": "手速太快啦！请歇一分钟再来和 Sena 聊天吧 😊",
                    "data": None
                }
            )

        # 5. 如果没超限，利用 Redis 的 Pipeline（管道）进行高性能原子自增
        # 这能将自增（INCR）和倒计时（EXPIRE）两条命令打包发送，极大缩减横跨公网的 SSH 隧道网络 IO 损耗
        async with redis_client.pipeline(transaction=True) as pipe:
            # 令该 IP 的计数器累加 1
            await pipe.incr(redis_key)

            # 🚨 细节控：如果是这一分钟内的第一次点击（Redis 里还没这个 Key），必须立刻注入 60 秒的过期倒计时
            if not current_count:
                await pipe.expire(redis_key, 60)

            # 批量将命令轰炸给云端 Docker 执行
            await pipe.execute()

    except HTTPException:
        # 如果是主动抛出的 429 异常，不作为系统未知错误处理，直接向上抛给 FastAPI 捕捉返回给前端
        raise
    except Exception as e:
        # 💡 大厂级高可用防线（降级容错）：
        # 万一哪天阿里云突发网络波动、或者隧道偶尔闪断，限流系统绝对不能把正常用户卡死。
        # 此时记录 error 日志，并直接 return 放行，让用户继续聊天，保障核心业务不中断。
        logger.error(f"❌ Redis 限流服务闪断或异常: {str(e)}，已自动开启安全降级放行模式。")
        return


# ==========================================
# 🗄️ 模块二：关系型数据库会话管理（MySQL 驱动）
# ==========================================

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI 异步数据库依赖注入函数。

    【核心数据流向】：
    FastAPI 路由函数入参请求 -> 依赖注入系统触发 -> yield 分配 AsyncSession -> 请求完毕自动清理关闭连接。

    【具体职责】：
    全局依赖注入的底层支柱，确保每一个 HTTP 并发请求都拥有完全独立且能安全释放的异步数据库会话。
    """
    async with AsyncSessionLocal() as db:
        try:
            yield db
        finally:
            # 无论路由内部是执行成功返回 JSON，还是中途报错崩溃，finally 保证百分之百把 MySQL 会话关闭，防止连接池死锁
            await db.close()