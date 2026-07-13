# AgentToolRegistry 方法说明

> 对应类图：`AgentToolRegistry.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `getTools` | 获取所有已注册的 Agent 工具列表（search_knowledge、generate_summary、submit_feedback、knowledge_stats）。 |
| `getTool` | 按工具名称查找单个 Agent 工具定义。 |
| `executeTool` | 执行指定的 Agent 工具并根据工具类型路由到对应处理器。 |

## 私有方法（工具处理器）

| 方法 | 说明 |
|---|---|
| `executeSearchKnowledge` | 执行知识库搜索工具：调用混合检索并将结果格式化返回。 |
| `executeGenerateSummary` | 执行摘要生成工具：调用 DeepSeek 对搜索结果进行总结。 |
| `executeSubmitFeedback` | 执行反馈提交工具：接收评分和原因并持久化。 |
| `executeKnowledgeStats` | 执行知识库统计工具：查询文件数量、总大小和最近更新时间。 |
| `searchKnowledgeTool` | 定义 search_knowledge 工具的 JSON Schema。 |
| `generateSummaryTool` | 定义 generate_summary 工具的 JSON Schema。 |
| `submitFeedbackTool` | 定义 submit_feedback 工具的 JSON Schema。 |
| `knowledgeStatsTool` | 定义 knowledge_stats 工具的 JSON Schema。 |
