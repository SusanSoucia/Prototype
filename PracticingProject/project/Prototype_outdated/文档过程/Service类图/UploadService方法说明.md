# UploadService 方法说明

> 对应类图：`UploadService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `uploadChunk` | 将文件分片上传到 MinIO 并记录分片元数据，使用 Redis Bitmap 追踪上传进度。 |
| `isChunkUploaded` | 检查指定分片是否已上传完成。 |
| `markChunkUploaded` | 在 Redis Bitmap 中标记分片已上传。 |
| `deleteFileMark` | 清除文件的 Redis 上传标记（含 Bitmap 和总分片数）。 |
| `getUploadedChunks` | 从 Redis Bitmap 读取已上传分片列表。 |
| `getTotalChunks` | 从 Redis 读取文件的总分片数。 |
| `mergeChunks` | 将所有分片按序合并为完整文件并上传到 MinIO。 |
| `getMergedFileStream` | 从 MinIO 获取合并后文件的输入流。 |
| `generateMergedObjectUrl` | 生成合并后文件的 MinIO 内网访问 URL。 |
| `transToPublicUrl` | 将 MinIO 内网 URL 转换为公网可访问 URL。 |

## 私有方法

| 方法 | 说明 |
|---|---|
| `getFileType` | 根据扩展名返回中文文件类型。 |
| `getUploadedChunksFromDatabase` | 从 chunk_info 表查询已上传分片（Redis 缺失时降级）。 |
| `backfillUploadedChunks` | 将数据库中的分片记录回填到 Redis。 |
| `isBitSet` | 判断 Bitmap 中指定位是否已设置。 |
| `saveChunkInfo` | 将分片元数据（MD5/存储路径）持久化到 chunk_info 表。 |
| `buildChunkStoragePath` | 构造分片在 MinIO 中的存储路径。 |
| `getOrCreateFileUpload` | 获取或创建文件上传记录（file_upload 表）。 |
