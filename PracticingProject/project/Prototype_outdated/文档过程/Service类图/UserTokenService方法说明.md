# UserTokenService 方法说明

> 对应类图：`UserTokenService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `getLlmTokenBalance` | 查询用户 LLM Token 余额。 |
| `getEmbeddingTokenBalance` | 查询用户 Embedding Token 余额。 |
| `consumeLlmTokens` | 扣除用户 LLM Token 并记录消耗明细。 |
| `consumeEmbeddingTokens` | 扣除用户 Embedding Token 并记录消耗明细。 |
| `incrementUserTotalRequestCount` | 递增用户的总请求计数。 |
| `getTodayTopConsumers` | 获取当天 Token 消耗最多的前 N 名用户。 |
| `addLlmTokens` | 管理员为用户手动追加 LLM Token，记录原因和备注。 |
| `addEmbeddingTokens` | 管理员为用户手动追加 Embedding Token，记录原因和备注。 |
| `hasEnoughLlmTokens` | 检查用户 LLM Token 是否足够。 |
| `hasEnoughEmbeddingTokens` | 检查用户 Embedding Token 是否足够。 |
| `getUserTokenRecords` | 分页查询用户的 Token 变动记录列表。 |
| `getUserDailyChatCount` | 查询用户某日的对话请求次数。 |
| `updateUserDailyChatCount` | 更新用户某日的对话请求次数（+1）。 |
| `getDailyStatsByType` | 按日期范围和 Token 类型查询每日聚合统计。 |
| `getDailyReqCountStats` | 按日期范围查询每日请求次数统计。 |
| `getLowBalanceUsers` | 查询 Token 余额低于指定阈值的用户列表。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `resolveInitToken` | 计算用户初始 Token（管理员无限 or 配置默认值）。 |
| `isAdminUser` | 判断用户是否为管理员（管理员不扣 Token）。 |
| `recordTokenIncrease` | 记录 Token 增加流水。 |
| `recordTokenConsume` | 记录 Token 消耗流水。 |
| `safeAddTokenBalance` | 安全地执行余额加减（防止 null 溢出）。 |
