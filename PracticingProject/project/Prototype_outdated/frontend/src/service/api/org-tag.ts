import { request } from '../request';

export type FetchOrgTagTreeResult = {
  number: number;
  size: number;
  totalElements: number;
  data: Api.OrgTag.Item[];
};

export function fetchGetOrgTagTree() {
  return request<FetchOrgTagTreeResult>({ url: '/admin/org-tags/tree' });
}

export async function fetchGetOrgTagList(
  params: Api.Common.CommonSearchParams = { page: 1, size: 10 }
): Promise<NaiveUI.FlatResponseData<Api.OrgTag.List>> {
  // 构建请求参数（将 CommonSearchParams 的 page/size 转换为后端期望的参数）
  const requestParams: Record<string, any> = {};
  if (params.page) {
    requestParams.page = params.page;
  }
  if (params.size) {
    requestParams.size = params.size;
  }

  const response = await request<FetchOrgTagTreeResult>({ url: '/admin/org-tags/tree', params: requestParams });
  if (response.error) {
    console.error('[org-tag] fetchGetOrgTagList error:', response.error);
    return response as NaiveUI.FlatResponseData<Api.OrgTag.List>;
  }

  const payload = response.data;
  console.log('[org-tag] fetchGetOrgTagList raw payload type:', typeof payload, 'isArray:', Array.isArray(payload), payload);

  // Normalize: extract the items array from whatever shape the backend returns
  let allData: Api.OrgTag.Item[] = [];

  if (Array.isArray(payload)) {
    // Backend returns a flat array (e.g. mock or simple tree endpoint)
    allData = payload;
  } else if (payload && typeof payload === 'object') {
    // Backend returns a paginated wrapper — try common keys
    allData = (payload as any).data || (payload as any).content || (payload as any).records || [];
  }

  if (!Array.isArray(allData) || allData.length === 0) {
    console.warn('[org-tag] No org-tag data found in response. payload:', payload);
  }

  const page = params.page && params.page > 0 ? params.page : 1;
  const size = params.size && params.size > 0 ? params.size : 10;
  const start = (page - 1) * size;
  const pageData = allData.slice(start, start + size);

  return {
    ...response,
    data: {
      data: pageData,
      content: pageData,
      number: page,
      size,
      totalElements: allData.length,
    },
  };
}
