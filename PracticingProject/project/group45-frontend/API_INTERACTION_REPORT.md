# 前端-后端 API 交互分析报告

## 一、请求基础设施

### 1.1 请求实例配置

**文件:** `src/service/request/index.ts`

前端使用 `@sa/axios` 库封装了 Axios 实例：

| 实例名    | 用途       | 成功码 | Base URL                                             |
| --------- | ---------- | ------ | ---------------------------------------------------- |
| `request` | 主后端 API | `0000` | `https://mock.apifox.cn/m1/3109515-0-default` (prod) |

- **请求头注入规则：**
  - 所有请求自动带 `Authorization: Bearer <token>`（从 localStorage 读取）
  - 额外带 `apifoxToken: 'XL299LiMEDZ0H5h3A29PxwQXdMJqWyY2'`
- **令牌刷新：** 收到 `9999, 9998, 3333` 错误码时自动调用 `POST /auth/refreshToken` 刷新并重试
- **强制登出：** 收到 `8888, 8889` 直接登出；收到 `7777, 7778` 弹窗确认后登出
- **开发代理：** `VITE_HTTP_PROXY=Y` 时，请求经过 `/proxy-default` 转发到后端
- **响应转换：** `response.data.data` 作为实际返回值

---

## 二、全部 API 请求清单

### 模块 A：认证 (Auth)

#### A1. 登录

| 项目                | 内容                                                              |
| ------------------- | ----------------------------------------------------------------- |
| **文件**            | `src/service/api/auth.ts:9`                                       |
| **调用方**          | `src/store/modules/auth/index.ts:102`                             |
| **方法**            | `POST`                                                            |
| **端点**            | `/auth/login`                                                     |
| **请求参数 (Body)** | `{ userName: string, password: string }`                          |
| **预期响应**        | `Api.Auth.LoginToken` — `{ token: string, refreshToken: string }` |
| **类型定义**        | `src/typings/api/auth.d.ts:8`                                     |

#### A2. 获取用户信息

| 项目         | 内容                                                                                             |
| ------------ | ------------------------------------------------------------------------------------------------ |
| **文件**     | `src/service/api/auth.ts:21`                                                                     |
| **调用方**   | `src/store/modules/auth/index.ts:149`                                                            |
| **方法**     | `GET`                                                                                            |
| **端点**     | `/auth/getUserInfo`                                                                              |
| **请求参数** | 无（仅依赖 Header 中的 Authorization token）                                                     |
| **预期响应** | `Api.Auth.UserInfo` — `{ userId: string, userName: string, roles: string[], buttons: string[] }` |
| **类型定义** | `src/typings/api/auth.d.ts:13`                                                                   |

#### A3. 刷新令牌

| 项目                | 内容                                                              |
| ------------------- | ----------------------------------------------------------------- |
| **文件**            | `src/service/api/auth.ts:30`                                      |
| **调用方**          | `src/service/request/shared.ts:18`（请求拦截器自动触发）          |
| **方法**            | `POST`                                                            |
| **端点**            | `/auth/refreshToken`                                              |
| **请求参数 (Body)** | `{ refreshToken: string }`                                        |
| **预期响应**        | `Api.Auth.LoginToken` — `{ token: string, refreshToken: string }` |
| **类型定义**        | `src/typings/api/auth.d.ts:8`                                     |

---

### 模块 B：路由 (Route)

> **注意:** 当 `VITE_AUTH_ROUTE_MODE=static` 时，以下三个请求均**不会发出**，改为使用本地静态路由定义。仅在 `dynamic` 模式下发出请求。

#### B1. 获取常量路由

| 项目         | 内容                                                                  |
| ------------ | --------------------------------------------------------------------- |
| **文件**     | `src/service/api/route.ts:4`                                          |
| **调用方**   | `src/store/modules/route/index.ts:161`                                |
| **方法**     | `GET`                                                                 |
| **端点**     | `/route/getConstantRoutes`                                            |
| **请求参数** | 无                                                                    |
| **预期响应** | `Api.Route.MenuRoute[]` — `Array<{ id: string } & ElegantConstRoute>` |
| **类型定义** | `src/typings/api/route.d.ts:10`                                       |

#### B2. 获取用户路由

