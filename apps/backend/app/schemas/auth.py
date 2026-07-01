from pydantic import BaseModel, Field

class LoginRequest(BaseModel):
    """
    接收前端登录请求的参数
    """
    username: str = Field(..., description="用户名")
    password: str = Field(..., description="密码")

class TokenData(BaseModel):
    access_token: str
    token_type: str
    user_id: str | None = None
    username: str | None = None

class TokenResponse(BaseModel):
    """
    标准的成功返回结构
    """
    code: int = Field(default=200)
    message: str = Field(default="登录成功")
    data: TokenData



from typing import Optional
from pydantic import BaseModel, Field, EmailStr

class UserRegisterRequest(BaseModel):
    """
    用户注册入参契约
    """
    username: str = Field(..., min_length=3, max_length=64, description="用户名")
    password: str = Field(..., min_length=6, max_length=20, description="密码 (6-20位)")
    email: Optional[EmailStr] = Field(None, description="选填电子邮箱")

class RegisterResponse(BaseModel):
    """
    注册成功返回结构（包含自动登录 Token）
    """
    code: int = Field(default=200)
    message: str = Field(default="注册成功")
    data: TokenData  # 复用之前定义的 TokenData 结构




from pydantic import BaseModel, EmailStr, Field

class SendCodeRequest(BaseModel):
    email: EmailStr = Field(..., description="注册时的邮箱")

class ResetPasswordRequest(BaseModel):
    email: EmailStr = Field(..., description="注册时的邮箱")
    code: str = Field(..., min_length=6, max_length=6, description="6位验证码")
    new_password: str = Field(..., min_length=6, max_length=20, description="新密码")