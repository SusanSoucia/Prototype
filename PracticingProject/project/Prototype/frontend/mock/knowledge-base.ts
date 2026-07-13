import type { MockMethod } from 'vite-plugin-mock';
import { UploadStatus } from '@/enum';

// 与 mock/org-tag.ts 保持同步的合法标签 ID 集合
const VALID_ORG_TAG_IDS = new Set([
  'engineering',
  'engineering-frontend',
  'engineering-backend',
  'engineering-ai',
  'search',
  'product',
  'product-design',
  'management'
]);

const mockDocuments: Api.KnowledgeBase.UploadTask[] = [
  {
    id: 1,
    fileMd5: 'abc123def456',
    fileName: 'RAG架构设计文档.pdf',
    totalSize: 2_560_000,
    uploadedChunks: [0, 1, 2, 3, 4],
    progress: 100,
    status: UploadStatus.Completed,
    orgTag: 'engineering',
    orgTagName: '工程部',
    public: false,
    isPublic: false,
    chunk: null,
    chunkIndex: 4,
    estimatedEmbeddingTokens: 15420,
    estimatedChunkCount: 85,
    actualEmbeddingTokens: 15100,
    actualChunkCount: 82,
    vectorizationStatus: 'COMPLETED',
    vectorizationErrorMessage: null,
    createdAt: new Date(Date.now() - 259200000).toISOString(),
    mergedAt: new Date(Date.now() - 259100000).toISOString()
  },
  {
    id: 2,
    fileMd5: 'def456ghi789',
    fileName: 'Elasticsearch向量检索指南.pdf',
    totalSize: 1_840_000,
    uploadedChunks: [0, 1, 2, 3],
    progress: 100,
    status: UploadStatus.Completed,
    orgTag: 'search',
    orgTagName: '搜索团队',
    public: true,
    isPublic: true,
    chunk: null,
    chunkIndex: 3,
    estimatedEmbeddingTokens: 8920,
    estimatedChunkCount: 42,
    actualEmbeddingTokens: 9100,
    actualChunkCount: 44,
    vectorizationStatus: 'COMPLETED',
    vectorizationErrorMessage: null,
    createdAt: new Date(Date.now() - 172800000).toISOString(),
    mergedAt: new Date(Date.now() - 172700000).toISOString()
  },
  {
    id: 3,
    fileMd5: 'ghi789jkl012',
    fileName: '混合检索配置说明.pdf',
    totalSize: 920_000,
    uploadedChunks: [0, 1, 2],
    progress: 100,
    status: UploadStatus.Completed,
    orgTag: 'engineering',
    orgTagName: '工程部',
    public: false,
    isPublic: false,
    chunk: null,
    chunkIndex: 2,
    estimatedEmbeddingTokens: 4500,
    estimatedChunkCount: 18,
    actualEmbeddingTokens: 4620,
    actualChunkCount: 19,
    vectorizationStatus: 'COMPLETED',
    vectorizationErrorMessage: null,
    createdAt: new Date(Date.now() - 86400000).toISOString(),
    mergedAt: new Date(Date.now() - 86390000).toISOString()
  },
  {
    id: 4,
    fileMd5: 'jkl012mno345',
    fileName: 'Python异步编程最佳实践.md',
    totalSize: 340_000,
    uploadedChunks: [0, 1, 2, 3, 4, 5],
    progress: 100,
    status: UploadStatus.Completed,
    orgTag: null,
    orgTagName: null,
    public: true,
    isPublic: true,
    chunk: null,
    chunkIndex: 5,
    estimatedEmbeddingTokens: 3200,
    estimatedChunkCount: 12,
    vectorizationStatus: 'PROCESSING',
    vectorizationErrorMessage: null,
    createdAt: new Date(Date.now() - 3600000).toISOString(),
    mergedAt: new Date(Date.now() - 3599000).toISOString()
  },
  {
    id: 5,
    fileMd5: 'mno345pqr678',
    fileName: '项目周报-2024W48.pdf',
    totalSize: 1_200_000,
    uploadedChunks: [0, 1],
    progress: 66.67,
    status: UploadStatus.Break,
    orgTag: 'management',
    orgTagName: '管理层',
    public: false,
    isPublic: false,
    chunk: null,
    chunkIndex: 1,
    vectorizationStatus: null,
    vectorizationErrorMessage: null,
    createdAt: new Date(Date.now() - 1800000).toISOString()
  }
];

