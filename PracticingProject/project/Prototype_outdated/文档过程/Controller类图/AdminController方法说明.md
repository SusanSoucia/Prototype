# AdminController 方法说明

> 对应类图：`admincontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `getAllUsers` | 获取系统中所有注册用户的列表，并移除密码等敏感信息后返回。 |
| `addKnowledgeDocument` | 将上传的文件及其描述信息添加到知识库中，供后续检索使用。 |
| `deleteKnowledgeDocument` | 根据文档ID从知识库中删除指定的文档及其关联数据。 |
| `getSystemStatus` | 获取当前系统的运行状态概览，包括CPU、内存、磁盘使用率及活跃用户数等指标。 |
| `getUserActivities` | 按用户名和时间范围查询用户的操作活动日志，如登录、上传文件等行为记录。 |
| `getUsageOverview` | 获取近N天（默认7天）的平台用量总览数据，包括Token消耗、API调用次数等统计信息。 |
| `getRateLimits` | 查询当前系统的API限流配置参数，包括各接口的请求频率上限。 |
| `updateRateLimits` | 更新系统的API限流配置，调整各接口的请求频率上限阈值。 |
| `getModelProviders` | 获取当前配置的大模型提供商列表及其连接参数设置。 |
| `updateModelProviders` | 更新指定范围（scope）的大模型提供商配置，包括API地址、密钥等信息。 |
| `testModelProviderConnection` | 测试指定模型提供商的网络连接是否通畅，验证配置参数是否正确。 |
| `createAdminUser` | 创建新的管理员账户，设置用户名和密码。 |
| `createOrganizationTag` | 创建新的组织标签，设置标签ID、名称、描述、父标签及上传文件大小上限。 |
| `getAllOrganizationTags` | 获取系统中所有已创建的组织标签列表。 |
| `assignOrgTagsToUser` | 为指定用户分配一个或多个组织标签，使其归属于对应组织。 |
| `getOrganizationTagTree` | 获取组织标签的树状层级结构，支持分页展示。 |
| `updateOrganizationTag` | 更新指定组织标签的信息，包括名称、描述、父级关系及上传限制。 |
| `deleteOrganizationTag` | 删除指定的组织标签，清理其关联的层级关系。 |
| `getUserList` | 按关键字、组织标签、状态等条件分页搜索用户列表，支持模糊匹配。 |
| `addUserTokens` | 管理员手动为用户追加LLM Token或Embedding Token额度，并记录操作原因。 |
| `getAllConversations` | 管理员查询指定用户及时间范围内的所有持久化对话历史记录。 |
| `migrateMinioFiles` | 将MinIO中旧路径（按文件名）的文件迁移到新路径（按文件MD5），返回迁移统计报告。 |
| `clearAllData` | 清空数据库中所有数据（危险操作，仅限测试环境使用，需额外密钥验证）。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `validateAdmin` | 验证当前请求用户是否为管理员角色，不是则抛出权限异常。 |
| `paginateTree` | 对组织标签树状结构列表进行内存分页，返回指定页的数据及分页元信息。 |
| `normalizeManualTokenReason` | 规范化管理员手动追加Token的原因字段，截断过长文本并设置默认值。 |
| `parseStartDate` | 将多种格式的起始时间字符串解析为LocalDateTime，支持日期、日期时间等灵活输入。 |
| `parseEndDate` | 将多种格式的结束时间字符串解析为LocalDateTime，日期格式自动补齐至当天最后一秒。 |
