# Group45 Backend 功能实现分析报告

> 分析日期：2026-07-01
> 代码仓库：https://github.com/AsRe6666/group45-backend

---

## 一、技术栈

| 类别 | 技术 |
|------|------|
| 语言 | Java 17 |
| 框架 | Spring Boot 3.5.15 |
| 构建 | Maven |
| 关系数据库 | MySQL 8（Spring Data JPA / Hibernate） |
| 搜索引擎 / 向量库 | Elasticsearch 8.10.0（IK 中文分词，dense_vector 2048维 cosine） |
| 缓存 | Redis（Spring Data Redis） |
| 消息队列 | Apache Kafka（文件异步处理链路） |
| 对象存储 | MinIO（文件上传） |
| 认证 | JWT（jjwt 0.11.5）+ BCrypt |
| LLM 客户端 | Spring WebFlux（响应式流式） |
| LLM 提供商 | DeepSeek、阿里云 Qwen（DashScope）、智谱 AI |
| Embedding | DashScope text-embedding-v4（2048维），可切换 |
| PDF/OCR | LiteParse CLI、Apache Tika、阿里云 OCR SDK、Tesseract |
| 中文 NLP | HanLP（portable 1.8.6） |
| 测试 | JUnit 5、H2 内存库、Spring Security Test |

---

## 二、目录结构总览

```
backend/
├── .env.example                    # 环境变量模板
├── .gitignore
├── README.md
├── pom.xml                         # Maven 构建文件
├── scripts/                        # 脚本（空，仅 .gitkeep）
└── src/
    ├── main/
    │   ├── java/com/group45/backend/
    │   │   ├── Group45BackendApplication.java   # 主入口
    │   │   ├── client/              # 外部 API 客户端
    │   │   │   ├── DeepSeekClient.java          # LLM API（SSE 流式）
    │   │   │   └── EmbeddingClient.java         # Embedding API
    │   │   ├── config/              # Spring 配置
    │   │   │   ├── AiProperties.java
    │   │   │   ├── AsyncExecutorConfig.java
    │   │   │   ├── DotenvEnvironmentPostProcessor.java
    │   │   │   ├── EsConfig.java
    │   │   │   ├── EsIndexInitializer.java
    │   │   │   ├── LoggingInterceptor.java
    │   │   │   ├── ProductionConfigValidator.java
    │   │   │   ├── QuotaConfiguration.java
    │   │   │   ├── RateLimitProperties.java
    │   │   │   ├── RedisConfig.java
    │   │   │   ├── UsageQuotaProperties.java
    │   │   │   ├── WebClientConfig.java
    │   │   │   ├── WebConfig.java               # CORS + UTF-8
    │   │   │   └── WebSocketConfig.java
    │   │   ├── consumer/            # Kafka 消费者（空，未实现）
    │   │   ├── controller/          # REST API 控制器
    │   │   │   ├── ChatController.java
    │   │   │   ├── ConversationController.java
    │   │   │   ├── ConversationSessionController.java
    │   │   │   ├── HealthController.java
    │   │   │   └── SearchController.java
    │   │   ├── entity/              # DTO / API 实体
    │   │   │   ├── EsDocument.java
    │   │   │   ├── Message.java
    │   │   │   ├── SearchRequest.java
    │   │   │   ├── SearchResult.java
    │   │   │   └── TextChunk.java
    │   │   ├── exception/           # 自定义异常
    │   │   │   ├── CustomException.java
    │   │   │   └── RateLimitExceededException.java
    │   │   ├── handler/             # WebSocket 处理器
    │   │   │   └── ChatWebSocketHandler.java
    │   │   ├── model/               # JPA 实体（数据库模型）
    │   │   │   ├── Conversation.java
    │   │   │   ├── ConversationSession.java
    │   │   │   ├── DailyReqCountStat.java
    │   │   │   ├── DailyUsageStat.java
    │   │   │   ├── DocumentVector.java
    │   │   │   ├── FileUpload.java
    │   │   │   ├── ModelProviderConfig.java
    │   │   │   ├── OrganizationTag.java
    │   │   │   ├── User.java
    │   │   │   ├── UserDailyChatCount.java
    │   │   │   └── UserTokenRecord.java
    │   │   ├── repository/          # JPA & Redis 仓库
    │   │   │   ├── ConversationRepository.java
    │   │   │   ├── ConversationSessionRepository.java
    │   │   │   ├── DocumentVectorRepository.java
    │   │   │   ├── FileUploadRepository.java
    │   │   │   ├── ModelProviderConfigRepository.java
    │   │   │   ├── OrganizationTagRepository.java
    │   │   │   ├── RedisRepository.java
    │   │   │   ├── UserDailyChatCountRepository.java
    │   │   │   ├── UserRepository.java
    │   │   │   └── UserTokenRecordRepository.java
    │   │   ├── service/             # 业务逻辑
    │   │   │   ├── AgentToolRegistry.java        # ReAct 工具注册（4个工具）
    │   │   │   ├── ChatGenerationStateService.java
    │   │   │   ├── ChatHandler.java              # 核心：ReAct 循环 + 流式生成
    │   │   │   ├── ChatSessionRegistry.java
    │   │   │   ├── ConversationService.java
    │   │   │   ├── ElasticsearchService.java
    │   │   │   ├── HybridSearchService.java      # KNN + BM25 混合检索
    │   │   │   ├── LlmProviderRouter.java        # LLM 路由 + SSE 流处理
    │   │   │   ├── ModelProviderConfigService.java
    │   │   │   ├── OrgTagCacheService.java
    │   │   │   ├── RateLimitService.java
    │   │   │   ├── TokenCacheService.java
    │   │   │   ├── UsageBalanceDashboardService.java
    │   │   │   ├── UsageBalanceQuotaService.java
    │   │   │   ├── UsageDashboardService.java
    │   │   │   ├── UsageQuotaService.java
    │   │   │   ├── UserService.java
    │   │   │   ├── UserTokenService.java
    │   │   │   └── VectorizationService.java
    │   │   └── utils/               # 工具类
    │   │       ├── HttpRequestUtil.java
    │   │       ├── JsonUtil.java
    │   │       ├── JwtUtils.java
    │   │       ├── LogUtils.java
    │   │       ├── PasswordUtil.java
    │   │       └── SecretCryptoService.java
    │   └── resources/
    │       ├── application.yml
    │       ├── application-dev.yml
    │       ├── application-prod.yml
    │       ├── es-mappings/knowledge_base.json
    │       └── logback-spring.xml
    └── test/java/com/group45/backend/
        ├── Group45BackendApplicationTests.java
        └── controller/HealthControllerTests.java
```

