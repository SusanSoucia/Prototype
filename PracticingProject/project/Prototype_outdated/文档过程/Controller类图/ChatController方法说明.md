# ChatController 方法说明

> 对应类图：`chatcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `getWebSocketToken` | 验证用户身份后生成并返回一个 WebSocket 指令 Token（cmdToken），供前端建立 WebSocket 连接时用于发送停止生成等控制指令。 |
| `getGeneration` | 根据指定的生成任务 ID 查询该任务的生成状态详情，并校验是否属于当前请求用户。 |
| `getActiveGeneration` | 获取当前用户正在进行的活动生成任务状态，若无活动任务则返回空。 |
| `submitFeedback` | 接收用户对对话或生成结果的评分（rating）及可选反馈原因，调用 Agent 工具记录反馈数据。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `buildFeedbackReason` | 将反馈请求中的 reason、conversationId、generationId 字段拼接为分号分隔的原因字符串。 |
| `appendReasonPart` | 向反馈原因 StringBuilder 中追加新片段，若非首个片段则加分号分隔。 |
| `extractValidatedUserId` | 从 Authorization 请求头的 Bearer Token 中提取并校验 JWT，通过后返回用户 ID，失败返回 null。 |
| `responseBody` | 构建统一的 API 响应体（code、message、data 三字段），封装为标准 Map 结构返回。 |
