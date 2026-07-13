# 前端重构 — 后端 API 需求记录

> 日期：2026-07-05
> 用途：供后续后端重构 Agent 使用
> 关联文档：`.claude.md`（项目重构方案 v2.0）

---

## 一、前端已完成的改造概述

前端已完成以下改造，需要后端配合实现对应的 API：

### 1. 角色化路由（已完成）
- 三种角色：ADMIN / LIBRARY_ADMIN / USER
- 路由级权限过滤已就绪，后端需在 `/api/v1/auth/me` 返回正确的 `role` 字段

### 2. 知识库页面角色化改造（已完成前端部分）
- ADMIN：可查看所有库文档、按库过滤、创建新库、委托库管
- LIBRARY_ADMIN：只能管理自己标签下的文档
- 详情见下方 P1 需求

---

## 二、新 API 需求（按优先级排列）

### P0 - 认证（AuthController）
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/logout`
- `GET  /api/v1/auth/me` → 返回 UserInfo { id, userName, role, orgTags, primaryOrg }
- `POST /api/v1/auth/refresh`

### P0 - 用户信息
- `GET /api/v1/users/me` → 需要返回 `role` 字段包含 `'LIBRARY_ADMIN'`

### P1 - 知识库管理（KnowledgeBaseController）⚠ 新需求

**核心设计：一个知识库 = 一个库管标签（org tag）= ES 中一个逻辑隔离的向量空间**

#### `POST /api/v1/admin/knowledge-bases`
创建新知识库，在创建标签的同时在 ES 中建立隔离的向量索引。

请求体：
```json
{
  "name": "研发部知识库",
  "tagId": "rd_dept",
  "description": "研发部专用知识库"
}
```

后端需完成：
1. 创建 org tag（调用已有逻辑）
2. 创建 ES 索引 `knowledge_base_{tagId}`（逻辑隔离的向量存储空间）
3. 创建 `KbTagAccess` 映射（tag → ES 索引）
4. 后续上传到此标签的文档自动路由到对应 ES 索引

#### 改造文档索引写入流程
- 当前：所有文档写入默认 `knowledge_base` 索引
- 目标：根据文档的 `orgTag` 字段决定写入哪个 ES 索引（`knowledge_base_{tagId}`）
- 相关服务：`ElasticsearchService.bulkIndex()`

#### 改造搜索流程
- 当前：`HybridSearchService.searchWithPermission()` 仅搜索 `DEFAULT_INDEX_NAME`
- 目标：使用已有的 `searchAcrossIndices()` 方法，根据用户可访问的知识库列表搜索对应 ES 索引
- 依赖：`KbTagAccessService.getAccessibleKbs()` 已可返回用户可访问的 ES 索引列表

### P1 - 用户监控（UserMonitorController）
- `GET /api/v1/admin/monitor/users`
- `GET /api/v1/admin/monitor/users/{id}/conversations`
- `GET /api/v1/admin/monitor/users/{id}/tokens`

### P1 - 仪表盘（DashboardController）
- `GET /api/v1/admin/dashboard/usage`
- `GET /api/v1/admin/dashboard/rankings`
- `GET /api/v1/admin/dashboard/alerts`

### P1 - 组织标签（OrgTagController）
- `GET /api/v1/admin/org-tags/tree`
- `POST /api/v1/admin/org-tags`
- `PUT /api/v1/admin/org-tags/{tagId}`
- `DELETE /api/v1/admin/org-tags/{tagId}`

### P2 - 文档管理（DocumentController）
- `GET /api/v1/documents/accessible`（支持按库过滤）
- `DELETE /api/v1/documents/{fileMd5}`
- `POST /api/v1/documents/{fileMd5}/vectorization/retry`
- `GET /api/v1/documents/preview`
- `GET /api/v1/documents/download-by-md5`

### P2 - 文件上传（UploadController）
- `POST /api/v1/upload/chunk`
- `POST /api/v1/upload/merge`
- `GET /api/v1/upload/status`

---

## 三、已有 API（前端已对接）
- ✅ `GET /api/v1/users/conversation`
- ✅ `GET/POST /api/v1/users/conversations`
- ✅ `PUT /api/v1/users/conversations/{id}/archive|unarchive|switch`
- ✅ `GET /api/v1/search/hybrid`
- ✅ `WebSocket /chat/{token}`
- ✅ `GET /api/v1/admin/org-tags/tree`
- ✅ `POST /api/v1/admin/org-tags`
- ✅ `PUT /api/v1/admin/org-tags/{tagId}`
- ✅ `DELETE /api/v1/admin/org-tags/{tagId}`
- ✅ `GET /api/v1/admin/users/list`
- ✅ `PUT /api/v1/admin/users/{userId}/org-tags`
- ✅ `POST /api/v1/admin/users/create-admin`

---

## 四、关键后端行为说明

### 角色自动升级/降级（已实现，需保持）
`UserService.assignOrgTagsToUser()` 已实现：
- USER 获得真实标签 → 自动升级为 LIBRARY_ADMIN
- LIBRARY_ADMIN 失去所有真实标签 → 自动降级为 USER
- ADMIN 不受此逻辑影响

### ES 索引隔离（P1 新需求核心）
当前已有基础设施但未接入主流程：
- `HybridSearchService.searchAcrossIndices()` — 跨多 ES 索引搜索（已存在）
- `KbTagAccessService` — 管理标签→索引映射（已存在）
- `ElasticsearchService.bulkIndex(docs, indexName)` — 支持指定索引写入（已存在）

需要接入主流程：
1. 创建库时同步创建 ES 索引
2. 文档上传时根据 orgTag 路由到对应索引
3. 搜索时根据用户可访问的索引列表进行跨索引搜索
