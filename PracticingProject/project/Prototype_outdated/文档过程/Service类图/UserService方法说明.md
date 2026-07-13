# UserService 方法说明

> 对应类图：`UserService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `registerUser` | 创建新用户账号并分配默认组织标签，支持可选邀请码。 |
| `createAdminUser` | 由已有管理员创建新的管理员账户。 |
| `authenticateUser` | 验证用户名和密码，通过则返回用户名。 |
| `createOrganizationTag` | 创建新的组织标签，支持层级关系和上传大小限制。 |
| `assignOrgTagsToUser` | 为指定用户分配组织标签集合，管理员操作。 |
| `getUserOrgTags` | 获取用户所属的组织标签及其层级信息。 |
| `setUserPrimaryOrg` | 设置用户的主组织标签。 |
| `getUserPrimaryOrg` | 查询用户的主组织标签。 |
| `getOrganizationTagTree` | 获取所有组织标签的树状层级结构。 |
| `updateOrganizationTag` | 更新组织标签的名称、描述、父级关系及上传限制。 |
| `isAdminUser` | 判断指定用户是否为管理员角色。 |
| `getOrganizationTag` | 根据标签 ID 查询组织标签实体。 |
| `deleteOrganizationTag` | 删除组织标签及其关联的层级关系。 |
| `getUserList` | 按关键字、组织标签、状态等条件分页搜索用户列表。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `createPrivateOrgTag` | 为用户创建私有组织标签。 |
| `ensureDefaultOrgTagExists` | 确保默认组织标签已存在。 |
| `validatePassword` | 校验密码复杂度是否满足安全要求。 |
| `buildTagTreeRecursive` | 递归构建组织标签的树状结构。 |
| `wouldFormCycle` | 检测修改父标签是否会导致循环引用。 |
| `matchesUserListFilters` | 判断用户是否匹配搜索条件。 |
| `resolveOrGenerateTagId` | 解析或自动生成组织标签 ID。 |
| `resolveUser` | 根据用户 ID 字符串查找 User 实体。 |
| `normalizeUploadMaxSizeBytes` | 将 MB 单位的文件大小限制转换为字节。 |
