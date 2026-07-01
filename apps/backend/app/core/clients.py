"""
app/core/clients.py

核心数据流向：业务层随时调用全局客户端对象 -> 经 HTTPX 异步连接池发起长连接 -> 对接不同服务商模型层。
核心逻辑：基于 httpx.AsyncClient 配置超时防死锁基座，初始化本地开源模型（Ollama）及云端模型（DeepSeek）的 API 环境。
具体职责：应用内所有模型侧外部调用的基础设施引擎层，集中纳管超参及常量标识配置，保证连接池高可用复用。
"""
import httpx
from openai import AsyncOpenAI

# 网络超时配置：连接 5 秒，流式读取容忍 300 秒
timeout_config = httpx.Timeout(connect=5.0, read=300.0, write=300.0, pool=10.0)
http_client = httpx.AsyncClient(trust_env=False,  timeout=timeout_config)

# 本地小模型（负责安全、路由、闲聊、标题等轻量任务）
ollama_client = AsyncOpenAI(
    api_key="ollama",
    base_url="http://127.0.0.1:11434/v1",
    http_client=http_client
)

# 云端专家（负责复杂健康咨询、多模态等）
from app.core.config import settings

# 引入全局 settings 动态读取。
deepseek_client = AsyncOpenAI(
    api_key=settings.DEEPSEEK_API_KEY,
    base_url="https://api.deepseek.com",
    http_client=http_client
)

# 模型名称常量
LOCAL_MODEL = "qwen2.5:0.5b"       # 本地 0.5B 快模型
DEEPSEEK_MODEL = "deepseek-chat"    # DeepSeek 对话模型
VISION_MODEL = "deepseek-chat"      # 多模态模型



# 大厂级标准异步连接池，带强密码，走本地安全隧道
import redis.asyncio as aioredis
from app.core.config import settings

# 直接调用定义好的 property 属性，清爽、稳固、不拼凑字符串！
redis_client = aioredis.from_url(
    settings.REDIS_URL,
    decode_responses=True,
    max_connections=100,       # 🌟 放大连接池，扛住 Apifox 的并发轰炸
    socket_timeout=5.0,        # 🌟 核心：读写超时给足 5 秒！绝不轻易触发 Timeout 降级
    socket_connect_timeout=5.0 # 🌟 连接超时给足 5 秒
)