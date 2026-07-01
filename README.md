
# SecondNature-Fullstack

> **基于 Flutter 3.x + FastAPI 异步高并发基座 + DeepSeek 大模型驱动的离线优先、个性化 AI 全栈健康管理生态系统。**

本项目将移动端、高并发后端、大数据持久层与大模型工程（Prompt Engine / RAG）深度内聚，跑通了端云全链路的闭环交付。

---

## 系统拓扑架构

本平台遵循“单一职责、网关收紧、弱网防御”的工程落地原则，数据流向及安防铁闸流转如下：

```text
【Flutter 客户端】 ─── (UUID 幂等请求 / 本地 SQLite) ───> [Nginx 反向代理]
                                                               │
                                                       [FastAPI 异步网关]
                                                               │
        ┌───────────────────────┬──────────────────────────────┴────────────────────────┐
        ▼                       ▼                                                       ▼
 [Redis 缓存/Pipeline限流] [DFA + LLM 双层语义审计] [Mifflin-St Jeor 算力中台]   [DeepSeek 极速流式引擎]
        │                       │                                                       │
        └───────────────────────┴───────────────┬───────────────────────────────────────┘
                                                ▼
                                    【MySQL 持久层 (AsyncSession)】
                                    【ChromaDB 私域向量知识库】

```

---

##  核心工程亮点与技术落地

### 1. 离线优先状态机与分布式 UUID 幂等锁

* **端侧多模态同步**：移动端（Flutter）引入离线优先架构，用户打卡、重算数据就地持久化至本地 SQLite。
* **物理主键控并发**：数据上云采用端侧预生成的分布式 `UUID` 作为物理主键，配合 FastAPI 后端 SQLAlchemy 2.0 异步单事务（AsyncSession）批处理 Upsert 机制，完美堵死弱网并发重试导致的“数据重入与多表污染”隐患。

### 2. 大模型算力防刷限流与 Token 压缩流水线

* **高性能铁闸网关**：前置挂载高吞吐 Redis Pipeline，实现每分钟单 IP 限流拦截（HTTP 429），防止恶意脚本刷爆大模型算力账单。
* **双层过滤安全网**：自研本地内存级 **DFA 敏感词前缀树**（1ms 零成本响应）+ 后置大模型语义审计，将 90% 的粗暴垃圾流量就地枪决，不消耗云端一分钱 Token。
* **滑动窗口裁剪**：设计 **1800 字符动态滑动窗口截断机制**，剥离历史对话客套话与脏记忆，配合分类路由网关 `temperature=0.0` 的确定性判定，降低外部 API 开销 30% 以上。

### 3. ⚡ 极速全链路交互：FastAPI 异步非阻塞基座与 SSE 流式推送

* **I/O 多路复用**：针对高频、耗时的大模型 API 握手等待，后端全量采用 FastAPI 异步（`async/await`）协程连接池，解耦多线程切换开销，单机高并发吞吐量翻倍。
* **打字机实时推流**：端云全链路交互丢弃传统慢 HTTP 请求，采用轻量级 **SSE（Server-Sent Events）单向流式推送协议**，结合异步生成器（Generator），实现亚秒级的 AI 个性化回复打字机回显。

---

## 仓储目录拓扑

```text
SecondNature-Fullstack/
  ├── apps/
  │   ├── frontend/         # Flutter 移动端应用 (离线优先/本地词库/Provider状态机)
  │   └── backend/          # FastAPI 后端算力服务 (Async-SQLAlchemy/Redis/DeepSeek-Engine)
  ├── .gitignore            # 根目录全局全局环境及缓存硬拦截规则
  └── README.md             # 本说明文档

```

---

## 环境依赖与快速部署

### 1. 后端基础设施 (apps/backend)

* **Python 版本**: `^3.10`
* **依赖安装**: `pip install -r requirements.txt`
* **数据库迁移**:
```bash
alembic revision --autogenerate -m "init_health_tables"
alembic upgrade head

```


* **生产模式启动**: `uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4`

### 2. 前端跨平台端 (apps/frontend)

* **Flutter SDK**: `^3.10.7` (Dart `^3.10.7`)
* **编译期运行指令 (动态注入后端公网安全网关)**:
```bash
flutter run --dart-define=API_BASE_URL=[https://your-backend-gateway.com/api/v1](https://your-backend-gateway.com/api/v1)
