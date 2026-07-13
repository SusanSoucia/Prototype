# DocumentService 方法说明

> 对应类图：`DocumentService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `deleteDocument` | 删除指定文档及其在 MinIO、ES、DB 中的所有关联数据。 |
| `reindexDocument` | 重新解析并对文档重新向量化，返回实际 Embedding 用量。 |
| `enqueueAsyncVectorizationRetry` | 将向量化失败的文档重新加入异步处理队列。 |
| `markVectorizationProcessing` | 将文档向量化状态标记为处理中，可选重置实际用量。 |
| `markVectorizationCompleted` | 将文档向量化状态标记为已完成并记录实际用量。 |
| `markVectorizationFailed` | 将文档向量化状态标记为失败并记录错误信息。 |
| `getAccessibleFiles` | 获取用户有权访问的全部文件列表（含个人和组织范围）。 |
| `updateDocumentOrgTag` | 更新文档的组织标签并同步 ES 权限元数据。 |
| `updateDocumentVisibility` | 更新文档的公开/私有属性并同步 ES 权限元数据。 |
| `getUserUploadedFiles` | 获取用户本人上传的全部文件列表。 |
| `generateDownloadUrl` | 为指定文件生成 MinIO 预签名下载链接。 |
| `generatePreviewUrl` | 为指定文件生成 MinIO 预签名预览链接。 |
| `getFilePreviewContent` | 获取文本类文件的预览内容字符串。 |
| `getPdfSinglePagePreview` | 渲染 PDF 指定页为二进制流，支持本地缓存和 Redis 缓存。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `syncDocumentPermissionMetadata` | 更新 ES 中文档的 orgTag 和 isPublic 权限元数据。 |
| `parseOrgTags` | 将逗号分隔的组织标签字符串解析为列表。 |
| `deduplicateFileUploads` | 对同 MD5 多记录去重，保留最新版本。 |
| `generatePresignedObjectUrl` | 生成 MinIO 对象的预签名 URL（支持 inline/content-disposition）。 |
| `getCachedPdfSinglePagePreview` | 从 Redis 缓存中获取 PDF 单页预览。 |
| `isTextFile` | 根据扩展名判断文件是否为可预览的文本类型。 |
