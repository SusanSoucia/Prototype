import type { MockMethod } from 'vite-plugin-mock';

// 与 mock/org-tag.ts 保持同步的标签数据
const mockUsers: Api.Admin.User[] = [
  {
    userId: 1,
    username: 'admin',
    role: 'ADMIN',
    orgTags: [
      { tagId: 'engineering', name: '工程部' },
      { tagId: 'management', name: '管理层' }
    ],
    primaryOrg: 'management',
    status: 0,
    createdAt: new Date('2024-01-15').toISOString()
  },
  {
    userId: 2,
    username: 'zhangsan',
    role: 'LIBRARY_ADMIN',
    orgTags: [
      { tagId: 'search', name: '搜索团队' }
    ],
    primaryOrg: 'search',
    status: 2,
    createdAt: new Date('2024-03-20').toISOString()
  },
  {
    userId: 3,
    username: 'lisi',
    role: 'LIBRARY_ADMIN',
    orgTags: [
      { tagId: 'product', name: '产品部' }
    ],
    primaryOrg: 'product',
    status: 2,
    createdAt: new Date('2024-05-10').toISOString()
  },
  {
    userId: 4,
    username: 'wangwu',
    role: 'USER',
    orgTags: [
      { tagId: 'engineering-frontend', name: '前端组' }
    ],
    primaryOrg: 'engineering',
    status: 1,
    createdAt: new Date('2024-06-01').toISOString()
  },
  {
    userId: 5,
    username: 'zhaoliu',
    role: 'USER',
    orgTags: [
      { tagId: 'engineering-backend', name: '后端组' }
    ],
    primaryOrg: 'engineering',
    status: 1,
    createdAt: new Date('2024-07-15').toISOString()
  },
  {
    userId: 6,
    username: 'sunqi',
    role: 'USER',
    orgTags: [
      { tagId: 'engineering-ai', name: 'AI 组' },
      { tagId: 'search', name: '搜索团队' }
    ],
    primaryOrg: 'engineering',
    status: 1,
    createdAt: new Date('2024-08-01').toISOString()
  },
  {
    userId: 7,
    username: 'zhouba',
    role: 'USER',
    orgTags: [
      { tagId: 'product-design', name: '产品设计组' }
    ],
    primaryOrg: 'product',
    status: 1,
    createdAt: new Date('2024-09-12').toISOString()
  },
  {
    userId: 8,
    username: 'wujiu',
    role: 'USER',
    orgTags: [],
    primaryOrg: null,
    status: 1,
    createdAt: new Date('2024-10-20').toISOString()
  },
  {
    userId: 9,
    username: 'zhengshi',
    role: 'USER',
    orgTags: [
      { tagId: 'search', name: '搜索团队' }
    ],
    primaryOrg: 'search',
    status: 1,
    createdAt: new Date('2024-11-05').toISOString()
  },
  {
    userId: 10,
    username: 'chenyi',
    role: 'LIBRARY_ADMIN',
    orgTags: [
      { tagId: 'engineering', name: '工程部' },
      { tagId: 'product', name: '产品部' }
    ],
    primaryOrg: 'engineering',
    status: 2,
    createdAt: new Date('2024-12-01').toISOString()
  },
  {
    userId: 11,
    username: 'liuer',
    role: 'USER',
    orgTags: [
      { tagId: 'engineering', name: '工程部' }
    ],
    primaryOrg: 'engineering',
    status: 1,
    createdAt: new Date('2025-01-10').toISOString()
  },
  {
    userId: 12,
    username: 'wusan',
    role: 'USER',
    orgTags: [
      { tagId: 'management', name: '管理层' }
    ],
    primaryOrg: 'management',
    status: 1,
    createdAt: new Date('2025-02-14').toISOString()
  }
];

export default [
  {
    url: '/api/v1/admin/users/list',
    method: 'get',
    response: ({ query }: { query: Record<string, string> }) => {
      let filtered = mockUsers;

      // 按关键字过滤（匹配用户名）
      if (query.keyword) {
        const kw = query.keyword.toLowerCase();
        filtered = filtered.filter(u => u.username.toLowerCase().includes(kw));
      }

      // 按组织标签过滤
      if (query.orgTag) {
        filtered = filtered.filter(u => u.orgTags.some(t => t.tagId === query.orgTag));
      }

      // 按角色状态过滤（0=ADMIN, 1=USER, 2=LIBRARY_ADMIN）
      if (query.status !== undefined && query.status !== '') {
        const s = Number(query.status);
        filtered = filtered.filter(u => u.status === s);
      }

      const totalElements = filtered.length;
      const size = Math.max(Number(query.size) || 10, 1);
      // Naive UI pagination uses 1-indexed pages, convert to 0-indexed for slicing
      const page1 = Math.max(Number(query.page) || 1, 1);
      const totalPages = Math.ceil(totalElements / size);
      const start = (page1 - 1) * size;
      const content = filtered.slice(start, start + size);

      return {
        code: 200,
        data: {
          content,
          totalElements,
          totalPages,
          number: page1 - 1,
          size
        },
        message: 'ok'
      };
    }
  },
  {
    url: '/api/v1/admin/users',
    method: 'get',
    response: () => ({
      code: 200,
      data: mockUsers,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/admin/users/create-admin',
    method: 'post',
    response: () => ({
      code: 200,
      data: null,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/admin/users/:userId/org-tags',
    method: 'put',
    response: () => ({
      code: 200,
      data: null,
      message: 'ok'
    })
  }
] as MockMethod[];
