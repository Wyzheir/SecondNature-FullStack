"""
app/core/resources.py

核心数据流向：传入用户的 locale 区域码 -> 触发前缀匹配检索 -> 返回就近的静态求助字典。
核心逻辑：建立基于 zh-CN, zh-HK, en-US 等映射库的高效静态字典查询机制。
具体职责：心理援助“指南针”，为安全柔性拦截策略输送地区化、可快速拨打的防自杀危机干预热线资源。
"""

# 地区码 → 热线列表
CRISIS_RESOURCES = {
    "zh-CN": [
        {"name": "全国心理援助热线", "phone": "12320", "hours": "24小时"},
        {"name": "希望24热线", "phone": "400-161-9995", "hours": "24小时"},
        {"name": "北京心理危机研究与干预中心", "phone": "010-82951332", "hours": "24小时"}
    ],
    "zh-HK": [
        {"name": "明爱向晴轩", "phone": "18288", "hours": "24小时"},
        {"name": "撒玛利亚会", "phone": "2896 0000", "hours": "24小时"}
    ],
    "zh-TW": [
        {"name": "生命线", "phone": "1995", "hours": "24小时"},
        {"name": "张老师", "phone": "1980", "hours": "周一至六 9:00-21:00"}
    ],
    "en-US": [
        {"name": "National Suicide Prevention Lifeline", "phone": "988", "hours": "24/7"},
        {"name": "Crisis Text Line", "phone": "Text HOME to 741741", "hours": "24/7"}
    ],
    # 默认兜底
    "default": [
        {"name": "心理援助热线", "phone": "12320", "hours": "24小时"}
    ]
}


def get_crisis_resources(locale: str) -> list[dict]:
    """
    根据地区码获取热线列表，支持精确匹配和语言前缀匹配。
    - locale: 如 "zh-CN", "zh-HK", "en-US" 或 None
    - 返回热线列表，若地区未知则返回默认资源
    """
    if not locale:
        return CRISIS_RESOURCES["default"]

    # 精确匹配
    if locale in CRISIS_RESOURCES:
        return CRISIS_RESOURCES[locale]

    # 尝试匹配语言部分（如 "zh"）
    lang = locale.split("-")[0] if "-" in locale else ""
    if lang in CRISIS_RESOURCES:
        return CRISIS_RESOURCES[lang]

    return CRISIS_RESOURCES["default"]