| 项目         | 内容                                                                       |
| ------------ | -------------------------------------------------------------------------- |
| **文件**     | `src/service/api/route.ts:9`                                               |
| **调用方**   | `src/store/modules/route/index.ts:213`                                     |
| **方法**     | `GET`                                                                      |
| **端点**     | `/route/getUserRoutes`                                                     |
| **请求参数** | 无                                                                         |
| **预期响应** | `Api.Route.UserRoute` — `{ routes: MenuRoute[], home: LastLevelRouteKey }` |
| **类型定义** | `src/typings/api/route.d.ts:14`                                            |

#### B3. 检查路由是否存在

| 项目                 | 内容                                   |
| -------------------- | -------------------------------------- |
| **文件**             | `src/service/api/route.ts:18`          |
| **调用方**           | `src/store/modules/route/index.ts:307` |
| **方法**             | `GET`                                  |
| **端点**             | `/route/isRouteExist`                  |
| **请求参数 (Query)** | `{ routeName: string }`                |
| **预期响应**         | `boolean`                              |

---

### 模块 C：聊天 (Chat) — 会话管理

#### C1. 加载会话列表

| 项目         | 内容                                                                                                                                                                    |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:143`                                                                                                                                   |
| **调用方**   | `src/views/chats/modules/conversationSideBar.vue`（通过 `chatStore.loadSessions()`）                                                                                    |
| **方法**     | `GET`                                                                                                                                                                   |
| **端点**     | `/users/conversations`                                                                                                                                                  |
| **请求参数** | 无                                                                                                                                                                      |
| **预期响应** | `Api.Chat.ConversationSession[]` — `Array<{ id: number, conversationId: string, title: string, status: 'ACTIVE' \| 'ARCHIVED', createdAt: string, updatedAt: string }>` |
| **类型定义** | `src/typings/api/chat.d.ts:74`                                                                                                                                          |

#### C2. 创建新会话

| 项目                | 内容                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------- |
| **文件**            | `src/store/modules/chat/index.ts:160`                                                    |
| **调用方**          | `src/views/chats/modules/conversationSideBar.vue`（通过 `chatStore.createNewSession()`） |
| **方法**            | `POST`                                                                                   |
| **端点**            | `/users/conversations`                                                                   |
| **请求参数 (Body)** | 无（空 body）                                                                            |
| **预期响应**        | `Api.Chat.ConversationSession`（同 C1 结构）                                             |
| **类型定义**        | `src/typings/api/chat.d.ts:74`                                                           |

#### C3. 切换会话

| 项目         | 内容                                                                                     |
| ------------ | ---------------------------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:175`                                                    |
| **调用方**   | `src/views/chats/modules/conversationSideBar.vue`（通过 `chatStore.switchSession(cid)`） |
| **方法**     | `PUT`                                                                                    |
| **端点**     | `/users/conversations/{targetConversationId}/switch`                                     |
| **请求参数** | URL 路径参数: `targetConversationId: string`                                             |
| **预期响应** | 无特定类型                                                                               |

#### C4. 归档会话

| 项目         | 内容                                                                                      |
| ------------ | ----------------------------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:204`                                                     |
| **调用方**   | `src/views/chats/modules/conversationSideBar.vue`（通过 `chatStore.archiveSession(cid)`） |
| **方法**     | `PUT`                                                                                     |
| **端点**     | `/users/conversations/{targetConversationId}/archive`                                     |
| **请求参数** | URL 路径参数: `targetConversationId: string`                                              |
| **预期响应** | 无特定类型                                                                                |

#### C5. 取消归档会话

| 项目         | 内容                                                                                        |
| ------------ | ------------------------------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:218`                                                       |
| **调用方**   | `src/views/chats/modules/conversationSideBar.vue`（通过 `chatStore.unarchiveSession(cid)`） |
| **方法**     | `PUT`                                                                                       |
| **端点**     | `/users/conversations/{targetConversationId}/unarchive`                                     |
| **请求参数** | URL 路径参数: `targetConversationId: string`                                                |
| **预期响应** | 无特定类型                                                                                  |

---

### 模块 D：聊天 (Chat) — 消息

#### D1. 加载消息列表

