import type { MockMethod } from 'vite-plugin-mock';

// ==================== Mock 账号存储 ====================
// 在 vite-plugin-mock 无状态模式下，用模块级变量跟踪当前登录用户

interface MockAccount {
  password: string;
  userInfo: Api.Auth.UserInfo;
}

const mockAccounts: Record<string, MockAccount> = {
  admin: {
    password: 'admin123',
    userInfo: {
      id: 1,
      userName: 'admin',
      role: 'ADMIN',
      orgTags: ['ADMIN'],
      primaryOrg: 'ADMIN'
    }
  },
  user: {
    password: 'user123',
    userInfo: {
      id: 2,
      userName: 'user',
      role: 'USER',
      orgTags: ['USER_A'],
      primaryOrg: 'USER_A'
    }
  }
};

/** 当前登录用户，用于 /users/me 返回正确的角色 */
let currentUser: Api.Auth.UserInfo | null = null;

// ==================== Mock API ====================

export default [
  {
    url: '/api/v1/users/login',
    method: 'post',
    response: (req) => {
      const { username, password } = (req.body || {}) as { username?: string; password?: string };
      const account = username ? mockAccounts[username] : undefined;

      if (!account || account.password !== password) {
        return {
          code: 400,
          data: null,
          message: '用户名或密码错误（可用账号: admin/admin123, user/user123）'
        };
      }

      currentUser = account.userInfo;

      return {
        code: 200,
        data: {
          token: `mock-jwt-token-${username}`,
          refreshToken: `mock-refresh-token-${username}`
        } as Api.Auth.LoginToken,
        message: 'ok'
      };
    }
  },
  {
    url: '/api/v1/users/logout',
    method: 'post',
    response: () => {
      currentUser = null;
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
      // 若 currentUser 为空（dev server 重启后），返回 401 要求重新登录
      if (!currentUser) {
        return {
          code: 401,
          data: null,
          message: '未登录或登录已过期，请重新登录'
        };
      }

      return {
        code: 200,
        data: { ...currentUser },
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
        token: 'mock-jwt-token-refreshed',
        refreshToken: 'mock-refresh-token-refreshed'
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
