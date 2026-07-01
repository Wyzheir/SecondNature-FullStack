"""
app/core/config.py

核心数据流向：读取环境 .env 文件及系统变量 -> pydantic_settings 解析验证 -> 挂载至全局 Settings 单例供其他模块安全导入。
核心逻辑：基于 BaseSettings 实现严格类型验证环境管理，动态构建异步 MySQL 驱动连接字符串（mysql+aiomysql）。
具体职责：项目级基石配置池，保管各类鉴权密钥、第三方 API Key 与 DB 数据源地址信息，阻隔硬编码。
"""
import os
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict

# 1. 自动定位项目根目录 (E:\myapp\hel_backend)
# __file__ 是当前文件，resolve().parent 是 core/，再 parent 是 app/，再 parent 是根目录
BASE_DIR = Path(__file__).resolve().parent.parent.parent

class Settings(BaseSettings):
    MYSQL_USER: str
    MYSQL_PASSWORD: str
    MYSQL_HOST: str
    MYSQL_PORT: int
    MYSQL_DB: str
    # --- 新增：JWT 安全配置 ---
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 默认 7 天过期
    # 🚀 新增：大模型配置
    DEEPSEEK_API_KEY: str
    REDIS_HOST: str = "127.0.0.1"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str

    @property
    def SQLALCHEMY_DATABASE_URL(self) -> str:
        # 🚨 核心修改：使用异步驱动 mysql+aiomysql
        return f"mysql+aiomysql://{self.MYSQL_USER}:{self.MYSQL_PASSWORD}@{self.MYSQL_HOST}:{self.MYSQL_PORT}/{self.MYSQL_DB}?charset=utf8mb4"

    # 2. 使用绝对路径指向 .env
    model_config = SettingsConfigDict(
        env_file=os.path.join(BASE_DIR, ".env"), # 这里的路径现在是死命令，绝对不会找错
        env_file_encoding="utf-8",
        extra="ignore"
    )
    @property
    def REDIS_URL(self) -> str:
        # 如果你之前宝塔设置了密码，就走带密码的标准协议
        return f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:{self.REDIS_PORT}"

    model_config = SettingsConfigDict(
        env_file=os.path.join(BASE_DIR, ".env"),
        env_file_encoding="utf-8",
        extra="ignore"
    )

settings = Settings()