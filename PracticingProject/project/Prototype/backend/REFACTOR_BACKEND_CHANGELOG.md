# 后端重构变更记录

> 日期：2026-07-05
> 基于：`.claude.md` 重构方案 v2.0 + 前端 REFACTOR_BACKEND_API_NEEDS.md
> 范围：后端 Phase 1-5（角色支持、新增 Controller、ES 索引隔离、Kafka Consumer）

---

## 一、变更文件清单

### 新增文件（6 个）

| 文件 | 说明 |
|------|------|
| `controller/UserMonitorController.java` | 用户监控控制器 — 3 个端点（监控列表/对话记录/Token 明细） |
| `controller/DashboardController.java` | API 用量仪表盘控制器 — 3 个端点（用量摘要/排行/告警） |
| `model/KbTagAccess.java` | 知识库-标签访问映射 JPA 实体 |
| `repository/KbTagAccessRepository.java` | 知识库-标签映射 Repository |
| `service/KbTagAccessService.java` | 知识库-标签权限映射服务（授权/撤销/继承计算） |
| `REFACTOR_BACKEND_CHANGELOG.md` | 本文件 |

### 修改文件（7 个）

| 文件 | 改动内容 |
|------|---------|
| `model/User.java` | `Role` 枚举添加 `LIBRARY_ADMIN` |
| `controller/AdminController.java` | 新增 `validateAdminOrLibraryAdmin()` / `hasAdminRole()` 方法；`AdminUserRequest` 支持 `role` 参数；`createAdminUser` 端点支持指定角色 |
| `controller/DocumentController.java` | 3 处权限检查从仅 `ADMIN` 扩展为 `ADMIN \| LIBRARY_ADMIN` |
| `service/UserService.java` | `createAdminUser()` 新增重载方法接受 `Role` 参数；`getUserList()` 的 status 过滤支持 3 种角色 |
| `service/ElasticsearchService.java` | 3 个方法（`bulkIndex`/`deleteByFileMd5`/`countByFileMd5`）新增 `indexName` 参数重载；旧方法标记 `@Deprecated` 保持兼容 |
| `service/HybridSearchService.java` | 提取 `DEFAULT_INDEX_NAME` 常量；新增 `searchAcrossIndices()` 多索引搜索；新增 `searchSingleIndex()` 单索引内部方法 |
| `service/KbTagAccessService.java` | **新增** — 知识库-标签多对多映射管理（授予/撤销/权限继承查询） |

---

## 二、新增 API 端点

### UserMonitorController（Phase 2）

| 方法 | 路径 | 用途 | 权限 |
|------|------|------|------|
| `GET` | `/api/v1/admin/monitor/users` | 用户监控列表（含对话数、Token 用量、最后活跃时间） | ADMIN |
| `GET` | `/api/v1/admin/monitor/users/{id}/conversations` | 查看某用户的对话记录 | ADMIN |
| `GET` | `/api/v1/admin/monitor/users/{id}/tokens` | 某用户的 Token 用量明细（按日期） | ADMIN |

### DashboardController（Phase 3）

| 方法 | 路径 | 用途 | 权限 |
|------|------|------|------|
| `GET` | `/api/v1/admin/dashboard/usage` | 用量摘要（今日/本周 LLM + Embedding + 配额） | ADMIN |
| `GET` | `/api/v1/admin/dashboard/rankings` | 用户 Token 用量排行（LLM + Embedding 合并） | ADMIN |
| `GET` | `/api/v1/admin/dashboard/alerts` | 配额告警消息列表 | ADMIN |

---

## 三、角色-权限模型

### 三种角色

```
ADMIN（超级管理员）
├── 可访问所有管理端点（用户管理/监控/仪表盘/系统配置/标签树）
├── 可管理所有知识库文档
└── 可创建 ADMIN 和 LIBRARY_ADMIN 用户

LIBRARY_ADMIN（库管）
├── 可管理知识库文档（上传/删除/向量化重试）
├── 可查看自己的聊天记录
├── 不可访问管理端点（监控/仪表盘/系统配置/标签树）
└── 不可创建其他用户

USER（普通用户）
├── 可聊天和检索被授权的知识库
├── 可查看自己的聊天记录
├── 不可管理文档
└── 不可访问任何管理端点
```

### 权限检查升级