---

## 三、现有 API 端点

| 方法 | 路径 | 控制器 | 功能 |
|------|------|--------|------|
| GET | `/api/health` | HealthController | 健康检查 |
| GET | `/api/v1/chat/websocket-token` | ChatController | 获取 WS 停止指令 Token |
| GET | `/api/v1/chat/generation/{generationId}` | ChatController | 查询生成任务状态 |
| GET | `/api/v1/chat/active-generation` | ChatController | 获取用户当前活动生成 |
| POST | `/api/v1/chat/feedback` | ChatController | 提交用户反馈（好/差评） |
| GET | `/api/v1/users/conversation` | ConversationController | 查询对话历史（按日期或会话ID） |
| GET | `/api/v1/users/conversations` | ConversationSessionController | 列出用户所有会话 |
| POST | `/api/v1/users/conversations` | ConversationSessionController | 创建新会话 |
| PUT | `/api/v1/users/conversations/{id}/archive` | ConversationSessionController | 归档会话 |
| PUT | `/api/v1/users/conversations/{id}/unarchive` | ConversationSessionController | 取消归档 |
| PUT | `/api/v1/users/conversations/{id}/switch` | ConversationSessionController | 切换当前会话 |
| GET | `/api/v1/search/hybrid` | SearchController | 混合检索（关键词 + 向量） |
| WS | `/chat/{token}` | ChatWebSocketHandler | WebSocket 实时流式聊天 |

**共 12 个 REST 端点 + 1 个 WebSocket 端点**

---

## 四、✅ 已完整实现的功能

### 4.1 核心 RAG 聊天链路（完整）

- **WebSocket 实时通信**：JWT 认证、心跳保活、会话注册/注销
- **ReAct Agent 循环**：最多 4 轮推理、最多 8 次工具调用
- **流式 LLM 生成**：SSE 流式接收、逐块推送前端、主动取消
- **Agent 工具体系**（4 个工具）：
  - `search_knowledge` — 混合检索（KNN + BM25 + 权限过滤）
  - `generate_summary` — LLM 摘要生成（流式）
  - `submit_feedback` — 用户反馈存储
  - `knowledge_stats` — 知识库统计