export default [
  {
    url: '/documents/accessible',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockDocuments,
      message: 'ok'
    })
  },
  {
    url: '/documents/preview',
    method: 'get',
    response: () => ({
      code: 200,
      data: `# RAG 架构设计文档（预览）

## 1. 概述
RAG（Retrieval-Augmented Generation）是一种将信息检索与大语言模型生成相结合的 AI 架构。

## 2. 核心组件
- **文档解析器**：支持 PDF、Word、Markdown 等格式
- **文本切分器**：基于语义的智能分段
- **向量化引擎**：将文本转换为高维向量
- **检索引擎**：混合检索（KNN + BM25）
- **生成模型**：基于上下文的答案生成

## 3. 工作流程
1. 用户上传文档到知识库
2. 系统自动解析并向量化
3. 用户提问时进行混合检索
4. 将检索结果注入 LLM 上下文
5. LLM 基于资料生成带引用的回答

> 这是 mock 预览数据，实际内容请上传真实文档查看。`,
      message: 'ok'
    })
  },
  {
    url: '/documents/download-by-md5',
    method: 'get',
    response: () => ({
      code: 200,
      data: {
        fileName: 'mock-document.pdf',
        downloadURL: '',
        fileSize: 0
      } as Api.Document.DownloadResponse,
      message: 'ok'
    })
  },
  {
    url: '/documents/:fileMd5',
    method: 'delete',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/documents/:fileMd5/vectorization/retry',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- upload ---
  {
    url: '/upload/chunk',
    method: 'post',
    response: ({ body }: { body: Record<string, any> }) => {
      // 校验 orgTag 是否在后端合法标签列表中
      if (body.orgTag && !VALID_ORG_TAG_IDS.has(body.orgTag)) {
        return {
          code: 400,
          data: null,
          message: `组织标签 "${body.orgTag}" 不存在，请选择有效的组织标签`
        };
      }
      return {
        code: 200,
        data: {
          uploaded: [body.chunkIndex ?? 0],
          progress: 100,
          totalChunks: 1
        },
        message: 'ok'
      };
    }
  },
  {
    url: '/upload/merge',
    method: 'post',
    response: ({ body }: { body: Record<string, any> }) => {
      // 合并时也校验 orgTag（从分片上传中继承）
      if (body.orgTag && !VALID_ORG_TAG_IDS.has(body.orgTag)) {
        return {
          code: 400,
          data: null,
          message: `组织标签 "${body.orgTag}" 不存在`
        };
      }
      return {
        code: 200,
        data: {
          objectUrl: '',
          estimatedEmbeddingTokens: 5000,
          estimatedChunkCount: 25
        } as Api.KnowledgeBase.MergeResult,
        message: 'ok'
      };
    }
  },
  {
    url: '/upload/status',
    method: 'get',
    response: ({ query }: { query: Record<string, string> }) => {
      const doc = mockDocuments.find(d => d.fileMd5 === query.fileMd5);
      return {
        code: 200,
        data: doc ?? null,
        message: 'ok'
      };
    }
  },
  // --- org-tags / search ---
  {
    url: '/users/org-tags',
    method: 'get',
    response: () => ({
      code: 200,
      data: {
        orgTags: ['engineering', 'search', 'management'],
        primaryOrg: 'engineering',
        orgTagDetails: [
          { tagId: 'engineering', name: '工程部', description: '负责核心产品研发' },
          { tagId: 'search', name: '搜索团队', description: '负责检索引擎与向量化' },
          { tagId: 'management', name: '管理层', description: '公司管理层' }
        ]
      } as Api.OrgTag.Mine,
      message: 'ok'
    })
  },
  {
    url: '/search/hybrid',
    method: 'get',
    response: () => ({
      code: 200,
      data: [
        {
          fileMd5: 'abc123def456',
          chunkId: 1,
          textContent: 'RAG 架构将检索与生成结合，通过向量化和混合检索提供精确的上下文增强回答。',
          score: 0.95,
          fileName: 'RAG架构设计文档.pdf'
        },
        {
          fileMd5: 'def456ghi789',
          chunkId: 3,
          textContent: 'Elasticsearch 的 dense_vector 字段支持 KNN 检索，配合 IK 分词器实现高效的中文搜索。',
          score: 0.87,
          fileName: 'Elasticsearch向量检索指南.pdf'
        },
        {
          fileMd5: 'ghi789jkl012',
          chunkId: 2,
          textContent: '混合检索通过加权融合 KNN 和 BM25 的分数，实现语义和关键词的双路匹配。',
          score: 0.82,
          fileName: '混合检索配置说明.pdf'
        }
      ] as Api.KnowledgeBase.SearchResult[],
      message: 'ok'
    })
  }
] as MockMethod[];
