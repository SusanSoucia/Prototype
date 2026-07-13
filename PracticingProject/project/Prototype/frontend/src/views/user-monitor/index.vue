<script setup lang="tsx">
import { NButton, NInput, NInputNumber, NSelect, NTag } from 'naive-ui';
import { useAppStore } from '@/store/modules/app';
import { useTable } from '@/hooks/common/table';
import { fetchGetUserList, fetchGetUsers } from '@/service/api';
import UserOperateDialog from './modules/user-operate-dialog.vue';
import AssignTagsDialog from './modules/assign-tags-dialog.vue';

const appStore = useAppStore();

const roleLabelMap: Record<string, { label: string; type: 'success' | 'warning' | 'info' }> = {
  USER: { label: '用户', type: 'info' },
  LIBRARY_ADMIN: { label: '库管', type: 'warning' },
  ADMIN: { label: '超级管理员', type: 'success' }
};

const roleOptions = [
  { label: '超级管理员', value: 'ADMIN' },
  { label: '库管', value: 'LIBRARY_ADMIN' },
  { label: '用户', value: 'USER' }
];

// 组织标签选项：ADMIN 树下的库管标签 + USER 树下的部门标签
const orgTagOptions = [
  // ADMIN 树 → 库管标签
  { label: '库管A（研发部）', value: 'LIB_A' },
  { label: '库管B（产品部）', value: 'LIB_B' },
  // USER 树 → 部门标签
  { label: '工程部', value: 'USER_A' },
  { label: '搜索团队', value: 'USER_A_SEARCH' },
  { label: '产品部', value: 'USER_B' },
  { label: '管理层', value: 'USER_C' }
];

// useTable provides correctly-typed columns/columnChecks via the fetchGetUserList type chain
const { columns, columnChecks } = useTable({
  apiFn: fetchGetUserList,
  showTotal: false,
  immediate: false,
  columns: () => [
    {
      key: 'userId',
      title: 'ID',
      width: 70,
      align: 'center'
    },
    {
      key: 'username',
      title: '用户名',
      width: 160,
      ellipsis: {
        tooltip: true
      }
    },
    {
      key: 'role',
      title: '角色',
      width: 130,
      render: (row: Api.Admin.User) => {
        const config = roleLabelMap[row.role] || { label: row.role, type: 'info' as const };
        return <NTag type={config.type} size="small">{config.label}</NTag>;
      }
    },
    {
      key: 'orgTags',
      title: '组织标签',
      minWidth: 200,
      ellipsis: {
        tooltip: true
      },
      render: (row: Api.Admin.User) => {
        const tags = row.orgTags || [];
        if (!tags.length) return <span class="text-stone-400 text-xs">暂无标签</span>;
        return (
          <div class="flex flex-wrap gap-1">
            {tags.slice(0, 3).map(tag => (
              <NTag key={tag.tagId} size="tiny" bordered>{tag.name || tag.tagId}</NTag>
            ))}
            {tags.length > 3 ? <NTag size="tiny" bordered>+{tags.length - 3}</NTag> : null}
          </div>
        );
      }
    },
    {
      key: 'primaryOrg',
      title: '主组织',
      width: 120,
      ellipsis: {
        tooltip: true
      },
      render: (row: Api.Admin.User) => row.primaryOrg
        ? <NTag type="primary" size="tiny">{row.primaryOrg}</NTag>
        : <span class="text-stone-400 text-xs">未设置</span>
    },
    {
      key: 'createdAt',
      title: '注册时间',
      width: 110,
      render: (row: Api.Admin.User) => {
        if (!row.createdAt) return <span class="text-stone-400 text-xs">-</span>;
        return dayjs(row.createdAt).format('YYYY-MM-DD');
      }
    },
    {
      key: 'operate',
      title: '操作',
      width: 140,
      render: (row: Api.Admin.User) => (
        <div class="flex gap-2">
          <NButton type="primary" ghost size="small" onClick={() => handleAssignTags(row)}>
            分配标签
          </NButton>
        </div>
      )
    }
  ]
});

// --- Client-side data & filter state ---
const allUsers = ref<Api.Admin.User[]>([]);
const loading = ref(false);

