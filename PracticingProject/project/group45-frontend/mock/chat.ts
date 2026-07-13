import type { MockMethod } from 'vite-plugin-mock';

const now = new Date().toISOString();
const hourAgo = new Date(Date.now() - 3600000).toISOString();
const dayAgo = new Date(Date.now() - 86400000).toISOString();

const mockSessions: Api.Chat.ConversationSession[] = [
  {
    id: 1,
    conversationId: 'conv-active-001',
    title: '关于知识库架构的讨论',
    status: 'ACTIVE',
    createdAt: hourAgo,
    updatedAt: now
  },
  {
    id: 2,
    conversationId: 'conv-active-002',
    title: 'Python 异步编程问题',
    status: 'ACTIVE',
    createdAt: dayAgo,
    updatedAt: hourAgo
  },
  {
    id: 3,
    conversationId: 'conv-archived-001',
    title: '上周会议纪要整理',
    status: 'ARCHIVED',
    createdAt: new Date(Date.now() - 604800000).toISOString(),
    updatedAt: dayAgo
  },
  {
    id: 4,
    conversationId: 'conv-active-003',
    title: 'API 接口文档引用预览测试',
    status: 'ACTIVE',
    createdAt: now,
    updatedAt: now
  }
];

const mockMessages: Api.Chat.Message[] = [
  {
    role: 'user',
    content: '请解释一下知识库的 RAG 架构是怎么设计的？',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
    username: 'admin'
  },
  {
    role: 'assistant',
    content: 'RAG（Retrieval-Augmented Generation）架构的核心思想是将检索系统与生成模型结合。在我们的知识库中，整个流程分为以下几步：\n\n1. **文档预处理**：上传的文档经过 PDF 解析、文本切块（chunking）后，通过 Embedding 模型将每个文本块转换为 2048 维向量 (来源#1: RAG架构设计文档.pdf | 第3页)。\n\n2. **向量存储**：向量数据和原始文本存储在 Elasticsearch 中，使用 dense_vector 类型支持 KNN 检索，同时使用 IK 分词器支持 BM25 关键词检索 (来源#2: Elasticsearch向量检索指南.pdf | 第12页)。\n\n3. **混合检索**：用户提问时，系统同时执行向量相似度检索和关键词检索，通过加权融合（Hybrid Search）返回最相关的结果。\n\n4. **上下文增强**：将检索到的文档片段作为上下文注入 LLM 的 prompt 中，让模型基于这些资料生成准确的回答。\n\n5. **引用溯源**：每个回答都会标注引用的来源文档和页码，用户可以点击引用查看原文。\n\n这种架构的优势在于：模型回答有据可查，减少幻觉，并且可以随时更新知识库而不需要重新训练模型。',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
    username: 'admin',
    generationId: 'gen-001',
    referenceMappings: {
      '1': {
        fileMd5: 'abc123',
        fileName: 'RAG架构设计文档.pdf',
        pageNumber: 3,
        anchorText: 'RAG 架构概述',
        retrievalMode: 'HYBRID',
        score: 0.95
      },
      '2': {
        fileMd5: 'def456',
        fileName: 'Elasticsearch向量检索指南.pdf',
        pageNumber: 12,
        anchorText: 'dense_vector 配置',
        retrievalMode: 'TEXT_ONLY',
        score: 0.87
      }
    },
    toolEvents: [
      {
        id: 'tool-1',
        tool: 'search_knowledge',
        status: 'success',
        timestamp: Date.now() - 2000
      }
    ]
  },
  {
    role: 'user',
    content: '那混合检索的权重是怎么设置的？',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
    username: 'admin'
  },
  {
    role: 'assistant',
    content: '混合检索的权重配置在 `HybridSearchService` 中管理，默认配置为：\n\n- **向量检索（KNN）权重**：0.7（主要依赖语义相似度）\n- **关键词检索（BM25）权重**：0.3（辅助精确匹配）\n\n权重可以通过以下方式调整 (来源#1: 混合检索配置说明.pdf | 第5页)：\n\n1. 在配置文件中修改 `search.knn.weight` 和 `search.bm25.weight` 参数\n2. 通过管理后台的动态配置功能实时调整\n3. 针对不同的知识库领域，可以使用不同的权重配比\n\n实际效果上，语义检索擅长理解同义词和上下文，关键词检索则保证专有名词和术语的精确命中，两者互补。',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
    username: 'admin',
    generationId: 'gen-002',
    referenceMappings: {
      '1': {
        fileMd5: 'ghi789',
        fileName: '混合检索配置说明.pdf',
        pageNumber: 5,
        anchorText: '权重配置',
        retrievalMode: 'HYBRID',
        score: 0.92
      }
    }
  },
  {
    role: 'user',
    content: '请对比一下我们项目里用到的几种检索策略，并给出适用场景建议',
    status: 'finished',
    timestamp: now,
    conversationId: 'conv-active-003',
    username: 'user'
  },
  {
    role: 'assistant',
    content: '我们项目目前支持三种检索策略，各有适用场景：\n\n### 1. 纯向量检索（KNN）\n基于 Embedding 向量的语义相似度匹配，适合处理同义词、近义词和跨语言查询。\n\n**适用场景**：用户用自然语言描述需求，比如「怎么让搜索更快」而不是精确的关键词「搜索性能优化」。(来源#1: 检索策略对比分析.pdf | 第2页)\n\n### 2. 纯关键词检索（BM25）\n基于倒排索引和 TF-IDF 的精确匹配，对专有名词、代码片段、版本号等有极高的准确性。\n\n**适用场景**：用户查找特定的 API 名称、配置参数、错误码等精确信息。(来源#2: Elasticsearch向量检索指南.pdf | 第18页)\n\n### 3. 混合检索（Hybrid）\n结合上述两种方式，先各自召回候选集，再通过加权融合排序。当前默认权重为 KNN 0.7、BM25 0.3。\n\n**适用场景**：大多数生产环境的通用查询，兼顾语义理解和精确匹配。(来源#3: 混合检索配置说明.pdf | 第8页)\n\n### 推荐策略\n\n| 场景 | 推荐策略 | 理由 |\n|------|---------|------|\n| 客服问答 | Hybrid | 用户表述多样，需要语义兜底 |\n| 代码搜索 | BM25 | 精确匹配函数名/类名 |\n| 文档查重 | KNN | 语义相似度天然适合 |\n| 合规审查 | BM25 | 必须精确匹配条款原文 |\n\n总结：没有一种策略是万能的，建议默认使用 Hybrid，再根据具体业务的数据特征做 A/B 测试微调权重。',
    status: 'finished',
    timestamp: now,
    conversationId: 'conv-active-003',
    username: 'user',
    generationId: 'gen-003',
    referenceMappings: {
      '1': {
        fileMd5: 'jkl101',
        fileName: '检索策略对比分析.pdf',
        pageNumber: 2,
        anchorText: '检索策略概述',
        retrievalMode: 'HYBRID',
        retrievalLabel: '混合召回',
        retrievalQuery: '检索策略对比适用场景',
        score: 0.96,
        chunkId: 42
      },
      '2': {
        fileMd5: 'def456',
        fileName: 'Elasticsearch向量检索指南.pdf',
        pageNumber: 18,
        anchorText: 'BM25 精确匹配',
        retrievalMode: 'TEXT_ONLY',
        retrievalLabel: '关键词召回',
        retrievalQuery: 'BM25 适用场景',
        score: 0.88,
        chunkId: 107
      },
      '3': {
        fileMd5: 'ghi789',
        fileName: '混合检索配置说明.pdf',
        pageNumber: 8,
        anchorText: '混合检索权重配置',
        retrievalMode: 'HYBRID',
        retrievalLabel: '混合召回',
        retrievalQuery: '混合检索权重融合策略',
        evidenceSnippet: 'KNN 权重 0.7 + BM25 权重 0.3 的线性组合在大多数场景下表现稳定',
        score: 0.93,
        chunkId: 56
      }
    },
    toolEvents: [
      {
        id: 'tool-4',
        tool: 'search_knowledge',
        status: 'success',
        timestamp: Date.now() - 3000
      },
      {
        id: 'tool-5',
        tool: 'generate_summary',
        status: 'success',
        timestamp: Date.now() - 1000
      }
    ]
  }
];

