<script setup lang="tsx">
import { onMounted, watch } from 'vue';
import { NTag, NButton, NCard, NSpace, NDatePicker, NInput } from 'naive-ui';
import type { DataTableColumns, PaginationProps } from 'naive-ui';
import { useAppStore } from '@/store/modules/app';
import { useAuthStore } from '@/store/modules/auth';
import { fetchChatHistory } from '@/service/api/chat-history';
import type { ChatMessage } from '@/service/api/chat-history';

const appStore = useAppStore();
const authStore = useAuthStore();

// ---- filter state ----
const startDate = ref<number | null>(null);
const endDate = ref<number | null>(null);
const filterUsername = ref('');
const filterConversationId = ref('');

// ---- table state ----
const data = ref<ChatMessage[]>([]);
const loading = ref(false);
const allData = ref<ChatMessage[]>([]);

// ---- apply frontend filters (username + conversationId) ----
function applyFrontendFilters() {
  let filtered = [...allData.value];

  console.log('[chat-history] allData sample:', allData.value.slice(0, 2).map(m => ({ role: m.role, username: m.username, conversationId: m.conversationId })));

  if (filterUsername.value.trim()) {
    const keyword = filterUsername.value.trim().toLowerCase();
    filtered = filtered.filter(msg => (msg.username || '').toLowerCase().includes(keyword));
  }

  if (filterConversationId.value.trim()) {
    const keyword = filterConversationId.value.trim().toLowerCase();
    filtered = filtered.filter(msg => (msg.conversationId || '').toLowerCase().includes(keyword));
  }

  data.value = filtered;
  pagination.itemCount = data.value.length;
  pagination.page = 1;
}

// ---- pagination ----
const pagination = reactive<PaginationProps>({
  page: 1,
  pageSize: 10,
  showSizePicker: true,
  itemCount: 0,
  pageSizes: [10, 15, 20, 25, 30],
  prefix: () => `共 ${pagination.itemCount} 条`,
  onUpdatePage: (page: number) => {
    pagination.page = page;
  },
  onUpdatePageSize: (pageSize: number) => {
    pagination.pageSize = pageSize;
    pagination.page = 1;
  }
});

// ---- computed paginated data ----
const pagedData = computed(() => {
  const start = (pagination.page! - 1) * pagination.pageSize!;
  const end = start + pagination.pageSize!;
  return data.value.slice(start, end);
});

// ---- columns ----
const columns = computed<DataTableColumns<ChatMessage>>(() => [
  {
    key: 'index',
    title: '序号',
    width: 70,
    align: 'center',
    render: (_row, index) => {
      return (pagination.page! - 1) * pagination.pageSize! + index + 1;
    }
  },
  {
    key: 'role',
    title: '角色',
    width: 90,
    align: 'center',
    render: row => {
      const isUser = row.role === 'user';
      return (
        <NTag type={isUser ? 'info' : 'success'} size="small">
          {isUser ? '用户' : '助手'}
        </NTag>
      );
    }
  },
  {
    key: 'content',
    title: '内容',
    minWidth: 240,
    ellipsis: { tooltip: true },
    render: row => row.content || '—'
  },
  {
    key: 'timestamp',
    title: '时间',
    width: 180,
    ellipsis: { tooltip: true },
    render: row => row.timestamp || '—'
  },
  {
    key: 'conversationId',
    title: '会话ID',
    width: 200,
    ellipsis: { tooltip: true },
    render: row => row.conversationId || '—'
  },
  ...(authStore.isAdmin
    ? [{
        key: 'username' as const,
        title: '用户',
        width: 110,
        ellipsis: { tooltip: true },
        render: (row: ChatMessage) => row.username || '—'
      }]
    : [])
]);

// ---- re-filter when admin filter inputs change (no re-fetch) ----
watch([filterUsername, filterConversationId], () => {
  if (allData.value.length > 0) {
    applyFrontendFilters();
  }
});

// ---- actions ----
async function handleSearch() {
  const params: { start_date?: string; end_date?: string } = {};

  if (startDate.value) {
    params.start_date = formatTimestamp(startDate.value);
  }
  if (endDate.value) {
    params.end_date = formatTimestamp(endDate.value);
  }

  loading.value = true;
  try {
    const result = await fetchChatHistory(params);
    const rawData = result.data;
    // Handle case where request interceptor already unwrapped the data
    if (Array.isArray(rawData)) {
      allData.value = rawData;
    } else if (rawData && Array.isArray((rawData as any).data)) {
      allData.value = (rawData as any).data;
    } else {
      allData.value = [];
    }
    applyFrontendFilters();
  } catch {
    allData.value = [];
    data.value = [];
    pagination.itemCount = 0;
  } finally {
    loading.value = false;
  }
}

function handleReset() {
  startDate.value = null;
  endDate.value = null;
  filterUsername.value = '';
  filterConversationId.value = '';
  allData.value = [];
  data.value = [];
  pagination.itemCount = 0;
  pagination.page = 1;
}

function formatTimestamp(ts: number): string {
  const d = new Date(ts);
  const pad = (n: number) => String(n).padStart(2, '0');
  const year = d.getFullYear();
  const month = pad(d.getMonth() + 1);
  const day = pad(d.getDate());
  const hours = pad(d.getHours());
  const minutes = pad(d.getMinutes());
  const seconds = pad(d.getSeconds());
  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}`;
}

// ---- auto-load on mount ----
onMounted(() => {
  handleSearch();
});
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="聊天记录" :bordered="false" size="small" class="sm:flex-1-hidden card-wrapper">
      <template #header-extra>
        <NSpace align="center" wrap>
          <NDatePicker
            v-model:value="startDate"
            type="datetime"
            clearable
            placeholder="起始时间"
            size="small"
            style="width: 190px"
          />
          <span class="text-14px text-gray-400">—</span>
          <NDatePicker
            v-model:value="endDate"
            type="datetime"
            clearable
            placeholder="结束时间"
            size="small"
            style="width: 190px"
          />
          <template v-if="authStore.isAdmin">
            <NInput
              v-model:value="filterConversationId"
              placeholder="会话ID"
              clearable
              size="small"
              style="width: 180px"
              @keyup.enter="handleSearch"
            />
            <NInput
              v-model:value="filterUsername"
              placeholder="用户ID"
              clearable
              size="small"
              style="width: 140px"
              @keyup.enter="handleSearch"
            />
          </template>
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
        </NSpace>
      </template>
      <NDataTable
        :columns="columns"
        :data="pagedData"
        size="small"
        :flex-height="!appStore.isMobile"
        :scroll-x="880"
        :loading="loading"
        :pagination="pagination"
        :row-key="(_row: ChatMessage, index: number) => String(index)"
        class="sm:h-full"
      />
    </NCard>
  </div>
</template>
