# ChatGenerationStateService 方法说明

> 对应类图：`ChatGenerationStateService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `createGeneration` | 创建新的生成任务快照并标记为用户当前活跃生成。 |
| `appendChunk` | 向生成任务追加流式文本块并续期 TTL。 |
| `updateReferenceMappings` | 更新生成任务的引用映射。 |
| `markCompleted` | 标记生成任务为已完成，写入最终内容并清理活跃状态。 |
| `markFailed` | 标记生成任务为失败，记录错误信息。 |
| `markCancelled` | 标记生成任务为用户取消。 |
| `getGeneration` | 按 generationId 查询生成任务快照。 |
| `getGenerationForUser` | 按 generationId 查询，同时校验是否属于指定用户。 |
| `getActiveGenerationForUser` | 查询用户当前活跃的生成任务。 |
