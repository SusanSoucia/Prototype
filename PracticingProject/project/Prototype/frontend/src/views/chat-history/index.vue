<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { NButton, NEmpty, NInput, NDatePicker, NTag, NSpin, NCard } from 'naive-ui';
import { request } from '@/service/request';
import { useAuthStore } from '@/store/modules/auth';
import dayjs from 'dayjs';

const authStore = useAuthStore();
const sessions = ref<Api.Chat.ConversationSession[]>([]);
const messages = ref<Api.Chat.Message[]>([]);
const selectedSessionId = ref<string>('');
const sessionsLoading = ref(false);
const messagesLoading = ref(false);
const searchKeyword = ref('');
const dateRange = ref<[number, number] | null>(null);

const filteredSessions = computed(() => {
  let result = sessions.value;
  if (searchKeyword.value) {
    const kw = searchKeyword.value.toLowerCase();
    result = result.filter(s => s.title.toLowerCase().includes(kw));
  }
  if (dateRange.value && dateRange.value.length === 2) {
    const [start, end] = dateRange.value;
    result = result.filter(s => {
      const ts = new Date(s.createdAt).getTime();
      return ts >= start && ts <= end;
    });
  }
  return result;
});

async function fetchSessions() {
  sessionsLoading.value = true;
  try {
    const { data, error } = await request<ConversationSession[]>({
      url: '/users/conversations',
      method: 'GET'
    });
    if (!error && data) {
      sessions.value = data;
    }
  } finally {
    sessionsLoading.value = false;
  }
}

async function selectSession(session: ConversationSession) {
  selectedSessionId.value = session.id;
  messagesLoading.value = true;
  try {
    const { data, error } = await request<Message[]>({
      url: '/users/conversation',
      method: 'GET',
      params: { conversationId: session.conversationId || session.id }
    });
    if (!error && data) {
      messages.value = Array.isArray(data) ? data : [];
    } else {
      messages.value = [];
    }
  } finally {
    messagesLoading.value = false;
  }
}

function formatTime(dateStr: string) {
  if (!dateStr) return '';
  return dayjs(dateStr).format('YYYY-MM-DD HH:mm');
}

onMounted(() => {
  fetchSessions();
});
</script>

<template>
  <div class="h-full flex overflow-hidden bg-layout p-4 gap-4">
    <!-- Session List Panel -->
    <div class="w-320px shrink-0 flex flex-col rounded-2xl bg-white shadow-sm ring-1 ring-#0f172a0a dark:bg-#1c1c1c dark:ring-#ffffff0f">
      <div class="p-4 pb-2">
        <h2 class="text-lg font-semibold text-#1f1f1f dark:text-#e0e0e0">
          {{ $t('route.chat-history') }}
        </h2>
      </div>
      <div class="px-4 pb-3 space-y-2">
        <NInput
          v-model:value="searchKeyword"
          :placeholder="$t('common.keywordSearch')"
          clearable
          size="small"
        />
        <NDatePicker
          v-model:value="dateRange"
          type="daterange"
          size="small"
          clearable
          class="w-full"
        />
      </div>
      <div class="flex-1 overflow-y-auto px-2">
        <NSpin :show="sessionsLoading">
          <div v-if="filteredSessions.length === 0 && !sessionsLoading" class="flex-center h-200px">
            <NEmpty :description="$t('common.noData')" />
          </div>
          <div
            v-for="session in filteredSessions"
            :key="session.id"
            class="mx-2 mb-1 cursor-pointer rounded-xl px-3 py-2.5 transition-all duration-150 hover:bg-#f5f5f5 dark:hover:bg-#262626"
            :class="{ 'bg-#e8f0fe dark:bg-#1a2740!': selectedSessionId === session.id }"
            @click="selectSession(session)"
          >
            <div class="truncate text-14px font-medium text-#333 dark:text-#ccc">
              {{ session.title || '未命名会话' }}
            </div>
            <div class="mt-1 flex items-center gap-2">
              <NTag :type="session.status === 'ACTIVE' ? 'success' : 'default'" size="tiny" :bordered="false">
                {{ session.status === 'ACTIVE' ? '活跃' : '已归档' }}
              </NTag>
              <span class="text-12px text-#999">{{ formatTime(session.updatedAt || session.createdAt) }}</span>
            </div>
          </div>
        </NSpin>
      </div>
    </div>

    <!-- Message Detail Panel -->
    <div class="flex-1 min-w-0 rounded-2xl bg-white shadow-sm ring-1 ring-#0f172a0a dark:bg-#1c1c1c dark:ring-#ffffff0f">
      <div v-if="!selectedSessionId" class="h-full flex-center">
        <NEmpty description="请选择一个会话查看详情" />
      </div>
      <div v-else class="h-full flex flex-col">
        <div class="p-4 pb-2 border-b border-#f0f0f0 dark:border-#333">
          <h3 class="text-16px font-semibold text-#1f1f1f dark:text-#e0e0e0">
            {{ filteredSessions.find(s => s.id === selectedSessionId)?.title || '对话详情' }}
          </h3>
        </div>
        <div class="flex-1 overflow-y-auto p-4">
          <NSpin :show="messagesLoading">
            <div v-if="messages.length === 0 && !messagesLoading" class="flex-center h-200px">
              <NEmpty :description="$t('common.noData')" />
            </div>
            <div v-for="(msg, idx) in messages" :key="idx" class="mb-4">
              <div class="mb-1 text-12px font-medium" :class="msg.role === 'user' ? 'text-[rgb(var(--primary-color))]' : 'text-#18a058'">
                {{ msg.role === 'user' ? authStore.userInfo.userName || '用户' : 'AI 助手' }}
                <span class="ml-2 font-normal text-#999">{{ formatTime(msg.createdAt) }}</span>
              </div>
              <NCard size="small" :bordered="true" class="message-card">
                <div class="prose prose-sm max-w-none whitespace-pre-wrap text-14px leading-relaxed" v-text="msg.content || '(空消息)'" />
              </NCard>
            </div>
          </NSpin>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.flex-center {
  @apply flex items-center justify-center;
}
.message-card {
  border-radius: 12px;
}
</style>
