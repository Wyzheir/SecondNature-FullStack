"""
app/services/goal_service.py

核心数据流向：接收生理与目标变量 -> 计算 BMR 基础代谢 -> 结合运动系数算 TDEE -> 审查风控拦截 -> 按目标分配宏量克数 -> 输出方案字典。
核心逻辑：严格内聚 Mifflin-St Jeor 权威公式、体型 BMI 下限风控判定，及按增肌/减脂动态平衡的三大常量营养占比分发算法。
具体职责：健康算法算力中台，产出权威客观的热量/营养底线及警告判定，隔离数学公式与外部接口。
"""
from app.schemas.goal import GoalCreateRequest, GoalType
from app.core.exceptions import HealthRiskException


def calculate_health_strategy(req: GoalCreateRequest):
    """
    算力中心核心逻辑：计算 BMR、TDEE、目标建议及宏量营养素分配
    """
    # 1. 计算 BMR (Mifflin-St Jeor)
    s = 5 if req.gender == 1 else -161
    bmr = (10 * float(req.weight)) + (6.25 * float(req.height)) - (5 * req.age) + s

    # 2. 计算 TDEE
    tdee = bmr * float(req.activity_level)

    # 3. 计算 BMI 并进行风控阻断
    bmi = float(req.weight) / ((float(req.height) / 100) ** 2)
    if bmi < 18.5 and req.goal_type == GoalType.LOSE:
        raise HealthRiskException("您的 BMI 已偏低，系统禁止设定进一步减脂目标。")

    # 4. 根据目标类型制定策略与宏量比例
    # 默认比例 (MAINTAIN): 碳水 40%, 蛋白 30%, 脂肪 30%
    carb_ratio, protein_ratio, fat_ratio = 0.4, 0.3, 0.3

    if req.goal_type == GoalType.LOSE:
        diet_target = tdee - 500
        exercise_target = 45
        # 减脂期：提高蛋白保肌肉，适当降低碳水
        carb_ratio, protein_ratio, fat_ratio = 0.3, 0.4, 0.3

    elif req.goal_type == GoalType.GAIN:
        diet_target = tdee + 300
        exercise_target = 30
        # 增肌期：高碳水提供合成能量
        carb_ratio, protein_ratio, fat_ratio = 0.5, 0.3, 0.2

    else:
        # MAINTAIN 或前端未传目标时的默认兜底
        diet_target = tdee
        exercise_target = 20

    # 🌟 5. 计算宏量营养素克数
    # 碳水/蛋白 = 热量 / 4；脂肪 = 热量 / 9
    carbs_g = (diet_target * carb_ratio) / 4
    protein_g = (diet_target * protein_ratio) / 4
    fat_g = (diet_target * fat_ratio) / 9

    return {
        "bmr": round(bmr, 2),
        "tdee": round(tdee, 2),
        "recommended_diet_kcal": round(diet_target, 2),
        "recommended_exercise_mins": exercise_target,
        "bmi": round(bmi, 2),
        "status": "Healthy",
        # 输出克数，保留 1 位小数
        "carbs_g": round(carbs_g, 1),
        "protein_g": round(protein_g, 1),
        "fat_g": round(fat_g, 1)
    }