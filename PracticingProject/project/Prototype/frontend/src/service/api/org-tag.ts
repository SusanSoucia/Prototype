import { request } from '../request';
import { localStg } from '@/utils/storage';

export type FetchOrgTagTreeResult = {
  number: number;
  size: number;
  totalElements: number;
  data: Api.OrgTag.Item[];
};

/** 检查是否处于 dev mock 模式 */
function isDevMockMode(): boolean {
  if (!import.meta.env.DEV) return false;
  const devMockRole = import.meta.env.VITE_DEV_MOCK_ROLE as string | undefined;
  if (!devMockRole) return false;
  if (localStg.get('token') !== 'dev-mock-token') return false;
  return true;
}

/**
 * Mock 组织标签树，反映正确的架构：
 * - ADMIN（超管标签）：子标签是各个库管标签（知识库）
 * - USER（用户标签）：子标签是各部门
 */
function getMockOrgTagTree(): FetchOrgTagTreeResult {
  const tree: Api.OrgTag.Item[] = [
    {
      tagId: 'ADMIN',
      name: '管理员',
      description: '超级管理员身份标签，子标签为各库管',
      parentTag: null,
      children: [
        {
          tagId: 'LIB_A',
          name: '库管A',
          description: '研发部知识库管理者',
          parentTag: 'ADMIN',
          children: []
        },
        {
          tagId: 'LIB_B',
          name: '库管B',
          description: '产品部知识库管理者',
          parentTag: 'ADMIN',
          children: []
        }
      ]
    },
    {
      tagId: 'USER',
      name: '用户',
      description: '普通用户标签，子标签为各部门',
      parentTag: null,
      children: [
        {
          tagId: 'USER_A',
          name: '工程部',
          description: '负责核心产品研发与技术架构',
          parentTag: 'USER',
          children: [
            {
              tagId: 'USER_A_SEARCH',
              name: '搜索团队',
              description: '负责检索引擎、向量化与知识库管理',
              parentTag: 'USER_A',
              children: []
            }
          ]
        },
        {
          tagId: 'USER_B',
          name: '产品部',
          description: '负责产品规划与需求管理',
          parentTag: 'USER',
          children: []
        },
        {
          tagId: 'USER_C',
          name: '管理层',
          description: '公司战略决策与资源调配',
          parentTag: 'USER',
          children: []
        }
      ]
    }
  ];

  return {
    number: 0,
    size: tree.length,
    totalElements: tree.length,
    data: tree
  };
}

export function fetchGetOrgTagTree() {
  // Dev mock: 无后端时返回模拟标签树
  if (isDevMockMode()) {
    console.log('[dev-mock] Returning mock org-tag tree');
    return Promise.resolve({ error: null, data: getMockOrgTagTree() as any });
  }

  return request<FetchOrgTagTreeResult>({ url: '/admin/org-tags/tree' });
}

export async function fetchGetOrgTagList(
  params: Api.Common.CommonSearchParams = { page: 1, size: 10 }
): Promise<NaiveUI.FlatResponseData<Api.OrgTag.List>> {
  // Dev mock: 无后端时 flatList 复用 tree mock
  if (isDevMockMode()) {
    const mockTree = getMockOrgTagTree();
    const allData = flattenTagTree(mockTree.data);
    const page = params.page && params.page > 0 ? params.page : 1;
    const size = params.size && params.size > 0 ? params.size : 10;
    const start = (page - 1) * size;
    const pageData = allData.slice(start, start + size);

    return {
      error: null,
      data: {
        data: pageData,
        content: pageData,
        number: page,
        size,
        totalElements: allData.length
      }
    } as any;
  }

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

/** 将标签树扁平化 */
function flattenTagTree(items: Api.OrgTag.Item[]): Api.OrgTag.Item[] {
  const result: Api.OrgTag.Item[] = [];
  for (const item of items) {
    result.push(item);
    if (item.children?.length) {
      result.push(...flattenTagTree(item.children));
    }
  }
  return result;
}
