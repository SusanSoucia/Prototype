# ConversationController 方法说明

> 对应类图：`conversationcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `getConversations` | 获取当前用户的持久化对话历史记录，支持按 conversationId 精确查询或按起止时间范围模糊查询。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `parseStartDate` | 将多种格式的起始时间字符串（ISO日期、日期时间、省略秒数等）解析为 LocalDateTime，解析失败则抛出异常。 |
| `parseEndDate` | 将多种格式的结束时间字符串解析为 LocalDateTime，日期格式自动补齐至当天最后一秒（23:59:59）。 |
