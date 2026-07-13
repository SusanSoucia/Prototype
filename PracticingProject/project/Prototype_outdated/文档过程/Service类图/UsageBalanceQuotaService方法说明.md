# UsageBalanceQuotaService 方法说明

> 对应类图：`UsageBalanceQuotaService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `reserveLlmTokens` | 余额模式下预留 LLM Token：检查用户 Token 余额是否足够并原子扣减。 |
| `reserveEmbeddingTokens` | 余额模式下预留 Embedding Token：按估算 Token 数检查并扣减。 |
| `recordChatRequest` | 记录一次对话请求（更新日计数）。 |
| `settleReservation` | 余额模式下结算预留：按实际消耗核减预扣的 Token。 |
| `getSnapshots` | 批量获取用户的 Token 余额快照。 |
| `getDailyAggregates` | 按用户列表获取每日 Token 消耗聚合数据。 |
