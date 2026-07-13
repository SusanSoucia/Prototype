# RateLimitConfigService 方法说明

> 对应类图：`RateLimitConfigService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `loadPersistedConfigs` | 启动时从数据库加载持久化的限流配置并覆盖默认值。 |
| `getCurrentSettings` | 获取当前生效的完整限流配置（5 个配置项）。 |
| `updateSettings` | 管理员更新限流配置并持久化到数据库，同时刷新运行时缓存。 |
