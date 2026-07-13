# RateLimitService 方法说明

> 对应类图：`RateLimitService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `checkRegisterByIp` | 按客户端 IP 检查注册频率是否超限，超限抛出 RateLimitExceededException。 |
| `checkLoginByIp` | 按客户端 IP 检查登录频率是否超限。 |
| `checkChatByUser` | 按用户 ID 检查对话频率是否超限。 |
| `reserveLlmUsage` | 为 LLM 调用预留 Token 配额（先检查用户配额再检查全局预算）。 |
| `checkEmbeddingQueryByUser` | 按用户检查 Embedding 查询请求频率。 |
| `reserveEmbeddingUploadUsage` | 为 Embedding 上传预留 Token 配额。 |
| `reserveEmbeddingQueryUsage` | 为 Embedding 查询预留 Token 配额。 |
