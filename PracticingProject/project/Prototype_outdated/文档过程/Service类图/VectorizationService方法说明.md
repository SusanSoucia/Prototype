# VectorizationService 方法说明

> 对应类图：`VectorizationService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `vectorize` | 对指定文件的文本块执行 Embedding 向量化并索引到 Elasticsearch。 |
| `vectorizeWithUsage` | 对指定文件执行向量化，同时返回实际消耗的 Embedding Token 和数据块数量。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `fetchTextChunks` | 从 document_vectors 表中查询指定文件的所有未向量化文本块。 |
