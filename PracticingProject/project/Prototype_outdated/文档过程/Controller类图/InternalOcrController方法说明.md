# InternalOcrController 方法说明

> 对应类图：`internalocrcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `recognizeForLiteParse` | 接收前端上传的图片文件，调用 LiteParse OCR 适配服务进行文字识别，支持指定识别语言和 Token 参数。 |
| `aliyunOcrHealth` | 查询阿里云 OCR 服务的健康状态，返回服务是否启用、是否已配置及是否需要 Token 校验。 |

## 私有方法

无。