| 项目                 | 内容                                                                                                                                                                                                                                                                                                                                                      |
| -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **文件**             | `src/store/modules/chat/index.ts:190`                                                                                                                                                                                                                                                                                                                     |
| **另外调用**         | `src/views/chats/modules/chat-list.vue:62`（直接调用同一端点，支持日期筛选）                                                                                                                                                                                                                                                                              |
| **方法**             | `GET`                                                                                                                                                                                                                                                                                                                                                     |
| **端点**             | `/users/conversation`                                                                                                                                                                                                                                                                                                                                     |
| **请求参数 (Query)** | `{ conversationId: string, start_date?: string (YYYY-MM-DD), end_date?: string (YYYY-MM-DD) }`                                                                                                                                                                                                                                                            |
| **预期响应**         | `Api.Chat.Message[]` — `Array<{ role: 'user' \| 'assistant', content: string, status?: 'pending' \| 'loading' \| 'finished' \| 'error', timestamp?: string, conversationId?: string, generationId?: string, username?: string, referenceMappings?: Record<string, ReferenceEvidence>, toolEvents?: AgentToolEvent[], feedbackRating?: 'good' \| 'bad' }>` |
| **类型定义**         | `src/typings/api/chat.d.ts:44`                                                                                                                                                                                                                                                                                                                            |

---

### 模块 E：聊天 (Chat) — 生成控制

#### E1. 获取生成快照（按 ID）

| 项目         | 内容                                                                                                                                                                                                                                                                                                                              |
| ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:111`                                                                                                                                                                                                                                                                                             |
| **调用方**   | `src/views/chats/modules/input-box.vue:189`（轮询后备，每 2 秒检查流是否卡住）                                                                                                                                                                                                                                                    |
| **方法**     | `GET`                                                                                                                                                                                                                                                                                                                             |
| **端点**     | `/chat/generation/{generationId}`                                                                                                                                                                                                                                                                                                 |
| **请求参数** | URL 路径参数: `generationId: string`                                                                                                                                                                                                                                                                                              |
| **预期响应** | `Api.Chat.GenerationSnapshot \| null` — `{ generationId: string, userId: string, conversationId: string, question: string, status: 'STREAMING' \| 'COMPLETED' \| 'FAILED' \| 'CANCELLED', content?: string, createdAt: string, updatedAt: string, errorMessage?: string, referenceMappings?: Record<string, ReferenceEvidence> }` |
| **类型定义** | `src/typings/api/chat.d.ts:61`                                                                                                                                                                                                                                                                                                    |

#### E2. 获取活跃生成快照

| 项目         | 内容                                                                  |
| ------------ | --------------------------------------------------------------------- |
| **文件**     | `src/store/modules/chat/index.ts:121`                                 |
| **调用方**   | WebSocket 重连后自动同步（`syncGenerationAfterReconnect`，第 136 行） |
| **方法**     | `GET`                                                                 |
| **端点**     | `/chat/active-generation`                                             |
| **请求参数** | 无                                                                    |
| **预期响应** | `Api.Chat.GenerationSnapshot \| null`（同 E1）                        |
| **类型定义** | `src/typings/api/chat.d.ts:61`                                        |

#### E3. 获取 WebSocket 命令令牌

| 项目         | 内容                                                                                                      |
| ------------ | --------------------------------------------------------------------------------------------------------- |
| **文件**     | `src/views/chats/modules/input-box.vue:323`                                                               |
| **调用方**   | 停止生成时（点击停止按钮）                                                                                |
| **方法**     | `GET`                                                                                                     |
| **端点**     | `/chat/websocket-token`                                                                                   |
| **请求参数** | 无                                                                                                        |
| **预期响应** | `Api.Chat.Token` — `{ cmdToken: string }`                                                                 |
| **类型定义** | `src/typings/api/chat.d.ts:57`                                                                            |
| **后续动作** | 获取到 `cmdToken` 后，通过 WebSocket 发送 `{ type: 'stop', generationId, _internal_cmd_token: cmdToken }` |

---

### 模块 F：聊天 (Chat) — 反馈

#### F1. 提交消息反馈（点赞/点踩）

| 项目                | 内容                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------- |
| **文件**            | `src/views/chats/modules/chat-message.vue:43`                                                 |
| **方法**            | `POST`                                                                                        |
| **端点**            | `/chat/feedback`                                                                              |
| **请求参数 (Body)** | `{ rating: 'good' \| 'bad', reason: string, conversationId?: string, generationId?: string }` |
| **预期响应**        | 无特定类型                                                                                    |

---

### 模块 G：文档 (Document)

#### G1. 获取引用详情

| 项目                 | 内容                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **文件**             | `src/views/chats/modules/chat-message.vue:308`                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| **另外调用**         | `src/views/chats/modules/reference-preview.vue:97`                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| **方法**             | `GET`                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| **端点**             | `/documents/reference-detail`                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| **请求参数 (Query)** | `{ sessionId: string, referenceNumber: string }`                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **预期响应**         | `Api.Document.ReferenceDetailResponse` — 继承 `ReferenceEvidence` 并增加 `referenceNumber: number`。完整结构: `{ fileMd5: string, fileName: string, pageNumber?: number \| null, anchorText?: string \| null, retrievalMode?: 'HYBRID' \| 'TEXT_ONLY' \| null, retrievalLabel?: string \| null, retrievalQuery?: string \| null, matchedChunkText?: string \| null, evidenceSnippet?: string \| null, score?: number \| null, chunkId?: number \| null, referenceNumber: number }` |
| **类型定义**         | `src/typings/api/document.d.ts:10`（继承 `src/typings/api/chat.d.ts:10`）                                                                                                                                                                                                                                                                                                                                                                                                          |

---

### 模块 H：WebSocket 实时通信

#### H1. 聊天消息流式传输

| 项目           | 内容                                                    |
| -------------- | ------------------------------------------------------- |
| **文件**       | `src/store/modules/chat/index.ts:233-284`               |
| **连接地址**   | `ws://{host}/proxy-ws/chat/{encodeURIComponent(token)}` |
| **库**         | `@vueuse/core` 的 `useWebSocket`                        |
| **心跳**       | 每 20s 发 `__chat_ping__`，10s 超时期待 `__chat_pong__` |
| **自动重连**   | 间隔 1.5s；收到 1002/1003/1007/1008 关闭码时停止重连    |
| **连接建立后** | 后端发送 `{ type: 'connection', sessionId }` 握手确认   |

