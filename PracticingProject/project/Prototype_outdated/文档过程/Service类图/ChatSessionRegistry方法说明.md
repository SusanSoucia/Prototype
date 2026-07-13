# ChatSessionRegistry 方法说明

> 对应类图：`ChatSessionRegistry.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `registerSession` | 将用户的 WebSocket 会话注册到内存中，用于消息推送。 |
| `unregisterSession` | 注销用户的 WebSocket 会话。 |
| `getCurrentSession` | 获取用户当前的活跃 WebSocket 会话。 |
| `sendJsonToUser` | 通过 WebSocket 向指定用户推送 JSON 消息。 |
