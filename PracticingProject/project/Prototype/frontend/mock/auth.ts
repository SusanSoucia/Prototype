import type { MockMethod } from 'vite-plugin-mock';

/**
 * Mock 用户数据 — 与 mock/admin.ts 保持一致的账号体系
 *
 * 角色说明：
 * - ADMIN: 超管，可访问 api-usage / knowledge-base / org-tag / user-monitor
 * - LIBRARY_ADMIN: 库管，可访问 chat-history / chats / knowledge-base
 * - USER: 普通用户，可访问 chat-history / chats
 *
 * 调试时输入对应 username 即可切换身份（密码可为任意非空字符串）：
 *   admin     → ADMIN
 *   librarian → LIBRARY_ADMIN
 *   user      → USER
 *   zhangsan  → LIBRARY_ADMIN
 *   wangwu    → USER
 */

interface MockUser {
  id: number;
  userName: string;
  role: 'ADMIN' | 'LIBRARY_ADMIN' | 'USER';
  orgTags: string[];
  primaryOrg: string;
}

const MOCK_USERS: Record<string, MockUser> = {
  // ==================== ADMIN ====================
  admin: {
    id: 1,
    userName: 'admin',
    role: 'ADMIN',
    orgTags: ['engineering', 'management'],
    primaryOrg: 'management'
  },

  // ==================== LIBRARY_ADMIN（库管）====================
  librarian: {
    id: 2,
    userName: 'librarian',
    role: 'LIBRARY_ADMIN',
    orgTags: ['search'],
    primaryOrg: 'search'
  },
  zhangsan: {
    id: 3,
    userName: 'zhangsan',
    role: 'LIBRARY_ADMIN',
    orgTags: ['search'],
    primaryOrg: 'search'
  },
  lisi: {
    id: 4,
    userName: 'lisi',
    role: 'LIBRARY_ADMIN',
    orgTags: ['product'],
    primaryOrg: 'product'
  },
  chenyi: {
    id: 10,
    userName: 'chenyi',
    role: 'LIBRARY_ADMIN',
    orgTags: ['engineering', 'product'],
    primaryOrg: 'engineering'
  },

  // ==================== USER（普通用户）====================
  user: {
    id: 5,
    userName: 'user',
    role: 'USER',
    orgTags: ['engineering-frontend'],
    primaryOrg: 'engineering'
  },
  wangwu: {
    id: 6,
    userName: 'wangwu',
    role: 'USER',
    orgTags: ['engineering-frontend'],
    primaryOrg: 'engineering'
  },
  zhaoliu: {
    id: 7,
    userName: 'zhaoliu',
    role: 'USER',
    orgTags: ['engineering-backend'],
    primaryOrg: 'engineering'
  },
  sunqi: {
    id: 8,
    userName: 'sunqi',
    role: 'USER',
    orgTags: ['engineering-ai', 'search'],
    primaryOrg: 'engineering'
  },
  zhouba: {
    id: 9,
    userName: 'zhouba',
    role: 'USER',
    orgTags: ['product-design'],
    primaryOrg: 'product'
  }
};

/**
 * 当前已登录的用户名。
 * 每次 POST /users/login 成功后更新，供 GET /users/me 返回对应的用户信息。
 * 账号切换：在登录页输入不同 username 即可。
 */
let currentLoginUsername = 'admin';

export default [
  {
    url: '/api/v1/users/login',
    method: 'post',
    response: ({ body }: { body: { username?: string; password?: string } }) => {
      const username = body?.username || 'admin';
      const password = body?.password || '';

      // 验证密码非空
      if (!password) {
        return {
          code: 401,
          data: null,
          message: '密码不能为空'
        };
      }

      // 检查用户是否存在
      const user = MOCK_USERS[username];
      if (!user) {
        return {
          code: 401,
          data: null,
          message: `用户 "${username}" 不存在，可用账号: ${Object.keys(MOCK_USERS).join(', ')}`
        };
      }

      // 记录当前登录用户
      currentLoginUsername = username;
      console.log(`[mock/auth] 用户 "${username}" (角色: ${user.role}) 已登录`);

      return {
        code: 200,
        data: {
          token: `mock-jwt-${username}-${Date.now()}`,
          refreshToken: `mock-refresh-${username}-${Date.now()}`
        } as Api.Auth.LoginToken,
        message: 'ok'
      };
    }
  },
  {
    url: '/api/v1/users/logout',
    method: 'post',
    response: () => {
      console.log(`[mock/auth] 用户 "${currentLoginUsername}" 已登出`);
      currentLoginUsername = 'admin'; // 重置为默认
      return { code: 200, data: null, message: 'ok' };
    }
  },
  {
    url: '/api/v1/users/register',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/users/changePassword',
    method: 'post',
    response: () => ({ code: 200, data: null, message: 'ok' })
  },
  {
    url: '/api/v1/users/me',
    method: 'get',
    response: () => {
      const user = MOCK_USERS[currentLoginUsername] || MOCK_USERS.admin;
      console.log(`[mock/auth] GET /users/me → 用户: ${user.userName}, 角色: ${user.role}`);

      return {
        code: 200,
        data: {
          id: user.id,
          userName: user.userName,
          role: user.role,
          orgTags: user.orgTags,
          primaryOrg: user.primaryOrg
        } as Api.Auth.UserInfo,
        message: 'ok'
      };
    }
  },
  {
    url: '/api/v1/auth/refreshToken',
    method: 'post',
    response: () => ({
      code: 200,
      data: {
        token: `mock-jwt-${currentLoginUsername}-refreshed-${Date.now()}`,
        refreshToken: `mock-refresh-${currentLoginUsername}-refreshed-${Date.now()}`
      } as Api.Auth.LoginToken,
      message: 'ok'
    })
  },
  {
    url: '/api/v1/auth/error',
    method: 'get',
    response: () => ({ code: 200, data: null, message: 'ok' })
  }
] as MockMethod[];
