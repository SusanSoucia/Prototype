# DocumentController 方法说明

> 对应类图：`documentcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `deleteDocument` | 根据文件 MD5 删除文档及其关联数据，仅允许文件所有者或管理员操作。 |
| `reindexDocument` | 对指定文档触发重新索引，重建向量嵌入并返回实际消耗的 Token 和分块数。 |
| `retryVectorizationAsync` | 将向量化失败的文档重新加入异步向量化队列，交由后台任务重试处理。 |
| `getAccessibleFiles` | 获取当前用户有权访问的全部文件列表（含个人上传及组织标签范围内的文件），支持分页。 |
| `getUserUploadedFiles` | 获取当前用户本人上传的文件列表，包含向量化状态、Token 估算等详细信息。 |
| `downloadFileByName` | 根据文件名查找并生成文件下载链接，未登录用户仅可下载公开文件。 |
| `previewFileByName` | 根据文件名和可选的 MD5 获取文件预览内容，支持 PDF 单页模式和文本模式两种预览方式。 |
| `previewPdfPage` | 渲染指定 PDF 文件的单页为 PDF 二进制流返回，支持缓存控制，仅适用于 PDF 类型文件。 |
| `downloadFileByMd5` | 根据文件 MD5 精确查找并生成文件下载链接，支持公开文件匿名访问。 |
| `getReferenceDetail` | 根据会话 ID 和引用编号查询 AI 回复中引用的文件来源详情，包括匹配片段、得分和检索模式。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `paginateList` | 对记录列表进行内存分页，返回包含分页元信息（页码、大小、总数）的分页结果。 |
| `convertFilesToResponse` | 将 FileUpload 实体列表转换为前端所需的 Map 结构，补充组织标签名称等冗余字段。 |
| `buildPreviewResponse` | 根据文件类型（文本/PDF/图片）构建预览响应数据，PDF 可选单页模式。 |
| `buildSinglePagePreviewUrl` | 拼接 PDF 单页预览的请求 URL，包含 fileMd5 和 pageNumber 参数。 |
| `getPreviewType` | 根据文件扩展名判断预览类型（text/pdf/image/download）。 |
| `getFileExtension` | 从文件名中提取扩展名（不含点号），无扩展名时返回空字符串。 |
| `resolveRequestAuthContext` | 从 Authorization 头和 fallbackToken 参数中提取 JWT 并解析出 userId 和 orgTags。 |
| `extractBearerToken` | 从 Authorization 请求头中剥离 "Bearer " 前缀，提取纯 JWT 字符串。 |
| `getOrgTagName` | 根据组织标签 ID 查询并返回对应的标签名称，找不到时返回原 ID。 |