**WebSocket 消息流：**

| 方向 | 消息类型                                                     | 内容                           | 触发时机         |
| ---- | ------------------------------------------------------------ | ------------------------------ | ---------------- |
| 上行 | 原始文本                                                     | `input.message` (用户输入内容) | 用户点击发送     |
| 上行 | `{ type: 'stop', generationId, _internal_cmd_token }`        | JSON 字符串                    | 用户点击停止按钮 |
| 上行 | `__chat_ping__`                                              | 心跳 ping                      | 每 20 秒自动     |
| 下行 | `{ type: 'connection', sessionId }`                          | 连接握手                       | 连接建立后       |
| 下行 | `{ type: 'start', generationId, conversationId, timestamp }` | 生成开始                       | 后端开始处理     |
| 下行 | `{ chunk: string }`                                          | 流式文本片段                   | 持续流式输出     |
| 下行 | `{ type: 'tool_call', toolCallId, tool, status }`            | 工具调用事件                   | 检索等操作       |
| 下行 | `{ type: 'completion', status, referenceMappings }`          | 生成完成                       | 生成结束时       |
| 下行 | `{ type: 'stop' }`                                           | 被停止                         | 停止指令生效后   |
| 下行 | `{ error, code, message, retryAfterSeconds }`                | 错误（含 429 限流）            | 出错时           |

---

### 模块 I：应用版本检查

#### I1. 检查前端新版本

| 项目                 | 内容                                                                 |
| -------------------- | -------------------------------------------------------------------- |
| **文件**             | `src/plugins/app.ts:95`                                              |
| **方法**             | `GET`（使用原生 `fetch()`，非 axios）                                |
| **端点**             | `{VITE_BASE_URL}index.html`                                          |
| **请求参数 (Query)** | `{ time: Date.now() }` (缓存破坏)                                    |
| **预期响应**         | HTML 文本，解析 `<meta name="buildTime" content="...">` 获取构建时间 |
| **检查频率**         | 每 3 分钟 + 页面可见性变化时                                         |
| **仅生产环境**       | `VITE_AUTOMATICALLY_DETECT_UPDATE === 'Y' && PROD`                   |

