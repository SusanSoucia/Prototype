import { request } from '../request';
import { localStg } from '@/utils/storage';

/** 检查是否处于 dev mock 模式 */
function isDevMockMode(): boolean {
  if (!import.meta.env.DEV) return false;
  const devMockRole = import.meta.env.VITE_DEV_MOCK_ROLE as string | undefined;
  if (!devMockRole) return false;
  if (localStg.get('token') !== 'dev-mock-token') return false;
  return true;
}

function getMockUsers(): any[] {
  return [
    {
      userId: 1,
      username: 'admin',
      role: 'ADMIN',
      status: 0,
      orgTags: [{ tagId: 'ADMIN', name: '管理员' }],
      primaryOrg: 'ADMIN',
      createdAt: '2025-01-01T00:00:00'
    },
    {
      userId: 2,
      username: 'librarian',
      role: 'LIBRARY_ADMIN',
      status: 2,
      orgTags: [{ tagId: 'LIB_A', name: '库管A' }],
      primaryOrg: 'LIB_A',
      createdAt: '2025-03-15T00:00:00'
    },
    {
      userId: 3,
      username: 'user',
      role: 'USER',
      status: 1,
      orgTags: [{ tagId: 'USER_A', name: '工程部' }],
      primaryOrg: 'USER_A',
      createdAt: '2025-06-01T00:00:00'
    }
  ];
}

/**
 * Get all users (ADMIN and LIBRARY_ADMIN)
 */
export function fetchGetUsers() {
  if (isDevMockMode()) {
    return Promise.resolve({ error: null, data: getMockUsers() as any });
  }
  return request<Api.Admin.User[]>({ url: '/admin/users' });
}

/**
 * Get paginated user list with filters
 */
export async function fetchGetUserList(
  params: Api.Admin.UserListParams = {}
): Promise<NaiveUI.FlatResponseData<Api.Admin.UserList>> {
  if (isDevMockMode()) {
    let users = getMockUsers();
    // 简单筛选
    if (params.keyword) {
      const kw = params.keyword.toLowerCase();
      users = users.filter((u: any) => u.username.toLowerCase().includes(kw));
    }
    if (params.orgTag) {
      users = users.filter((u: any) => u.orgTags?.some((t: any) => t.tagId === params.orgTag));
    }
    const page = params.page || 1;
    const size = params.size || 10;
    const start = (page - 1) * size;
    const pageData = users.slice(start, start + size);

    return {
      error: null,
      data: {
        data: pageData,
        content: pageData,
        number: page - 1,
        size,
        totalElements: users.length
      }
    } as any;
  }

  const response = await request<Api.Admin.UserListResult>({ url: '/admin/users/list', params });
  if (response.error) {
    return response as NaiveUI.FlatResponseData<Api.Admin.UserList>;
  }

  const payload = response.data;
  return {
    ...response,
    data: {
      data: payload?.content || [],
      content: payload?.content || [],
      number: payload?.number ?? 0,
      size: payload?.size || 10,
      totalElements: payload?.totalElements || 0,
    },
  };
}

/**
 * Create an admin or library_admin user (ADMIN only)
 */
export function fetchCreateAdminUser(data: { username: string; password: string; role?: string }) {
  return request({ url: '/admin/users/create-admin', method: 'post', data });
}

/**
 * Assign organization tags to a user (ADMIN only)
 */
export function fetchAssignOrgTagsToUser(userId: number, orgTags: string[]) {
  return request({ url: `/admin/users/${userId}/org-tags`, method: 'put', data: { orgTags } });
}

/**
 * Get all organization tags (ADMIN and LIBRARY_ADMIN)
 */
export function fetchGetAllOrgTags() {
  return request<Api.OrgTag.Item[]>({ url: '/admin/org-tags' });
}

/**
 * Create an organization tag (ADMIN only)
 */
export function fetchCreateOrgTag(data: {
  tagId: string;
  name: string;
  description: string;
  parentTag?: string | null;
}) {
  return request({ url: '/admin/org-tags', method: 'post', data });
}

/**
 * Update an organization tag (ADMIN only)
 */
export function fetchUpdateOrgTag(
  tagId: string,
  data: { name: string; description: string; parentTag?: string | null }
) {
  return request({ url: `/admin/org-tags/${tagId}`, method: 'put', data });
}

/**
 * Delete an organization tag (ADMIN only)
 */
export function fetchDeleteOrgTag(tagId: string) {
  return request({ url: `/admin/org-tags/${tagId}`, method: 'delete' });
}