- **引用映射**：`[1] (文件名 | 第X页)` 编号 → fileMd5/pageNumber 映射，前后端对齐
- **对话持久化**：MySQL 事务落库 + Redis 短期历史，双写一致性
- **生成状态管理**：Redis 存储 streaming/completed/failed/cancelled 状态

### 4.2 对话管理（完整）

- 会话创建/列表/归档/取消归档/切换
- 对话历史查询（按时间范围或按 conversationId）
- 自动创建会话（取用户最新 active 会话或新建）

### 4.3 安全与配额（完整）

- JWT 认证 + BCrypt 密码加密
- 滑动窗口限流（注册、登录、聊天、LLM 请求、Embedding 请求）
- Token 配额管理（每日重置 或 Token 总量消费，可切换）
- Token 黑名单 + Refresh Token 管理

### 4.4 AI 基础设施（完整）

- 多 LLM 提供商支持（DeepSeek / Qwen / ZhipuAI）
- 多 Embedding 提供商支持（阿里云 DashScope / 智谱 AI）
- API Key 加密存储（AES-GCM）
- 连接测试功能
- 运行时配置热更新

---

## 五、❌ 缺少 REST 控制器（业务逻辑已有，未暴露端点）

### 5.1 用户认证（AuthController 缺失）

| 前端期望的端点 | 后端已有的业务逻辑 | 状态 |
|---------------|-------------------|------|
| `POST /users/login` | `UserService.authenticateUser()` | 业务逻辑完整，缺 Controller |
| `POST /users/register` | `UserService.registerUser()` | 业务逻辑完整，缺 Controller |
| `POST /users/logout` | `TokenCacheService` 已实现 | 业务逻辑完整，缺 Controller |
| `GET /users/me` | `JwtUtils.extractUserIdFromToken()` | 缺 Controller |
| `POST /auth/refreshToken` | `JwtUtils.generateRefreshToken()` | 缺 Controller |

### 5.2 组织标签管理（OrgTagController 缺失）

| 前端期望的端点 | 后端已有的业务逻辑 | 状态 |
|---------------|-------------------|------|
| `GET /admin/org-tags/tree` | `UserService.getOrganizationTagTree()` | 业务逻辑完整（含递归树构建），缺 Controller |
| `POST /admin/org-tags` | `UserService.createOrganizationTag()` | 含 tagId 自动生成/冲突处理/父标签验证，缺 Controller |
| `PUT /admin/org-tags/{tagId}` | `UserService.updateOrganizationTag()` | 含循环检测/缓存失效，缺 Controller |
| `DELETE /admin/org-tags/{tagId}` | `UserService.deleteOrganizationTag()` | 含子标签/用户/文档占用检查，缺 Controller |
| `GET /users/org-tags` | `UserService.getUserOrgTags()` | 含缓存 + 详情聚合，缺 Controller |

### 5.3 知识库文档管理（DocumentController 缺失）

| 前端期望的端点 | 后端已有基础 | 状态 |
|---------------|-------------|------|
| `GET /documents/accessible` | `FileUploadRepository` 存在 | 缺 Service + Controller |
| `GET /documents/preview` | MinIO 客户端已配置 | 缺 Service + Controller |
| `GET /documents/download-by-md5` | MinIO 客户端已配置 | 缺 Service + Controller |
| `DELETE /documents/{fileMd5}` | `ElasticsearchService.deleteByQuery()` | 缺 Service + Controller |
| `POST /documents/{fileMd5}/vectorization/retry` | `VectorizationService` 存在 | 缺 Controller |
| `GET /documents/reference-detail` | `ChatHandler.getReferenceDetail()` | 缺 Controller 暴露 |

### 5.4 文件上传（UploadController 缺失）

| 前端期望的端点 | 说明 | 状态 |
|---------------|------|------|
| `POST /upload/chunk` | 分片上传（5MB/片，最多4并发） | MinIO 已配置，缺 Controller |
| `POST /upload/merge` | 合并分片，触发 Kafka 解析+向量化 | 缺 Controller |
| `GET /upload/status` | 查询上传进度 | `FileUploadRepository` 存在，缺 Controller |

