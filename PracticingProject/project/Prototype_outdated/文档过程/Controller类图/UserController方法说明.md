# UserController 方法说明

> 对应类图：`usercontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `register` | 接收用户名、密码和邀请码创建新用户账号，按客户端 IP 进行注册频率限制。 |
| `login` | 验证用户凭证后签发 JWT（accessToken + refreshToken），按客户端 IP 进行登录频率限制。 |
| `getCurrentUser` | 根据 Token 返回当前用户的基本信息，包括用户名、角色、组织标签和主组织。 |
| `getUserOrgTags` | 获取当前用户所属的全部组织标签及其层级信息。 |
| `setPrimaryOrg` | 设置当前用户的主组织标签，用于确定文件上传时的默认归属组织。 |
| `getCurrentUserUsage` | 查询当前用户的 Token 用量快照，包括 LLM 和 Embedding 的消耗与余额。 |
| `getUploadOrgTags` | 获取当前用户上传文件时可选的候选组织标签列表及默认主组织。 |
| `logout` | 使当前请求的 JWT Token 失效，实现单设备登出。 |
| `logoutAll` | 使当前用户在所有设备上的全部 JWT Token 失效，实现全设备登出。 |
| `getTokenRecords` | 分页查询当前用户的 Token 变动记录（增加/消耗的明细及余额前后变化）。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `buildRateLimitResponse` | 构造 429（请求过多）限流错误响应，附带建议重试秒数。 |
| `resolveClientIp` | 按优先级从多级代理请求头（CF-Connecting-IP、X-Forwarded-For 等）中提取真实客户端 IP。 |
| `extractForwardedForIp` | 解析 X-Forwarded-For 头中的第一个可路由 IP 地址。 |
| `firstUsableIp` | 从多个候选 IP 中返回第一个非空且非 "unknown" 的有效 IP。 |
| `isUsableIp` | 判断 IP 字符串是否非空且不是 "unknown"。 |