---

## 三、汇总

### 按请求方式统计

| 方法      | 数量 | 端点                                                                                                                                                                                                                                   |
| --------- | ---- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GET       | 11   | auth/getUserInfo, route/getConstantRoutes, route/getUserRoutes, route/isRouteExist, users/conversations, users/conversation, chat/generation/:id, chat/active-generation, chat/websocket-token, documents/reference-detail, index.html |
| POST      | 3    | auth/login, auth/refreshToken, chat/feedback                                                                                                                                                                                           |
| PUT       | 3    | users/conversations/:cid/switch, users/conversations/:cid/archive, users/conversations/:cid/unarchive                                                                                                                                  |
| WebSocket | 1    | proxy-ws/chat/:token                                                                                                                                                                                                                   |

### 按模块统计

| 模块      | 端点数量  | 核心文件                                                                                    |
| --------- | --------- | ------------------------------------------------------------------------------------------- |
| 认证      | 3         | `src/service/api/auth.ts`, `src/store/modules/auth/index.ts`                                |
| 路由      | 3         | `src/service/api/route.ts`, `src/store/modules/route/index.ts`                              |
| 聊天-会话 | 5         | `src/store/modules/chat/index.ts`, `src/views/chats/modules/conversationSideBar.vue`        |
| 聊天-消息 | 1         | `src/store/modules/chat/index.ts`, `src/views/chats/modules/chat-list.vue`                  |
| 聊天-生成 | 3         | `src/store/modules/chat/index.ts`, `src/views/chats/modules/input-box.vue`                  |
| 聊天-反馈 | 1         | `src/views/chats/modules/chat-message.vue`                                                  |
| 文档引用  | 1         | `src/views/chats/modules/chat-message.vue`, `src/views/chats/modules/reference-preview.vue` |
| 实时通信  | 1 (WS)    | `src/store/modules/chat/index.ts`                                                           |
| 版本检查  | 1 (fetch) | `src/plugins/app.ts`                                                                        |

### 类型定义文件索引

| 文件                            | 定义的接口（仅列出实际使用的）                                                                                                      |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `src/typings/api/auth.d.ts`     | `LoginToken`, `UserInfo`                                                                                                            |
| `src/typings/api/route.d.ts`    | `MenuRoute`, `UserRoute`                                                                                                            |
| `src/typings/api/chat.d.ts`     | `GenerationStatus`, `ReferenceEvidence`, `Input`, `AgentToolEvent`, `Message`, `Token`, `GenerationSnapshot`, `ConversationSession` |
| `src/typings/api/document.d.ts` | `ReferenceDetailResponse`                                                                                                           |
| `src/typings/api/common.d.ts`   | `PaginatingCommonParams`, `PaginatingQueryRecord`                                                                                   |
| `src/typings/app.d.ts`          | `App.Service.Response<T>`                                                                                                           |

---

## 四、交互流程图

```
用户登录
  POST /auth/login ───────→ { token, refreshToken }
  GET  /auth/getUserInfo ──→ { userId, userName, roles }

动态路由加载（仅 dynamic 模式）
  GET /route/getConstantRoutes → MenuRoute[]
  GET /route/getUserRoutes    → { routes, home }

进入聊天页面
  GET /users/conversations              → ConversationSession[]
  GET /users/conversation?conversationId=X → Message[]

发送消息
  WSS /proxy-ws/chat/:token → (发送用户消息)
  ← chunk / tool_call / completion / error 流式接收

停止生成
  GET /chat/websocket-token → { cmdToken }
  WSS → { type:'stop', generationId, _internal_cmd_token }

流中断后备
  GET /chat/generation/:id → GenerationSnapshot (每 2s 轮询)

重连恢复
  GET /chat/active-generation → GenerationSnapshot (仅当无 pending generationId)

点赞/点踩
  POST /chat/feedback → { rating, reason, conversationId, generationId }

查看引用来源
  GET /documents/reference-detail?sessionId=X&referenceNumber=N → ReferenceDetailResponse

版本更新检测（仅生产环境）
  GET /index.html?time={ts} → 比对 <meta buildTime>
```
