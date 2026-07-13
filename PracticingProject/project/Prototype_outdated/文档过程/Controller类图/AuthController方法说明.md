# AuthController 方法说明

> 对应类图：`authcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `refreshToken` | 验证前端传入的 refreshToken 有效性，提取用户身份后重新签发一对新的 accessToken 和 refreshToken，作为前端令牌刷新的后备方案。 |
| `customBackendError` | 根据请求参数中的状态码和消息动态构造并返回对应 HTTP 错误响应，用于前端自定义后端错误的联调测试。 |
