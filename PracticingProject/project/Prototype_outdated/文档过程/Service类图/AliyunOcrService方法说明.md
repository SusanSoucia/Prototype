# AliyunOcrService 方法说明

> 对应类图：`AliyunOcrService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `recognize` | 调用阿里云 OCR API 对图片字节流进行文字识别，返回 JSON 识别结果。 |
| `isEnabled` | 返回 OCR 服务是否启用。 |
| `isConfigured` | 返回 OCR 服务的 AK/SK 是否已配置。 |
| `isCallbackTokenRequired` | 返回是否需要验证回调 Token。 |
| `verifyCallbackToken` | 校验传入的 Token 是否与服务端配置的回调 Token 一致。 |
