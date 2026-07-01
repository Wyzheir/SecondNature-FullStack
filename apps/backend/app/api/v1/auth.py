import uuid
import random
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException  # 💡 引入 HTTPException
from sqlalchemy import select, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db
from app.models.user import UserProfile, VerificationCode
from app.schemas.auth import (
    LoginRequest, TokenResponse, TokenData,
    UserRegisterRequest, RegisterResponse, SendCodeRequest, ResetPasswordRequest
)
from app.core.security import get_password_hash, verify_password, create_access_token

router = APIRouter()

# 💡 新增：统一的密码长度校验函数
def validate_password_length(password: str):
    if len(password.encode('utf-8')) > 72:
        raise HTTPException(status_code=400, detail="密码长度不能超过 72 个字符")

@router.post("/register", response_model=RegisterResponse)
async def register(request: UserRegisterRequest, db: AsyncSession = Depends(get_db)):
    # 1. 唯一性检查
    result = await db.execute(select(UserProfile).where(UserProfile.username == request.username))
    existing_user = result.scalars().first()

    if existing_user:
        raise HTTPException(status_code=400, detail="该用户名已被占用")

    # 💡 2. 安全校验与哈希处理
    validate_password_length(request.password) # 必须在 hash 前校验
    hashed_password = get_password_hash(request.password)

    new_user = UserProfile(
        user_id=str(uuid.uuid4()),
        username=request.username,
        hashed_password=hashed_password,
        email=request.email,
        client_msg_id=str(uuid.uuid4())
    )

    try:
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
    except Exception as e:
        await db.rollback()
        raise e

    # 3. 自动登录
    access_token = create_access_token(subject=new_user.user_id)

    return RegisterResponse(
        message="注册成功，欢迎开启健康之旅",
        data=TokenData(
            access_token=access_token,
            token_type="bearer",
            user_id=new_user.user_id,
            username=new_user.username
        )
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    # 1. 查询用户
    stmt = select(UserProfile).where(
        or_(
            UserProfile.username == request.username,
            UserProfile.email == request.username
        )
    )
    result = await db.execute(stmt)
    user = result.scalars().first()

    # 💡 错误处理优化
    if not user or not verify_password(request.password, str(user.hashed_password)):
        raise HTTPException(status_code=400, detail="账号或密码错误")

    access_token = create_access_token(subject=str(user.user_id))

    return TokenResponse(
        message="登录成功",
        data=TokenData(
            access_token=access_token,
            token_type="bearer",
            user_id=str(user.user_id),
            username=str(user.username)
        )
    )


@router.post("/send-reset-code")
async def send_reset_code(request: SendCodeRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(UserProfile).where(UserProfile.email == request.email))
    user = result.scalars().first()

    if not user:
        raise HTTPException(status_code=400, detail="该邮箱尚未注册")

    code = f"{random.randint(0, 999999):06d}"
    expire_time = datetime.now(timezone.utc) + timedelta(minutes=10)

    verification = VerificationCode(email=request.email, code=code, expires_at=expire_time)
    db.add(verification)
    await db.commit()

    print(f"【系统邮件】正在发送验证码 {code} 到 {request.email}")
    return {"code": 200, "message": "验证码已发送至您的邮箱"}


@router.post("/reset-password")
async def reset_password(request: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    # 1. 验证码校验
    stmt = select(VerificationCode).where(
        VerificationCode.email == request.email,
        VerificationCode.code == request.code,
        VerificationCode.is_used == 0,
        VerificationCode.expires_at > datetime.now(timezone.utc)
    )
    result = await db.execute(stmt)
    record = result.scalars().first()

    if not record:
        raise HTTPException(status_code=400, detail="验证码无效或已过期")

    # 2. 用户查询
    user_result = await db.execute(select(UserProfile).where(UserProfile.email == request.email))
    user = user_result.scalars().first()

    if not user:
        raise HTTPException(status_code=400, detail="该邮箱绑定的用户不存在")

    # 💡 3. 密码重置入库前校验
    validate_password_length(request.new_password)
    user.hashed_password = get_password_hash(request.new_password)
    record.is_used = 1
    await db.commit()

    return {"code": 200, "message": "密码重置成功"}