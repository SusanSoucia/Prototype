# ModelProviderConfigService 方法说明

> 对应类图：`ModelProviderConfigService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `loadPersistedConfigs` | 启动时从数据库加载持久化的模型供应商配置并合并到默认值。 |
| `getCurrentSettings` | 获取当前完整的 LLM 和 Embedding 供应商配置。 |
| `getActiveProvider` | 根据 scope（llm/embedding）获取当前激活的供应商信息（含解密后的 API Key）。 |
| `updateScope` | 管理员更新指定 scope 的供应商配置，支持切换激活供应商和增删改。 |
| `testConnection` | 测试指定供应商的 API 连通性，返回成功/失败和延迟。 |
| `reloadSettings` | 清空缓存并重新从数据库加载配置。 |
| `normalizeOpenAiCompatibleBaseUrl` | 静态工具方法：将各种 OpenAI 兼容 API 地址格式标准化（去除尾部路径）。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `buildDefaultSettings` | 构建默认供应商配置（来自 application 配置）。 |
| `mergeOverrides` | 将持久化配置合并覆盖到默认配置上。 |
| `toActiveProvider` | 将 ProviderConfigView 转换为含明文 API Key 的 ActiveProviderView。 |
| `requiresEmbeddingReindex` | 判断 Embedding 模型切换是否需要重建索引。 |
| `validateUpdateRequest` | 校验更新请求的合法性（激活的 provider 必须存在且启用）。 |
