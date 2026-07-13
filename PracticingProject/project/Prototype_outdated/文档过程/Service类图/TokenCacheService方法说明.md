# TokenCacheService 方法说明

> 对应类图：`TokenCacheService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `cacheToken` | 将 JWT accessToken 及其关联的用户信息缓存到 Redis。 |
| `cacheRefreshToken` | 将 refreshToken 及其与 accessToken 的关联关系缓存到 Redis。 |
| `isTokenValid` | 检查 accessToken 是否在 Redis 中有效且未被加入黑名单。 |
| `getTokenInfo` | 获取 accessToken 对应的用户信息（userId/username）。 |
| `isRefreshTokenValid` | 检查 refreshToken 是否在 Redis 中有效。 |
| `getRefreshTokenInfo` | 获取 refreshToken 关联的用户和 accessToken 信息。 |
| `blacklistToken` | 将 accessToken 加入黑名单（注销时调用，TTL 对齐 Token 过期时间）。 |
| `isTokenBlacklisted` | 检查 accessToken 是否已被加入黑名单。 |
| `removeToken` | 删除指定 accessToken 及其用户关联，触发单设备登出。 |
| `removeAllUserTokens` | 删除用户的所有 Token，触发全设备登出。 |
| `getUserActiveTokenCount` | 获取用户当前活跃的 Token 数量。 |
