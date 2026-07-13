# LiteParseOcrAdapterService 方法说明

> 对应类图：`LiteParseOcrAdapterService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `recognize` | 接收前端 MultipartFile，调用阿里云 OCR 后将结果转换为与 LiteParse API 兼容的格式返回。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `appendBlockResults` | 将阿里云 OCR 的块级识别结果追加到结果列表。 |
| `appendContentFallback` | 无块级结果时降级为纯文本内容。 |
| `pointsToBbox` | 将阿里云 OCR 的坐标点转换为 LiteParse 格式的 bbox。 |
| `normalizeConfidence` | 将识别置信度归一化到 0-1 区间。 |
