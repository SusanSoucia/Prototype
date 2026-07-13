# ParseService 方法说明

> 对应类图：`ParseService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `parseAndSave` | 解析上传的文件（PDF/TXT等），按语义分块后保存文本块到 document_vectors 表。 |
| `estimateEmbeddingUsage` | 预估文件解析后的文本块的 Embedding Token 消耗和分块数量。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `checkMemoryThreshold` | 检查 JVM 内存使用率是否超过阈值，超过则中断解析。 |
| `parsePdfAndSave` | 调用 LiteParse 引擎解析 PDF，按页提取文本后分块保存。 |
| `estimatePdfEmbeddingUsage` | 预估 PDF 文件的 Embedding 用量。 |
| `parsePdfWithLiteParse` | 调用外部 LiteParse 命令解析 PDF，返回按页分组的结果。 |
| `buildLiteParseCommand` | 拼装 LiteParse 命令行参数（OCR、DPI、页数限制等）。 |
| `effectiveLiteParseOcrServerUrl` | 计算 LiteParse OCR 服务的实际回调 URL。 |
| `readLiteParsePages` | 读取 LiteParse 输出的 JSON 结果文件。 |
| `normalizeLiteParseText` | 清洗 LiteParse 输出的文本（去冗余换行、修复编码）。 |
| `splitTextIntoChunksWithSemantics` | 按语义边界（段落/句子）将文本切分为指定大小的块。 |
| `mergeSmallChunks` | 将过小的块合并到相邻块，保证最小块大小。 |
| `addSemanticOverlap` | 为分块添加语义重叠区（overlap），提升检索召回率。 |
| `splitIntoSentenceUnits` | 按句末标点和换行将文本拆分为句子单元。 |
