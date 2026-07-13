# UsageQuotaService 方法说明

> 对应类图：`UsageQuotaService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `reserveLlmTokens` | 为用户预留 LLM Token 配额（扣除日配额），返回预留凭证。 |
| `reserveEmbeddingTokens` | 为用户预留 Embedding Token 配额（扣除日配额），返回预留凭证。 |
| `reserveLlmTokensWithGlobalBudget` | 带全局预算检查的 LLM Token 预留，超出全局限制则拒绝。 |
| `reserveEmbeddingTokensWithGlobalBudget` | 带全局预算检查的 Embedding Token 预留，超出全局限制则拒绝。 |
| `recordChatRequest` | 记录一次对话请求（日配额计数+1）。 |
| `settleReservation` | 结算预留：按实际消耗扣减，剩余返还配额。 |
| `abortReservation` | 取消预留：全额返还已预留的 Token 配额。 |
| `getSnapshot` | 获取单个用户的当日用量快照（LLM + Embedding + 请求次数）。 |
| `getSnapshots` | 批量获取多个用户的当日用量快照。 |
| `getDailyAggregates` | 按用户列表和天数获取每日用量聚合数据。 |
| `estimateChatTokens` | 估算对话消息列表的 Token 消耗。 |
| `estimateEmbeddingTokens` | 估算文本列表的 Embedding Token 消耗。 |
| `estimateTextTokens` | 估算单段文本的 Token 数。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `reserveDailyTokens` | 对日配额窗口执行原子扣减预留。 |
| `reserveGlobalRollingTokens` | 对全局滑动窗口执行原子扣减预留。 |
| `abortReservedTokens` | 批量取消预留列表中的配额。 |
| `incrementMetricKey` | 递增 Redis 中的请求计数指标。 |
| `buildQuotaView` | 构建 QuotaView（已用/限额/剩余/请求数）。 |
| `buildQuotaKey` | 拼接 Redis 日配额 Key。 |
| `buildGlobalBudgetKey` | 拼接 Redis 全局预算滑动窗口 Key。 |
