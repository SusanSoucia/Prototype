# OrgTagCacheService 方法说明

> 对应类图：`OrgTagCacheService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `cacheUserOrgTags` | 将用户的组织标签列表缓存到 Redis。 |
| `getUserOrgTags` | 从 Redis 缓存获取用户的组织标签列表。 |
| `cacheUserPrimaryOrg` | 将用户的主组织标签缓存到 Redis。 |
| `getUserPrimaryOrg` | 从 Redis 缓存获取用户的主组织标签。 |
| `deleteUserOrgTagsCache` | 删除用户的组织标签缓存。 |
| `getUserEffectiveOrgTags` | 计算用户的有效组织标签集合（自身标签 + 所有祖先标签）。 |
| `getDocumentAccessOrgTags` | 计算文档检索时用户可访问的标签范围（含子标签扩散）。 |
| `deleteUserEffectiveTagsCache` | 删除用户的有效标签缓存。 |
| `invalidateAllEffectiveTagsCache` | 全局清除所有用户的有效标签缓存。 |
