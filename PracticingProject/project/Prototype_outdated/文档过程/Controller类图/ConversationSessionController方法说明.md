# ConversationSessionController 方法说明

> 对应类图：`conversationsessioncontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `listSessions` | 获取当前用户的全部对话会话列表，返回每个会话的元信息（ID、标题、时间、当前活跃会话标记等）。 |
| `createSession` | 为当前用户创建一个新的空白对话会话，返回新会话的标识信息。 |
| `archiveSession` | 将指定对话会话标记为归档状态，使其从活跃会话列表中移除但保留数据。 |
| `switchSession` | 将指定对话会话切换为当前用户的活动会话，后续对话将关联到该会话。 |
| `unarchiveSession` | 将已归档的对话会话恢复为非归档状态，重新显示在活跃会话列表中。 |

## 私有方法

无。
