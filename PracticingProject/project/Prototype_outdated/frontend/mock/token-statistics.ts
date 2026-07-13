import type { MockMethod } from 'vite-plugin-mock';

const mockTokenData: Api.TokenStatistics.DepartmentUsage[] = [
  {
    tagId: 'engineering',
    name: '工程部',
    parentTag: null,
    lastDay: 12500,
    lastWeek: 89500,
    lastMonth: 365000,
    lastYear: 4280000,
    total: 5890000,
    children: [
      {
        tagId: 'engineering-frontend',
        name: '前端组',
        parentTag: 'engineering',
        lastDay: 3800,
        lastWeek: 26800,
        lastMonth: 108000,
        lastYear: 1296000,
        total: 1750000
      },
      {
        tagId: 'engineering-backend',
        name: '后端组',
        parentTag: 'engineering',
        lastDay: 5200,
        lastWeek: 36400,
        lastMonth: 148000,
        lastYear: 1776000,
        total: 2380000
      },
      {
        tagId: 'engineering-ai',
        name: 'AI 组',
        parentTag: 'engineering',
        lastDay: 3500,
        lastWeek: 26300,
        lastMonth: 109000,
        lastYear: 1208000,
        total: 1760000
      }
    ]
  },
  {
    tagId: 'search',
    name: '搜索团队',
    parentTag: null,
    lastDay: 8200,
    lastWeek: 57400,
    lastMonth: 236000,
    lastYear: 2832000,
    total: 3780000
  },
  {
    tagId: 'product',
    name: '产品部',
    parentTag: null,
    lastDay: 4500,
    lastWeek: 31500,
    lastMonth: 128000,
    lastYear: 1536000,
    total: 2050000,
    children: [
      {
        tagId: 'product-design',
        name: '产品设计组',
        parentTag: 'product',
        lastDay: 1800,
        lastWeek: 12600,
        lastMonth: 51200,
        lastYear: 614400,
        total: 820000
      }
    ]
  },
  {
    tagId: 'management',
    name: '管理层',
    parentTag: null,
    lastDay: 1800,
    lastWeek: 12600,
    lastMonth: 52000,
    lastYear: 624000,
    total: 820000
  }
];

export default [
  {
    url: '/api/v1/token-statistics/department',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockTokenData,
      message: 'ok'
    })
  }
] as MockMethod[];
