import { request } from '../request';

interface FetchGetUserListParams {
  keyword?: string;
  orgTag?: string;
  status?: number;
  page?: number;
  size?: number;
}

/**
 * Fetch user list with optional filters
 *
 * Backend: GET /api/v1/admin/users/list
 */
export function fetchGetUserList(params: FetchGetUserListParams = {}) {
  const requestParams: Record<string, any> = {};

  if (params.keyword) requestParams.keyword = params.keyword;
  if (params.orgTag) requestParams.orgTag = params.orgTag;
  if (params.status !== undefined && params.status !== null) requestParams.status = params.status;
  requestParams.page = params.page || 1;
  requestParams.size = params.size || 10;

  return request<Api.UserManagement.List>({
    url: '/admin/users/list',
    params: requestParams
  });
}

/**
 * Assign org tags to a user
 *
 * Backend: PUT /api/v1/admin/users/{userId}/org-tags
 */
export function fetchAssignOrgTagsToUser(userId: number, orgTags: string[]) {
  return request({
    url: `/admin/users/${userId}/org-tags`,
    method: 'PUT',
    data: { orgTags }
  });
}
