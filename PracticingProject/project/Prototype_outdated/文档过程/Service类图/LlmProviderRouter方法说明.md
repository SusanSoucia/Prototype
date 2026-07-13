# LlmProviderRouter 方法说明

> 对应类图：`LlmProviderRouter.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `streamResponse` | 调用当前激活的 LLM 供应商，流式推送回复到客户端，完成后回调统计用量。 |
| `buildReActMessages` | 构建 ReAct 模式的消息列表（system prompt + 历史消息 + 用户问题 + 上下文）。 |
| `completeReActTurn` | 同步执行一次 ReAct LLM 调用，返回最终回复或工具调用决策。 |
| `streamReActTurn` | 流式执行一次 ReAct LLM 调用，逐块推送回复内容。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `buildClient` | 根据供应商配置创建 WebClient 实例（含超时和认证头）。 |
| `buildReActRequest` | 构建 ReAct 请求体（含工具定义、流式开关）。 |
| `parseReActTurn` | 解析 LLM 的 ReAct 响应，提取文本回复或工具调用列表。 |
| `processChunk` | 处理 SSE 流式块，提取增量文本并统计 Token 用量。 |
| `processReActStreamChunk` | 处理 ReAct 流式块，提取增量文本和工具调用 delta。 |
| `settleUsage` | 流结束后结算 Token 用量。 |
| `buildOpenAiTools` | 将 AgentTool 列表转换为 OpenAI 兼容的 tools 参数格式。 |
| `estimateToolsTokens` | 估算工具定义的 Token 开销。 |
