"""
app/api/v1/foods.py

核心数据流向：客户端因本地命中失败发起关键词检索 -> 路由网关接收 -> 在云端模拟大词库中模糊匹配 -> 下发结构化营养常数。
核心逻辑：利用 List Comprehension 实现对常量/远端数据库的低延迟遍历，提取默认的卡路里及三大宏量营养素数据。
具体职责：食物字典网关，作为前端 SQLite 本地词库的防击穿补丁，提供远端云算力模糊查询支撑。
"""
import logging
from typing import List, Optional
from fastapi import APIRouter, Query, Depends
from fastapi.responses import JSONResponse
from app.core.security import get_current_user
from pydantic import BaseModel

logger = logging.getLogger(__name__)
router = APIRouter()


# 契约定义
class FoodItem(BaseModel):
    food_name: str
    default_kcal: float
    default_carbs: float
    default_protein: float
    default_fat: float


# 模拟云端庞大的食物数据库（实际应用中这里连接 MySQL 或 ElasticSearch）
CLOUD_FOOD_DB = [
    {"food_name": "全脂牛奶", "default_kcal": 62.0, "default_carbs": 4.9, "default_protein": 3.2, "default_fat": 3.2},
    {"food_name": "脱脂牛奶", "default_kcal": 33.0, "default_carbs": 5.0, "default_protein": 3.4, "default_fat": 0.1},
    {"food_name": "牛肉面", "default_kcal": 118.0, "default_carbs": 16.5, "default_protein": 5.2, "default_fat": 3.1},
    {"food_name": "麻辣烫", "default_kcal": 95.0, "default_carbs": 8.0, "default_protein": 3.0, "default_fat": 5.5},
]


@router.get(
    "/search",
    summary="云端食物库模糊检索",
    description="当客户端本地 SQLite 词库未命中时，旁路调用此接口进行云端大词库检索"
)
def search_cloud_foods(
        keyword: str = Query(..., min_length=1, description="搜索关键词"),
        current_user: str = Depends(get_current_user)
):
    logger.info(f"🔍 [API 测试日志] 用户 {current_user} 发起云端食物检索，关键词: '{keyword}'")

    try:
        # 模拟模糊搜索逻辑
        results = [food for food in CLOUD_FOOD_DB if keyword in food["food_name"]]

        logger.info(f"✅ [API 测试日志] 检索成功，共命中 {len(results)} 条数据")
        return JSONResponse(
            status_code=200,
            content={
                "code": 200,
                "message": "success",
                "data": results
            }
        )
    except Exception as e:
        logger.error(f"❌ [API 测试异常] 云端检索崩溃: {str(e)}")
        return JSONResponse(
            status_code=500,
            content={"code": 500, "message": "云端算力引擎异常", "data": None}
        )