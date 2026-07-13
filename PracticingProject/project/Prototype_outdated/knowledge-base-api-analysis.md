# 知识库页面后端 API 请求分析

知识库页面及其子组件共向 **13 个 API 调用**（去重后 **11 个不同端点**），分布在 **5 个文件** 中。

---

## 一、主页面 `frontend/src/views/knowledge-base/index.vue`

| # | 函数位置 | 请求方式 | API URL | 功能说明 |
|---|---------|---------|---------|---------|
| 1 | `apiFn()` (L20-45) | `GET` | `/documents/accessible` | **获取可访问的文档列表**，传入分页参数 `page`/`size`，前端手动做切片分页 |
| 2 | `handleDelete()` (L259) | `DELETE` | `/documents/${fileMd5}` | **删除文档**，按 MD5 删除指定文件，成功后刷新列表 |
| 3 | `handleRetryVectorization()` (L323) | `POST` | `/documents/${fileMd5}/vectorization/retry` | **重试向量化**，提交异步向量化重试任务 |
| 4 | `onBeforeUpload()` (L495) | `GET` | `/upload/status` | **查询上传进度**，参数 `file_md5`，用于断点续传时获取已上传分片信息 |

---

## 二、上传对话框 `frontend/src/views/knowledge-base/modules/upload-dialog.vue`

| # | 函数位置 | 请求方式 | API URL | 功能说明 |
|---|---------|---------|---------|---------|
| 5 | `presetSingleOrgForUser()` (L64) | `GET` | `/users/org-tags` | **获取当前用户的组织标签**，若用户只有一个组织则自动选中 |
| 6 | `<TheSelect>` 组件 (L117) | `GET` | `/users/org-tags` | **获取组织标签列表**（同上端点），供非管理员用户选择组织 |

> 依赖的 `OrgTagCascader` 组件（管理员可见）通过 `@/service/api/org-tag.ts` 调用 `GET /admin/org-tags/tree` 获取组织标签树。

---

## 三、检索对话框 `frontend/src/views/knowledge-base/modules/search-dialog.vue`

| # | 函数位置 | 请求方式 | API URL | 功能说明 |
|---|---------|---------|---------|---------|
| 7 | `search()` (L33) | `GET` | `search/hybrid` | **混合检索知识库**，参数：`userId`、`query`（关键字）、`topK`（返回结果数） |

---

## 四、上传 Store `frontend/src/store/modules/knowledge-base/index.ts`

| # | 函数位置 | 请求方式 | API URL | 功能说明 |
|---|---------|---------|---------|---------|
| 8 | `uploadChunk()` (L30) | `POST` | `/upload/chunk` | **上传文件分片**，`multipart/form-data`，携带 `file`、`fileMd5`、`chunkIndex`、`totalSize`、`fileName`、`orgTag`、`isPublic` |
| 9 | `mergeFile()` (L91) | `POST` | `/upload/merge` | **合并文件分片**，参数 `fileMd5`、`fileName`，返回 `estimatedEmbeddingTokens`、`estimatedChunkCount` |

---

## 五、文件预览组件 `frontend/src/components/custom/file-preview.vue`

| # | 函数位置 | 请求方式 | API URL | 功能说明 |
|---|---------|---------|---------|---------|
| 10 | `loadPreviewContent()` (L356, L400) | `GET` | `/documents/preview` | **获取文件预览内容**，参数 `fileName`、`fileMd5`（优先）、`pageNumber`（PDF 单页定位）；返回 `previewType`、`content`/`previewUrl`、`singlePageMode` 等 |
| 11 | `downloadFile()` (L448) | `GET` | `/documents/download-by-md5` | **获取文件下载链接**（按 MD5），优先使用 MD5 精确下载，返回预签名 URL |
| 12 | `downloadFile()` (L473) | `GET` | `/documents/download` | **获取文件下载链接**（按文件名），无 MD5 时的降级路径，参数 `fileName` |

> `loadPreviewContent()` 在两个分支中调用了两次 `/documents/preview`，逻辑相同但分别处理 "有 MD5" 和 "无 MD5 降级" 两种场景。

---

## 六、后端新增但前端尚未调用的端点

以下端点在本次后端更新中新增，但当前前端知识库页面尚未直接调用：

| 请求方式 | API URL | 功能说明 |
|---------|---------|---------|
| `POST` | `/documents/{fileMd5}/reindex` | 重建文档索引，返回 `actualEmbeddingTokens`、`actualChunkCount`、`modelVersion` |
| `GET` | `/documents/uploads` | 获取当前用户上传的所有文件列表（与 `/accessible` 不同，仅返回本人的上传记录） |
| `GET` | `/documents/page-preview` | PDF 单页预览，参数 `fileMd5`、`pageNumber`，直接返回 PDF 二进制（仅 PDF），带 ETag 缓存 |
| `GET` | `/documents/reference-detail` | 获取 RAG 引用详情，参数 `sessionId`、`referenceNumber`，返回检索模式、匹配文本、证据片段、分数等 |
| `GET` | `/upload/supported-types` | 获取服务端支持的文件类型列表 |

---

## 汇总

```text
GET    /documents/accessible                        — 文档列表（index.vue:22）
DELETE /documents/:fileMd5                          — 删除文档（index.vue:259）
POST   /documents/:fileMd5/vectorization/retry      — 重试向量化（index.vue:324）
GET    /upload/status                               — 查询上传进度（index.vue:496）
GET    /users/org-tags                              — 获取用户组织标签（upload-dialog.vue:64, :117）
GET    search/hybrid                                — 混合检索（search-dialog.vue:34）
POST   /upload/chunk                                — 上传分片（store/index.ts:31）
POST   /upload/merge                                — 合并分片（store/index.ts:92）
GET    /documents/preview                           — 文件预览，支持 pageNumber（file-preview.vue:356, :400）
GET    /documents/download-by-md5                   — 文件下载(按MD5)（file-preview.vue:448）
GET    /documents/download                          — 文件下载(按文件名降级)（file-preview.vue:473）★新增
GET    /admin/org-tags/tree                         — 组织标签树(管理员)（org-tag-cascader → org-tag.ts）
```

**共 13 个 API 调用**（去重后 11 个不同端点 + 5 个后端新增端点），覆盖文档 CRUD、分片上传/合并、向量化、混合检索、预览下载（含 PDF 单页）、组织标签等完整功能链路。

请求函数均通过 `@/service/request` 导出的 `request` 函数直接内联调用，未封装独立的 service 层。

---

## 变更记录

| 日期 | 变更内容 |
|------|---------|
| 2026-07-02 | 后端更新：新增 `DocumentController` 端点（`/reindex`、`/uploads`、`/page-preview`、`/reference-detail`、`/download`）、`UploadController` 端点（`/supported-types`）；前端 `file-preview.vue` 新增 `/documents/download` 降级下载路径，`/documents/preview` 新增 `pageNumber` 参数支持 PDF 单页定位 |
