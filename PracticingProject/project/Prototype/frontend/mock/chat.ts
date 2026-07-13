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
  }
];

const mockMessages: Api.Chat.Message[] = [
  {
    role: 'user',
    content: '请解释一下知识库的 RAG 架构是怎么设计的？',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001'
  },
  {
    role: 'assistant',
    content: 'RAG（Retrieval-Augmented Generation）架构的核心思想是将检索系统与生成模型结合。在我们的知识库中，整个流程分为以下几步：\n\n1. **文档预处理**：上传的文档经过 PDF 解析、文本切块（chunking）后，通过 Embedding 模型（如 text-embedding-v4）将每个文本块转换为 2048 维向量。\n\n2. **向量存储**：向量数据和原始文本存储在 Elasticsearch 中，使用 dense_vector 类型支持 KNN 检索，同时使用 IK 分词器支持 BM25 关键词检索。\n\n3. **混合检索**：用户提问时，系统同时执行向量相似度检索和关键词检索，通过加权融合（Hybrid Search）返回最相关的结果。\n\n4. **上下文增强**：将检索到的文档片段作为上下文注入 LLM 的 prompt 中，让模型基于这些资料生成准确的回答。\n\n5. **引用溯源**：每个回答都会标注引用的来源文档和页码，用户可以点击引用查看原文。\n\n这种架构的优势在于：模型回答有据可查，减少幻觉，并且可以随时更新知识库而不需要重新训练模型。',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
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
    conversationId: 'conv-active-001'
  },
  {
    role: 'assistant',
    content: '混合检索的权重配置在 `HybridSearchService` 中管理，默认配置为：\n\n- **向量检索（KNN）权重**：0.7（主要依赖语义相似度）\n- **关键词检索（BM25）权重**：0.3（辅助精确匹配）\n\n权重可以通过以下方式调整：\n\n1. 在配置文件中修改 `search.knn.weight` 和 `search.bm25.weight` 参数\n2. 通过管理后台的动态配置功能实时调整\n3. 针对不同的知识库领域，可以使用不同的权重配比\n\n实际效果上，语义检索擅长理解同义词和上下文，关键词检索则保证专有名词和术语的精确命中，两者互补。',
    status: 'finished',
    timestamp: hourAgo,
    conversationId: 'conv-active-001',
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
  }
];

export default [
  // --- conversation sessions ---
  {
    url: '/users/conversations',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockSessions,
      message: 'ok'
    })
  },
  {
    url: '/users/conversations',
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
    url: '/users/conversations/:cid/switch',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/users/conversation',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockMessages,
      message: 'ok'
    })
  },
  {
    url: '/users/conversations/:cid/archive',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/users/conversations/:cid/unarchive',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- chat ---
  {
    url: '/chat/websocket-token',
    method: 'get',
    response: () => ({
      code: 200,
      data: { cmdToken: 'mock-cmd-token' } as Api.Chat.Token,
      message: 'ok'
    })
  },
  {
    url: '/chat/generation/:id',
    method: 'get',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/chat/active-generation',
    method: 'get',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/chat/feedback',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  // --- documents ---
  {
    url: '/documents/reference-detail',
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
