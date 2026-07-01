"""
app/db/base.py

核心数据流向：空向。只做类继承约束。
核心逻辑：实例化 SQLAlchemy 的 Declarative 注册元类映射字典。
具体职责：ORM 版图基石，统管所有通过此基类注册的数据模型，供 Alembic 等引擎扫描建表比对使用。
"""
from sqlalchemy.orm import declarative_base

# 创建 SQLAlchemy 的基类，所有 models 目录下的 ORM 模型都将继承它
Base = declarative_base()