"""
app/core/security.py

核心数据流向：依赖拦截 HTTP Header -> jwt.decode/encode 解析及签发验证 -> pwd_context.hash 比对数据库明密文。
核心逻辑：基于 HS256 算法保证 Token 不可伪造，利用 passlib 配置多轮 bcrypt 盐化避免彩虹表破解。
具体职责：应用安防保卫处，主导 JWT 令牌在无状态服务中的流通寿命管控，以及对数据库内密码落盘执行单向高强度加密。
"""
import jwt
from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from app.core.config import settings
from app.core.exceptions import AuthException
from datetime import datetime, timedelta, timezone

# auto_error=False 是关键：不让 FastAPI 自动抛出 401，而是交由我们自定义处理
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login", auto_error=False)


def get_current_user(token: str = Depends(oauth2_scheme)) -> str:
    """
    全局鉴权依赖注入函数。
    验证请求头中的 JWT，若合法则返回 user_id，若非法则触发自定义 401 拦截。
    """
    if not token:
        # 拦截：未携带 Token
        raise AuthException()

    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            # 拦截：Token 格式正确但缺少关键主体信息
            raise AuthException()

        return user_id

    except jwt.ExpiredSignatureError:
        # 拦截：Token 已过期
        raise AuthException()
    except jwt.InvalidTokenError:
        # 拦截：Token 签名失效或被篡改
        raise AuthException()





def create_access_token(subject: str) -> str:
    """
    根据传入的用户标识（subject）签发具备有效期的 JWT
    """
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode = {"exp": expire, "sub": str(subject)}

    # 使用 HS256 算法和配置文件中的 SECRET_KEY 进行签名
    encoded_jwt = jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return encoded_jwt


from passlib.context import CryptContext

# 采用 bcrypt 算法，默认进行 12 轮哈希加盐
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def get_password_hash(password: str) -> str:
    """
    将明文密码转换为不可逆的哈希字符串
    """
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    校验明文密码与数据库哈希值是否匹配
    """
    return pwd_context.verify(plain_password, hashed_password)