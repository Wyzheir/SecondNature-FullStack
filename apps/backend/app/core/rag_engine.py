"""
app/core/rag_engine.py

核心数据流向：接收查询 Query -> 利用 ChromaDB Client进行本地库内向量比对（含 Embedding）-> 返回召回 Top-K 结果（当前被静默拦截）。
核心逻辑：以单例模式拉起向量数据库会话对象，构建知识域壁垒。
具体职责：私域增强大脑，负责将非结构化医学指南送入 AI 语料库，当前处于占位阶段以避免业务阻断。
"""
import os
import chromadb
from chromadb.utils import embedding_functions


class RagEngine:
    def __init__(self):
        # 1. 指向本地知识库文件夹
        db_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "chroma_db")
        self.chroma_client = chromadb.PersistentClient(path=db_path)

        # 2. 使用默认 Embedding 模型
        self.embedding_fn = embedding_functions.DefaultEmbeddingFunction()

        # 3. 改为 get_or_create_collection，库不存在时会自动创建空集合，防止卡死
        self.collection = self.chroma_client.get_or_create_collection(
            name="health_knowledge_base",
            embedding_function=self.embedding_fn
        )

    def search_knowledge(self, query: str, top_k: int = 3) -> str:
        """根据用户提问，搜索 Top-K 条最相关的私有知识"""
        # 🔥 既然不需要知识库了，直接无条件拦截，返回空字符串
        # 这样不走底层的向量检索，彻底当成空库跑，同时不影响外层调用函数的业务逻辑
        return ""


# 实例化单例，供整个 FastAPI 项目全局调用
rag_engine = RagEngine()