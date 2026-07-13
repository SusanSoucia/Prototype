import type { MockMethod } from 'vite-plugin-mock';

const mockOrgTags: Api.OrgTag.Item[] = [
  {
    tagId: 'engineering',
    name: '工程部',
    description: '负责核心产品研发与技术架构',
    parentTag: null,
    uploadMaxSizeBytes: 104_857_600,
    uploadMaxSizeMb: 100,
    children: [
      {
        tagId: 'engineering-frontend',
        name: '前端组',
        description: '负责 Web 前端与用户体验',
        parentTag: 'engineering',
        uploadMaxSizeBytes: 52_428_800,
        uploadMaxSizeMb: 50
      },
      {
        tagId: 'engineering-backend',
        name: '后端组',
        description: '负责服务端架构与 API 开发',
        parentTag: 'engineering',
        uploadMaxSizeBytes: 52_428_800,
        uploadMaxSizeMb: 50
      },
      {
        tagId: 'engineering-ai',
        name: 'AI 组',
        description: '负责大模型应用与算法研究',
        parentTag: 'engineering',
        uploadMaxSizeBytes: 104_857_600,
        uploadMaxSizeMb: 100
      }
    ]
  },
  {
    tagId: 'search',
    name: '搜索团队',
    description: '负责检索引擎、向量化与知识库管理',
    parentTag: null,
    uploadMaxSizeBytes: 209_715_200,
    uploadMaxSizeMb: 200
  },
  {
    tagId: 'product',
    name: '产品部',
    description: '负责产品规划与需求管理',
    parentTag: null,
    uploadMaxSizeBytes: 52_428_800,
    uploadMaxSizeMb: 50,
    children: [
      {
        tagId: 'product-design',
        name: '产品设计组',
        description: '负责产品原型与交互设计',
        parentTag: 'product',
        uploadMaxSizeBytes: 31_457_280,
        uploadMaxSizeMb: 30
      }
    ]
  },
  {
    tagId: 'management',
    name: '管理层',
    description: '公司战略决策与资源调配',
    parentTag: null,
    uploadMaxSizeBytes: 524_288_000,
    uploadMaxSizeMb: 500
  }
];

let nextId = 1;

export default [
  {
    url: '/api/v1/admin/org-tags/tree',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockOrgTags,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/admin/org-tags',
    method: 'post',
    response: () => ({
      code: 200,
      data: { tagId: `new-tag-${nextId++}`, name: '', description: '', parentTag: null },
      message: 'ok'
    })
  },
  {
    url: '/api/v1/admin/org-tags/:tagId',
    method: 'put',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/admin/org-tags/:tagId',
    method: 'delete',
    response: () => ({ code: 200, data: null, message: 'ok' })
  }
] as MockMethod[];
