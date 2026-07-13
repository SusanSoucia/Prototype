# UsageDashboardService 方法说明

> 对应类图：`UsageDashboardService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `buildOverview` | 构建指定天数的平台用量总览（今日概况+趋势+LLM/Embedding 排行榜+告警）。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `toRankingItem` | 将用户和用量快照转换为排行榜条目。 |
| `buildAlerts` | 为用户生成用量告警列表（超 80%/90% 阈值）。 |
| `buildAlert` | 对单个配额维度生成用量告警。 |
