# HybridSearchService 方法说明

> 对应类图：`HybridSearchService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `searchWithPermission` | 基于用户权限（组织标签+公开文档）执行混合检索，向量检索+关键词检索结果融合排序。 |
| `search` | 仅搜索公开文档的混合检索，用于未登录用户。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `textOnlySearchWithPermission` | 带权限过滤的关键词检索。 |
| `textOnlySearch` | 仅公开文档的关键词检索。 |
| `embedToVectorList` | 将查询文本编码为向量（float 列表）。 |
| `buildPermissionFilter` | 构建 ES 查询的权限过滤条件（userId/organization/public）。 |
| `canAccess` | 判断当前用户是否有权访问给定文档。 |
| `resolveAccessContext` | 解析用户的权限上下文（角色+可访问组织标签集合）。 |
| `attachFileNames` | 为检索结果批量补充文件名和文件元信息。 |
