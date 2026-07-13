# FileTypeValidationService 方法说明

> 对应类图：`FileTypeValidationService.puml`

## 公开方法

| 方法 | 说明 |
|---|---|
| `validateFileType` | 校验文件扩展名是否在支持列表中，返回校验结果（成功/失败+文件类型+支持列表）。 |
| `getSupportedFileTypes` | 获取所有支持的文件类型描述（如 PDF文档、Word文档）。 |
| `getSupportedExtensions` | 获取所有支持的原始文件扩展名列表。 |
