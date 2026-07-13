# ElasticsearchService 方法说明

> 对应类图：`ElasticsearchService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `bulkIndex` | 批量将文档文本块索引到 Elasticsearch 中。 |
| `deleteByFileMd5` | 按文件 MD5 删除 ES 中该文件的所有文本块索引。 |
| `countByFileMd5` | 统计指定文件在 ES 中的文本块数量。 |
| `updatePermissionMetadataByFileMd5` | 按文件 MD5 批量更新所有文本块的权限元数据（orgTag + isPublic）。 |