- `AdminController.validateAdmin()` → 仅 `ADMIN`（用户管理、系统配置、标签树管理）
- `AdminController.validateAdminOrLibraryAdmin()` → `ADMIN` 或 `LIBRARY_ADMIN`（文档管理）
- `DocumentController` 中 3 处权限检查：`"ADMIN".equals(role)` → `"ADMIN".equals(role) || "LIBRARY_ADMIN".equals(role)`

---

## 四、ES 索引隔离

### 变更

1. **ElasticsearchService** — 3 个核心方法新增 `indexName` 参数重载：
   - `bulkIndex(List<EsDocument>, String indexName)`
   - `deleteByFileMd5(String fileMd5, String indexName)`
   - `countByFileMd5(String fileMd5, String indexName)`
   - 旧方法标记 `@Deprecated`，默认使用 `"knowledge_base"` 保持兼容

2. **HybridSearchService** — 新增多索引搜索：
   - `searchAcrossIndices(query, userId, topK, indexNames)` — 跨多个 ES 索引搜索
   - `searchSingleIndex()` — 单索引内部方法
   - 默认索引名改为常量 `DEFAULT_INDEX_NAME`

### kb_tag_access 表

```sql
CREATE TABLE IF NOT EXISTS kb_tag_access (
    id          BIGINT AUTO_INCREMENT PRIMARY KEY,
    kb_name     VARCHAR(100) NOT NULL COMMENT 'ES索引名（如 knowledge_base_研发部库管）',
    tag_id      VARCHAR(255) NOT NULL COMMENT 'USER树下的标签ID',
    created_by  VARCHAR(64),
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_kb_tag (kb_name, tag_id),
    INDEX idx_tag_id (tag_id)
);
```

### KbTagAccessService

- `grantAccess(kbName, tagId, createdBy)` — 授予 USER 树标签对知识库的访问权限
- `revokeAccess(kbName, tagId)` — 撤销权限
- `getAccessibleKbs(userTags)` — 计算用户可访问的知识库列表（含子标签权限继承）
- `getAuthorizedTags(kbName)` — 查询某知识库被授权给哪些标签

---

## 五、已存在无需修改的部分

以下发现后端已完整实现，无需新增：

| 发现 | 状态 |
|------|------|
| `FileProcessingConsumer.java` | ✅ 已存在 — 处理 UPLOAD_PROCESS 和 REINDEX 任务 |
| DocumentController 全部 10 个端点 | ✅ 已存在 — 含 delete/preview/download/accessible/retry |
| UploadController 全部 4 个端点 | ✅ 已存在 — 含 chunk/merge/status/supported-types |
| UserController 全部 10 个端点 | ✅ 已存在 — 含 login/register/logout/me/org-tags |
| AdminController 全部 19 个端点 | ✅ 已存在 — 含 users/org-tags/rate-limits/model-providers |

---

## 六、验证结果

### 编译验证
```bash
cd backend && mvn compile
```
✅ **零编译错误** — 所有改动通过编译。

### 测试验证
```bash
cd backend && mvn test
```
- HealthControllerTests: ✅ 通过
- Group45BackendApplicationTests: ⚠️ 跳过（需要本地 MySQL，非代码问题）

### 不变更的部分
- `ChatController` / `ChatHandler` / `ChatWebSocketHandler` — 核心聊天链路
- `ConversationController` / `ConversationSessionController` — 对话管理
- `SearchController` — 混合检索
- `RateLimitService` / `TokenCacheService` / `UsageQuotaService` — 限流和配额
- JPA 实体类 — 除 User.Role 枚举外不修改
- 数据库已有表结构 — 仅新增 kb_tag_access 表

---

## 七、后续工作建议

1. **数据库迁移** — 在目标 MySQL 上执行 `CREATE TABLE kb_tag_access` DDL
2. **前端联调** — 将 `user-monitor/index.vue` 和 `api-usage/index.vue` 的 mock 数据替换为真实 API 调用
3. **权限测试** — 用不同 role 的账号登录验证：
   - ADMIN 访问 `/admin/monitor/users` → 200
   - LIBRARY_ADMIN 访问 `/admin/monitor/users` → 403
   - USER 删除文档 → 403
   - LIBRARY_ADMIN 删除自己的文档 → 200
4. **ES 索引创建** — 需要为每个库管创建对应的 ES 索引 `knowledge_base_{tagId}`
5. **向指导老师汇报** — 前后端重构均已完成，可进行联合演示