### 5.5 用户管理（UserController 缺失）

| 可用业务逻辑 | 状态 |
|-------------|------|
| `UserService.getUserList()` | 分页+过滤（关键词/组织标签/状态），缺 Controller |
| `UserService.assignOrgTagsToUser()` | 含私人标签保护逻辑，缺 Controller |
| `UserService.createAdminUser()` | 管理员创建管理员，缺 Controller |

### 5.6 模型配置管理（ModelProviderController 缺失）

| 可用业务逻辑 | 状态 |
|-------------|------|
| `ModelProviderConfigService.getCurrentSettings()` | 获取所有 LLM/Embedding 提供商配置 |
| `ModelProviderConfigService.updateScope()` | 更新提供商配置（API Key/模型/启用） |
| `ModelProviderConfigService.testConnection()` | 连接测试（含错误诊断） |

### 5.7 使用量仪表盘（DashboardController 缺失）

| 可用业务逻辑 | 状态 |
|-------------|------|
| `UsageDashboardService` / `UsageBalanceDashboardService` | 用量统计、排名、告警 |

---

## 六、❌ 完全缺失（既无 Controller 也无 Service）

| 功能 | 说明 |
|------|------|
| 路由权限端点（`/route/*`） | 前端当前使用 static 模式，不需要；仅 dynamic 模式需要 |
| Kafka Consumer 实现 | `consumer/` 包存在但为空，文件「解析 → 切块 → 向量化 → ES 索引」的异步链路未实现 |
| `RateLimitConfigService` | 被 `RateLimitService` 引用但文件不存在（可能是编译期接口，运行时不需要） |

---

## 七、路径前缀不匹配

- **后端 Controller** 统一使用 `/api/v1/` 前缀
- **前端请求** 不带 `/api/v1/` 前缀

部署时需要在 Nginx/网关层或 Vite 代理层统一，例如：

```nginx
# Nginx 方案
location /api/v1/ {
    proxy_pass http://backend:8081;
}
```

或在前端 axios baseURL 中补齐 `/api/v1` 前缀。

---

## 八、数据库表一览

| 表名 | 用途 |
|------|------|
| `users` | 用户（username, password, role, org_tags, primary_org） |
| `conversations` | 对话消息（question, answer, referenceMappings JSON） |
| `conversation_sessions` | 对话会话（title, status: ACTIVE/ARCHIVED） |
| `document_vectors` | 文档向量元数据（fileMd5, chunkId, textContent, orgTag） |
| `file_upload` | 文件上传记录（状态、向量化进度、token 估算） |
| `model_provider_configs` | AI 模型提供商配置（API Key 加密存储） |
| `organization_tags` | 组织标签（层级结构, parentTag, 上传大小限制） |
| `user_daily_chat_count` | 用户每日对话次数统计 |
| `user_token_record` | Token 消费记录（流水账） |

**Elasticsearch 索引**：`knowledge_base`（dense_vector 2048维 + IK 分词器）

---

## 九、总结

| 维度 | 评估 |
|------|------|
| 核心 RAG 链路 | ✅ 完整实现，质量高 |
| 对话管理 | ✅ 完整实现 |
| 安全/限流/配额 | ✅ 完整实现 |
| AI 基础设施 | ✅ 完整实现（多提供商、加密、热更新） |
| 用户认证端点 | ❌ Service 已有，缺 Controller |
| 组织标签端点 | ❌ Service 已有，缺 Controller |
| 知识库文档端点 | ❌ 大部分缺失 |
| 文件上传端点 | ❌ 缺失 |
| 用户管理端点 | ❌ Service 已有，缺 Controller |
| 异步处理链路 | ❌ Kafka Consumer 未实现 |
| 路由权限端点 | ➖ 仅 dynamic 模式需要，当前 static 模式不需要 |

**整体评估**：后端核心的 RAG 聊天、检索、对话管理链路已完整实现且质量较高（ReAct Agent 循环、流式 SSE、引用映射、多 LLM 提供商、配额管理都比较完善）。**约 60% 的辅助功能（认证、组织标签、文档管理、文件上传）的业务逻辑已在 Service 层写好，仅缺少对应的 REST Controller 来暴露 HTTP 接口**。补全这些 Controller 即可让前后端完全对接。