const filterKeyword = ref('');
const filterRole = ref<string | null>(null);
const filterOrgTag = ref<string | null>(null);
const filterUserId = ref<number | null>(null);

const currentPage = ref(1);
const pageSize = ref(10);

const filteredUsers = computed(() => {
  let list = allUsers.value;
  if (filterKeyword.value) {
    const kw = filterKeyword.value.toLowerCase();
    list = list.filter(u => u.username.toLowerCase().includes(kw));
  }
  if (filterRole.value) {
    list = list.filter(u => u.role === filterRole.value);
  }
  if (filterOrgTag.value) {
    list = list.filter(u => u.orgTags.some(t => t.tagId === filterOrgTag.value));
  }
  if (filterUserId.value != null) {
    list = list.filter(u => u.userId === filterUserId.value);
  }
  return list;
});

const pagedUsers = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  return filteredUsers.value.slice(start, start + pageSize.value);
});

function handleFilterChange() {
  currentPage.value = 1;
}

async function loadUsers() {
  loading.value = true;
  try {
    const res = await fetchGetUsers();
    if (res.error) return;
    const payload: any = res.data;
    if (!payload) return;
    // Handle both flat array and wrapped response formats
    const list: Api.Admin.User[] = Array.isArray(payload)
      ? payload
      : (payload.data || payload.content || payload.records || []);
    allUsers.value = list;
    currentPage.value = 1;
  } finally {
    loading.value = false;
  }
}

// Dialog state
const createDialogVisible = ref(false);
const assignTagsVisible = ref(false);
const currentUser = ref<Api.Admin.User | null>(null);

function handleCreate() {
  createDialogVisible.value = true;
}

function handleAssignTags(row: Api.Admin.User) {
  currentUser.value = row;
  assignTagsVisible.value = true;
}

onMounted(() => {
  loadUsers();
});
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="用户管理" :bordered="false" size="small" class="sm:flex-1-hidden card-wrapper">
      <template #header-extra>
        <TableHeaderOperation
          v-model:columns="columnChecks"
          :loading="loading"
          :show-batch-delete="false"
          add-text="创建管理员"
          @add="handleCreate"
          @refresh="loadUsers"
        />
      </template>

      <!-- Filter bar -->
      <div class="flex flex-wrap gap-12px mb-12px">
        <NInput
          v-model:value="filterKeyword"
          placeholder="用户名"
          clearable
          style="width: 160px"
          @input="handleFilterChange"
          @clear="handleFilterChange"
        >
          <template #prefix>
            <icon-ic-round-search class="text-16px" />
          </template>
        </NInput>
        <NInputNumber
          v-model:value="filterUserId"
          placeholder="用户ID"
          clearable
          style="width: 120px"
          @update:value="handleFilterChange"
          @clear="handleFilterChange"
        />
        <NSelect
          v-model:value="filterRole"
          :options="roleOptions"
          placeholder="角色"
          clearable
          style="width: 130px"
          @update:value="handleFilterChange"
        />
        <NSelect
          v-model:value="filterOrgTag"
          :options="orgTagOptions"
          placeholder="组织标签"
          clearable
          style="width: 150px"
          @update:value="handleFilterChange"
        />
      </div>

      <NDataTable
        remote
        :columns="columns"
        :data="pagedUsers"
        size="small"
        :flex-height="!appStore.isMobile"
        :scroll-x="962"
        :loading="loading"
        :pagination="{
          page: currentPage,
          pageSize: pageSize,
          itemCount: filteredUsers.length,
          showSizePicker: true,
          pageSizes: [5, 10, 20, 50],
          prefix: () => `共 ${filteredUsers.length} 条`,
          onChange: (p: number) => { currentPage = p; },
          onUpdatePageSize: (s: number) => { pageSize = s; currentPage = 1; }
        }"
        :row-key="(item: Api.Admin.User) => item.userId"
        class="sm:h-full"
      />
      <UserOperateDialog
        v-model:visible="createDialogVisible"
        operate-type="create"
        @submitted="loadUsers"
      />
      <AssignTagsDialog
        v-model:visible="assignTagsVisible"
        :user="currentUser"
        @submitted="loadUsers"
      />
    </NCard>
  </div>
</template>