export default [
  // --- conversation sessions ---
  {
    url: '/api/v1/users/conversations',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockSessions,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/users/conversations',
    method: 'post',
    response: () => ({
      code: 200,
      data: {
        id: mockSessions.length + 1,
        conversationId: `conv-active-${String(mockSessions.length + 1).padStart(3, '0')}`,
        title: '新的对话',
        status: 'ACTIVE' as const,
        createdAt: now,
        updatedAt: now
      } as Api.Chat.ConversationSession,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/users/conversations/:cid/switch',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/users/conversation',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockMessages.map(m => ({
        ...m,
        username: m.username || (m.conversationId === 'conv-active-001' ? 'admin' : 'user')
      })),
      message: 'ok'
    })
  },
  {
    url: '/api/v1/users/conversations/:cid/archive',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/users/conversations/:cid/unarchive',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- chat ---
  {
    url: '/api/v1/chat/websocket-token',
    method: 'get',
    response: () => ({
      code: 200,
      data: { cmdToken: 'mock-cmd-token' } as Api.Chat.Token,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/chat/generation/:id',
    method: 'get',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/chat/active-generation',
    method: 'get',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/chat/feedback',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- documents ---
  {
    url: '/api/v1/documents/reference-detail',
    method: 'get',
    response: ({ query }: { query: Record<string, string> }) => {
      const allRefs: Api.Document.ReferenceDetailResponse[] = [
        {
          referenceNumber: 1,
          fileMd5: 'abc123',
          fileName: 'RAG架构设计文档.pdf',
          pageNumber: 3,
          anchorText: 'RAG 架构概述',
          retrievalMode: 'HYBRID',
          score: 0.95
        },
        {
          referenceNumber: 2,
          fileMd5: 'def456',
          fileName: 'Elasticsearch向量检索指南.pdf',
          pageNumber: 12,
          anchorText: 'dense_vector 配置',
          retrievalMode: 'TEXT_ONLY',
          score: 0.87
        },
        {
          referenceNumber: 3,
          fileMd5: 'ghi789',
          fileName: '混合检索配置说明.pdf',
          pageNumber: 5,
          anchorText: '权重配置',
          retrievalMode: 'HYBRID',
          score: 0.92
        },
        {
          referenceNumber: 4,
          fileMd5: 'jkl101',
          fileName: '检索策略对比分析.pdf',
          pageNumber: 2,
          anchorText: '检索策略概述',
          retrievalMode: 'HYBRID',
          retrievalQuery: '检索策略对比适用场景',
          matchedChunkText: 'KNN 适合语义搜索，BM25 适合精确匹配，Hybrid 是两者的折中方案',
          score: 0.96,
          chunkId: 42
        },
        {
          referenceNumber: 5,
          fileMd5: 'def456',
          fileName: 'Elasticsearch向量检索指南.pdf',
          pageNumber: 18,
          anchorText: 'BM25 精确匹配',
          retrievalMode: 'TEXT_ONLY',
          retrievalQuery: 'BM25 适用场景',
          matchedChunkText: 'BM25 在专有名词、代码标识符和版本号等场景下准确率接近 100%',
          score: 0.88,
          chunkId: 107
        },
        {
          referenceNumber: 6,
          fileMd5: 'ghi789',
          fileName: '混合检索配置说明.pdf',
          pageNumber: 8,
          anchorText: '混合检索权重配置',
          retrievalMode: 'HYBRID',
          retrievalQuery: '混合检索权重融合策略',
          evidenceSnippet: 'KNN 权重 0.7 + BM25 权重 0.3 的线性组合在大多数场景下表现稳定',
          matchedChunkText: '建议默认使用 KNN=0.7 BM25=0.3，定期通过 A/B 测试验证',
          score: 0.93,
          chunkId: 56
        }
      ];
      const nums = query.refNums?.split(',').map(Number) || [];
      return {
        code: 200,
        data: nums.length ? allRefs.filter(r => nums.includes(r.referenceNumber)) : allRefs,
        message: 'ok'
      };
    }
  }
] as MockMethod[];
