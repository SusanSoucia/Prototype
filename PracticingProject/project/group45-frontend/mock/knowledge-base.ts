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

const TAG_ID_TO_NAME: Record<string, string> = {
  engineering: '工程部',
  'engineering-frontend': '前端组',
  'engineering-backend': '后端组',
  'engineering-ai': 'AI 组',
  search: '搜索团队',
  product: '产品部',
  'product-design': '产品设计组',
  management: '管理层'
};

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

// ---------- preview content per fileMd5 ----------
const previewContents: Record<string, string> = {
  abc123: '# RAG 架构设计文档\n\n## 1. 概述\nRAG（Retrieval-Augmented Generation）将信息检索与 LLM 生成相结合，通过先从知识库中检索相关文档片段，再将这些片段作为上下文提供给 LLM，从而生成有据可查、减少幻觉的回答。\n\n## 2. 核心组件\n- **文档解析器**：支持 PDF、Word、Markdown 等格式\n- **文本切分器**：基于语义的智能分段，默认 chunk_size=512, overlap=100\n- **向量化引擎**：使用 text-embedding-v4 将文本转换为 2048 维向量\n- **检索引擎**：混合检索（KNN + BM25），取两者的加权融合结果\n- **生成模型**：基于 DeepSeek Chat API 的上下文增强生成\n\n## 3. 工作流程\n1. 用户上传文档到知识库\n2. 系统自动解析 → 切块 → 向量化 → 存入 ES\n3. 用户提问时执行混合检索\n4. 将 Top-K 检索结果注入 LLM 上下文\n5. LLM 基于资料生成带引用编号的回答\n\n> 检索模式：HYBRID | 相关分数：0.95 | 第 3 页',

  def456: '# Elasticsearch 向量检索指南\n\n## dense_vector 字段配置\n```json\n{\n  "vector": {\n    "type": "dense_vector",\n    "dims": 2048,\n    "index": true,\n    "similarity": "cosine"\n  }\n}\n```\n\n## IK 分词器\n中文文本使用 IK 分词器，支持 ik_max_word 和 ik_smart 两种模式。知识库检索推荐 ik_max_word 以获得更高召回率。\n\n## BM25 关键词检索\nBM25 基于 TF-IDF 改进，对文档长度做归一化处理。在专有名词、代码标识符和版本号等场景下准确率接近 100%。\n\n### 适用场景\n- API 名称搜索：如 "getUserById"\n- 配置参数查询：如 "spring.datasource.url"\n- 错误码定位：如 "ERR_TIMEOUT_502"\n\n> 检索模式：TEXT_ONLY | 相关分数：0.87 | 第 18 页',

  ghi789: '# 混合检索配置说明\n\n## 权重公式\n```\nfinal_score = knn_weight × knn_score + bm25_weight × bm25_score\n```\n\n## 默认配置\n| 参数 | 默认值 | 说明 |\n|------|-------|------|\n| knn_weight | 0.7 | KNN 语义检索权重 |\n| bm25_weight | 0.3 | BM25 关键词检索权重 |\n| recall_k | topK × 30 | KNN 召回窗口大小 |\n\n## 调优建议\n- **语义密集型**（FAQ、客服）：提高 KNN 权重至 0.8-0.9\n- **精确匹配型**（代码搜索、合规）：降低 KNN 至 0.3-0.4\n- **通用场景**：保持默认，定期 A/B 测试验证\n\nKNN 权重 0.7 + BM25 权重 0.3 的线性组合在大多数场景下表现稳定。\n\n> 检索模式：HYBRID | 相关分数：0.92 | 第 8 页',

  jkl101: '# 检索策略对比分析\n\n## 三种检索策略横向对比\n\n| 维度 | KNN 向量检索 | BM25 关键词 | Hybrid 混合 |\n|------|------------|-----------|-----------|\n| 同义词 | ✅ 优秀 | ❌ 不支持 | ✅ 优秀 |\n| 专有名词 | ⚠️ 一般 | ✅ 精确 | ✅ 精确 |\n| 跨语言 | ✅ 支持 | ❌ 不支持 | ✅ 支持 |\n| 速度 | 中等 | 极快 | 中等 |\n| 冷启动 | 需要向量化 | 即时可用 | 需要向量化 |\n\n## 场景推荐\n\n### 客服问答 → Hybrid\n用户表述多样，同义词多（如"退款"≈"退钱"≈"申请退还"），需要语义兜底。\n\n### 代码搜索 → BM25\n函数名、类名、变量名是精确标识符，不存在同义词问题。\n\n### 文档查重 → KNN\n语义向量的余弦相似度天然适合做相似文档检测。\n\n### 合规审查 → BM25\n法律条款必须精确匹配原文，一个字的差异可能导致不同判决。\n\n> 检索模式：HYBRID | 相关分数：0.96 | 第 2 页'
};

export default [
  {
    url: '/api/v1/documents/accessible',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockDocuments,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/documents/preview',
    method: 'get',
    response: ({ query }: { query: Record<string, string> }) => {
      const fileMd5 = (query.fileMd5 || '') as string;
      const content = previewContents[fileMd5] || previewContents.abc123;

      return {
        code: 200,
        data: {
          fileName: query.fileName || '',
          fileMd5,
          fileSize: content.length,
          content,
          previewType: 'text'
        },
        message: 'ok'
      };
    }
  },
  {
    url: '/api/v1/documents/download-by-md5',
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
    url: '/api/v1/documents/:fileMd5',
    method: 'delete',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/admin/documents/:fileMd5/org-tag',
    method: 'put',
    response: (req: any) => {
      const fileMd5 = (req.params?.fileMd5 || '') as string;
      const { orgTag } = (req.body || {}) as { orgTag?: string };
      const doc = mockDocuments.find(d => d.fileMd5 === fileMd5);
      if (!doc) {
        return { code: 404, message: '文档不存在', data: null };
      }
      if (!orgTag || !VALID_ORG_TAG_IDS.has(orgTag)) {
        return { code: 400, message: '无效的组织标签', data: null };
      }
      doc.orgTag = orgTag;
      doc.orgTagName = TAG_ID_TO_NAME[orgTag] || orgTag;
      return { code: 200, message: '标签更新成功', data: null };
    }
  },
  {
    url: '/api/v1/admin/documents/:fileMd5/visibility',
    method: 'put',
    response: (req: any) => {
      const fileMd5 = (req.params?.fileMd5 || '') as string;
      const { isPublic } = (req.body || {}) as { isPublic?: boolean };
      const doc = mockDocuments.find(d => d.fileMd5 === fileMd5);
      if (!doc) {
        return { code: 404, message: '文档不存在', data: null };
      }
      if (typeof isPublic !== 'boolean') {
        return { code: 400, message: 'isPublic 必须为布尔值', data: null };
      }
      doc.isPublic = isPublic;
      doc.public = isPublic;
      return { code: 200, message: '可见性更新成功', data: null };
    }
  },
  {
    url: '/api/v1/documents/:fileMd5/vectorization/retry',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- upload ---
  {
    url: '/api/v1/upload/chunk',
    method: 'post',
    response: ({ body }: { body: Record<string, any> }) => {
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
    url: '/api/v1/upload/merge',
    method: 'post',
    response: ({ body }: { body: Record<string, any> }) => {
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
    url: '/api/v1/upload/status',
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
    url: '/api/v1/users/org-tags',
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
    url: '/api/v1/search/hybrid',
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
