import type { MockMethod } from 'vite-plugin-mock';

const mockUsers = [
  {
    userId: 1,
    username: 'admin',
    status: 0,
    orgTags: [
      { tagId: 'engineering', name: '工程部' },
      { tagId: 'management', name: '管理层' }
    ],
    primaryOrg: 'engineering',
    createdAt: '2026-07-01T10:00:00'
  },
  {
    userId: 2,
    username: 'user',
    status: 1,
    orgTags: [
      { tagId: 'product', name: '产品部' }
    ],
    primaryOrg: 'product',
    createdAt: '2026-07-02T14:30:00'
  },
  {
    userId: 3,
    username: 'zhangsan',
    status: 1,
    orgTags: [
      { tagId: 'engineering', name: '工程部' },
      { tagId: 'engineering-frontend', name: '前端组' }
    ],
    primaryOrg: 'engineering',
    createdAt: '2026-07-03T09:15:00'
  },
  {
    userId: 4,
    username: 'lisi',
    status: 1,
    orgTags: [
      { tagId: 'search', name: '搜索团队' }
    ],
    primaryOrg: 'search',
    createdAt: '2026-07-04T16:00:00'
  },
  {
    userId: 5,
    username: 'wangwu',
    status: 1,
    orgTags: [],
    primaryOrg: 'product',
    createdAt: '2026-07-05T11:20:00'
  }
];

let userData = [...mockUsers];

export default [
  {
    url: '/api/v1/admin/users/list',
    method: 'get',
    response: (req) => {
      const { keyword, orgTag, page = '1', size = '10' } = (req.query || {}) as Record<string, string>;

      let filtered = [...userData];

      // keyword filter: match username or userId
      if (keyword) {
        const kw = keyword.toLowerCase();
        filtered = filtered.filter(
          u => u.username.toLowerCase().includes(kw) || String(u.userId) === kw
        );
      }

      // orgTag filter: match any of user's org tag tagIds
      if (orgTag) {
        filtered = filtered.filter(u => u.orgTags.some(t => t.tagId === orgTag));
      }

      const pageNum = Math.max(1, Number(page));
      const pageSize = Math.max(1, Number(size));
      const total = filtered.length;
      const start = (pageNum - 1) * pageSize;
      const content = filtered.slice(start, start + pageSize);

      return {
        code: 200,
        message: 'ok',
        data: {
          content,
          totalElements: total,
          totalPages: Math.ceil(total / pageSize),
          size: pageSize,
          number: pageNum
        }
      };
    }
  },
  {
    url: '/api/v1/admin/users/:userId/org-tags',
    method: 'put',
    response: (req) => {
      const { userId } = (req.params || {}) as Record<string, string>;
      const { orgTags } = (req.body || {}) as { orgTags?: string[] };
      const uid = Number(userId);

      const user = userData.find(u => u.userId === uid);
      if (!user) {
        return { code: 404, message: '用户不存在' };
      }

      // Simple mock: treat orgTags as tagId strings, mock name = tagId
      user.orgTags = (orgTags || []).map(tagId => ({ tagId, name: tagId }));
      return { code: 200, message: '分配成功' };
    }
  }
] as MockMethod[];
