# ConversationService 方法说明

> 对应类图：`ConversationService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `recordConversation` | 持久化记录一条对话（含问题、回答和引用映射），同时更新会话时间戳。 |
| `getConversationSessions` | 获取用户的所有对话会话列表，标记当前活跃会话。 |
| `createConversationSession` | 为用户创建新的空白对话会话并返回会话元信息。 |
| `ensureConversationSession` | 确保指定 conversationId 的会话存在，不存在则创建并设标题。 |
| `switchCurrentConversation` | 将用户当前活跃会话切换到指定会话。 |
| `updateSessionTitle` | 更新会话标题（如用首条消息自动命名）。 |
| `archiveConversationSession` | 将指定会话状态设为 ARCHIVED。 |
| `unarchiveConversationSession` | 将指定会话状态从 ARCHIVED 恢复为 ACTIVE。 |
| `updateSessionTitleIfDefault` | 仅当当前标题为默认标题时才更新为指定标题。 |
| `getMessagesByConversationId` | 根据 conversationId 查询该会话的全部历史消息。 |
| `getConversations` | 按用户名和时间范围查询对话记录。 |
| `getAllConversations` | 管理员按目标用户名和时间范围查询任意用户的对话记录。 |
| `toMessageHistory` | 将 Conversation 实体列表转换为前端消息格式。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `saveConversation` | 保存一条对话记录到数据库并更新会话时间。 |
| `touchSessionUpdatedAt` | 更新会话的 updatedAt 时间戳。 |
| `buildMessage` | 组装单条消息的标准 Map 结构（role/content/timestamp/reference）。 |
| `writeReferenceMappings` | 将引用映射序列化为 JSON 字符串。 |
| `parseReferenceMappings` | 将 JSON 字符串反序列化为引用映射 Map。 |
