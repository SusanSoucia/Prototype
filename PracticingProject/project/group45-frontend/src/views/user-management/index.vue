<script setup lang="tsx">
import { NTag, NButton, NSelect, NCard, NSpace } from 'naive-ui';
import { useAppStore } from '@/store/modules/app';
import { useTable, useTableOperate } from '@/hooks/common/table';
import { fetchGetUserList } from '@/service/api/user-management';
import { fetchGetOrgTagTree, type FetchOrgTagTreeResult } from '@/service/api/org-tag';
import AssignOrgTagsDialog from './modules/assign-org-tags-dialog.vue';

const appStore = useAppStore();

// ---- org tag options for filter & dialog ----
const orgTagOptions = ref<{ label: string; value: string }[]>([]);
const selectedOrgTag = ref<string | undefined>(undefined);

function flattenOrgTags(tree: any[]): { label: string; value: string }[] {
  const result: { label: string; value: string }[] = [];
  function walk(nodes: any[]) {
    for (const node of nodes) {
      result.push({ label: node.name, value: node.tagId });
      if (node.children?.length) walk(node.children);
    }
  }
  walk(tree);
  return result;
}

async function loadOrgTagOptions() {
  const { data, error } = await fetchGetOrgTagTree();
  if (!error && data) {
    const tree = Array.isArray(data) ? data : (data as FetchOrgTagTreeResult).data || [];
    orgTagOptions.value = flattenOrgTags(Array.isArray(tree) ? tree : []);
  }
}
loadOrgTagOptions();

// ---- table ----
const { columns, columnChecks, data, loading, getData, mobilePagination, searchParams, updateSearchParams } = useTable({
  apiFn: fetchGetUserList,
  showTotal: true,
  columns: () => [
    {
      key: 'username',
      title: '用户名',
      width: 160,
      ellipsis: { tooltip: true }
    },
    {
      key: 'role',
      title: '角色',
      width: 100,
      render: (row: Api.UserManagement.User) => {
        const isAdmin = row.status === 0;
        return (
          <NTag type={isAdmin ? 'error' : 'info'} size="small">
            {isAdmin ? 'ADMIN' : 'USER'}
          </NTag>
        );
      }
    },
    {
      key: 'orgTags',
      title: '组织标签',
      minWidth: 200,
      render: (row: Api.UserManagement.User) => (
        <NSpace wrap size={4}>
          {row.orgTags?.length
            ? row.orgTags.map(tag => <NTag key={tag.tagId} size="small">{tag.name}</NTag>)
            : <span class="text-stone-400">—</span>}
        </NSpace>
      )
    },
    {
      key: 'primaryOrg',
      title: '主组织',
      width: 120,
      ellipsis: { tooltip: true },
      render: (row: Api.UserManagement.User) => row.primaryOrg || <span class="text-stone-400">—</span>
    },
    {
      key: 'createdAt',
      title: '创建时间',
      width: 180,
      ellipsis: { tooltip: true }
    },
    {
      key: 'operate',
      title: '操作',
      width: 120,
      render: (row: Api.UserManagement.User) => (
        <NButton type="primary" ghost size="small" onClick={() => handleAssignTags(row)}>
          分配标签
        </NButton>
      )
    }
  ]
});

const keywordInput = ref('');

function handleSearch() {
  updateSearchParams({
    keyword: keywordInput.value || undefined,
    orgTag: selectedOrgTag.value || undefined
  });
  getData();
}

function handleReset() {
  keywordInput.value = '';
  selectedOrgTag.value = undefined;
  updateSearchParams({ keyword: undefined, orgTag: undefined });
  getData();
}

// ---- assign org tags dialog ----
const assignDialogVisible = ref(false);
const currentUser = ref<Api.UserManagement.User | null>(null);

function handleAssignTags(row: Api.UserManagement.User) {
  currentUser.value = row;
  assignDialogVisible.value = true;
}
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="用户管理" :bordered="false" size="small" class="sm:flex-1-hidden card-wrapper">
      <template #header-extra>
        <NSpace align="center" wrap>
          <NInput
            v-model:value="keywordInput"
            placeholder="用户名/ID搜索"
            clearable
            size="small"
            class="w-180px"
            @keyup.enter="handleSearch"
          />
          <NSelect
            v-model:value="selectedOrgTag"
            :options="orgTagOptions"
            placeholder="按标签过滤"
            clearable
            size="small"
            class="w-160px"
            @update:value="handleSearch"
          />
          <NButton size="small" @click="handleSearch">
            <template #icon>
              <icon-ic-round-search class="text-icon" />
            </template>
            搜索
          </NButton>
          <NButton size="small" @click="handleReset">
            <template #icon>
              <icon-mdi-refresh class="text-icon" />
            </template>
            重置
          </NButton>
          <NButton size="small" ghost type="primary" @click="getData">
            <template #icon>
              <icon-mdi-refresh class="text-icon" :class="{ 'animate-spin': loading }" />
            </template>
            刷新
          </NButton>
          <TableColumnSetting v-model:columns="columnChecks" />
        </NSpace>
      </template>
      <NDataTable
        remote
        :columns="columns"
        :data="data"
        size="small"
        :flex-height="!appStore.isMobile"
        :scroll-x="962"
        :loading="loading"
        :pagination="mobilePagination"
        :row-key="(item: Api.UserManagement.User) => item.userId"
        class="sm:h-full"
      />
      <AssignOrgTagsDialog
        v-model:visible="assignDialogVisible"
        :user="currentUser"
        :org-tag-options="orgTagOptions"
        @submitted="getData"
      />
    </NCard>
  </div>
</template>
