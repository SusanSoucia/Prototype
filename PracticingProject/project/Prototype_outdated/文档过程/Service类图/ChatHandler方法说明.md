# ChatHandler 方法说明

> 对应类图：`ChatHandler.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `processMessage` | 接收用户消息，执行 ReAct 循环（检索→思考→工具调用→生成），将流式回复推送到 WebSocket。 |
| `stopResponse` | 取消指定 generationId 的正在进行的 AI 生成。 |
| `getReferenceMd5` | 根据 generationId 和引用编号查询引用文件的 MD5。 |
| `getReferenceDetail` | 根据 generationId 和引用编号查询完整的引用详情（来源文件、片段、得分等）。 |

## 私有方法（核心流程）

| 方法 | 说明 |
|---|---|
| `runReActLoop` | 执行 ReAct 循环：构建上下文 → 搜索知识库 → LLM 决策工具调用 → 流式输出最终答案。 |
| `runReActLoopSafely` | 带异常保护的 ReAct 循环包装器。 |
| `executeToolForReAct` | 执行 LLM 决定的单个工具调用并返回结果。 |
| `streamReActTurnBlocking` | 阻塞式执行一次 ReAct 流式对话轮次。 |
| `finalizeResponse` | 对话完成后持久化记录、更新会话历史、发送完成通知。 |
| `persistConversation` | 将对话持久化到 MySQL 并更新会话历史（Redis）。 |
| `buildContext` | 将检索结果拼接为 LLM 上下文文本。 |
