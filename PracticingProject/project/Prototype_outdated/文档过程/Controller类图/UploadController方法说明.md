# UploadController 方法说明

> 对应类图：`uploadcontroller.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `uploadChunk` | 接收文件分片并存储，首个分片校验文件类型，自动补全用户主组织标签，非管理员校验组织上传大小限制。 |
| `getUploadStatus` | 根据文件 MD5 查询上传进度，返回已上传分片列表和百分比进度。 |
| `mergeFile` | 校验分片完整性及用户权限后合并所有分片为完整文件，预估 Embedding 用量并发送 Kafka 处理任务。 |
| `getSupportedFileTypes` | 返回系统当前支持上传和解析的文件类型及扩展名列表。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `buildAlreadyMergedResponse` | 为已合并完成的文件构造幂等成功响应，直接返回已有的对象访问 URL。 |
| `calculateProgress` | 根据已上传分片数和总片数计算上传进度百分比。 |
| `formatSize` | 将字节数格式化为人类可读的存储单位（KB/MB/GB）。 |
| `getFileType` | 根据文件扩展名映射返回中文文件类型描述（如 PDF文档、Word文档）。 |
