"""
services/vision.py

处理用户上传的图像：安全审核 + 多模态模型分析，返回文本描述。
"""

import logging
from app.core.clients import deepseek_client, VISION_MODEL

logger = logging.getLogger(__name__)


async def check_image_safety(image_url: str) -> bool:
    """
    图像安全审查（当前为占位实现，实际生产需接入第三方内容审核 API）。
    - 返回 True 表示图片安全，False 表示违规。
    """
    # TODO: 接入鉴黄/暴恐/政治敏感识别 API
    # 目前不做真实检测，默认放行
    return True


async def analyze_image(image_url: str, prompt: str = "") -> str:
    """
    调用多模态模型分析图像，返回文字描述。
    - image_url: 图片 URL 或 base64 数据
    - prompt: 用户附带的文字说明，若为空则使用默认提示
    - 返回模型的描述文本，若失败返回空字符串
    """
    messages = [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "text": prompt or "请详细描述这张图片的内容，重点关注与健康相关的信息（如食物、体态、皮肤状况等）。"
                },
                {
                    "type": "image_url",
                    "image_url": {"url": image_url}
                }
            ]
        }
    ]
    try:
        resp = await deepseek_client.chat.completions.create(
            model=VISION_MODEL,
            messages=messages,
            max_tokens=500
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        logger.error(f"图像分析请求失败: {e}")
        return ""