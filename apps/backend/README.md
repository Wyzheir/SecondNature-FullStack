# SecondNature Backend 

一款基于 FastAPI 异步生态构建的生产级 AI 智能健康管理应用后端。本项目不仅实现了完备的端云分布式同步逻辑，更深度融合了大语言模型（LLM）的多模态感知与智能化意图编排。



---

##  核心技术亮点与架构设计

### 1. 分布式高并发防刷限流机制 (`Redis` 驱动)
* **原子令牌桶**：基于 Redis 异步连接池（`redis.asyncio`）构建分布式限流大闸，通过 Redis Pipeline（管道技术）将 `INCR` 和 `EXPIRE` 封装为原子操作，最大程度压榨公网 IO 性能，对核心 AI 接口实施单 IP 频率锁定（10次/min），超限精准抛出 `HTTP 429`。
* **高可用降级兜底**：限流模块具备大厂级弹性防线。若 Redis 服务发生公网瞬断或波动，限流引擎自动切换为安全降级放行模式，保障核心 AI 对话业务绝不中断。

### 2. 弱网无感全量数据同步与事务一致性
* **登记员模式 Upsert**：全面摒弃数据库传统自增 ID，深度对齐移动端（Flutter/SQLite）生成的 UUID 物理主键。在云端设计并实现了批处理（Batch Upsert）同步引擎。
* **连带指标动态重算**：在单个 MySQL 异步事务（`AsyncSession`）中，一旦批次流水内包含体重（`WEIGHT`）变更，系统会自动旁路调度 `Mifflin-St Jeor` 算力中心，实时重算用户的 BMR、TDEE 及三大常量营养素（碳水/蛋白/脂肪）克数并连带回写用户主表。任何环节崩溃自动整体回滚，确保绝对的数据一致性。

### 3. 多模态 AI 混合编排与生理状态机注入
* **智能化意图分发**：设计了轻量级双轨路由网关。利用 LLM 预判将日常问候（`SIMPLE`）与专业健康咨询（`COMPLEX`）在路由层前置分发，降维节约商业 API 调用成本。
* **具备“生理记忆”的 RAG 伴诊**：多模态请求（文本/图像分析）打入后，后端深度劫持状态机，将用户动态实时热量、今日摄入/消耗明细等 physiological context 全量注入 Prompt 上下文，配合 HTTP `SSE (Server-Sent Events)` 长链接实现低延迟流式打字机渲染。

### 4. 三级全量内容安全审计与反洗脑干预
* **高效 DFA 硬防线**：构建零成本前置关键字前缀树链表（DFA），毫秒级瞬时过滤违规文本。
* **柔性危机拦截**：二级防线调用 LLM 进行语义风控打标（`safe` / `hard_block` / `soft_block`）。面对自残或心理绝望情绪（`soft_block`），系统触发危机干预提示词，联动 `core/resources` 静态热线底库，动态向前端下发就近的心理援助热线，实现有温度的安全控线。

---

##  技术栈清单

* **核心框架**：FastAPI (Python 异步协程生态)
* **ORM 引擎**：SQLAlchemy 2.0 (全异步驱动 `aiomysql`)
* **缓存/限流**：Redis (基于 `redis.asyncio` 异步连接池)
* **向量底座**：ChromaDB (内置 Embedding 增强)
* **大模型驱动**：OpenAI SDK 异步长连接 (对接 DeepSeek-V3 / Qwen 生态)
* **安防鉴权**：PyJWT + Passlib (Bcrypt 多轮哈希加盐，严格执行 Bcrypt 72字节长度校验限制)
* **环境工程**：Pydantic Settings v2 + Docker 容器化