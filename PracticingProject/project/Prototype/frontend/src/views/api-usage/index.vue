<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { request } from '@/service/request';
import LookForward from '@/components/custom/look-forward.vue';

interface RateLimitSetting {
  id: number;
  name: string;
  limitType: string;
  maxRequests: number;
  windowSeconds: number;
  enabled: boolean;
}

interface ModelProvider {
  scope: string;
  provider: string;
  model: string;
  baseUrl: string;
}

const rateLimits = ref<RateLimitSetting[]>([]);
const modelProviders = ref<ModelProvider[]>([]);
const loading = ref(false);

onMounted(async () => {
  loading.value = true;
  try {
    const [rateRes, modelRes] = await Promise.all([
      request<RateLimitSetting[]>({ url: '/admin/rate-limits' }),
      request<ModelProvider[]>({ url: '/admin/model-providers' })
    ]);
    if (!rateRes.error) {
      const d = rateRes.data;
      rateLimits.value = Array.isArray(d) ? d : (d as any)?.data || [];
    }
    if (!modelRes.error) {
      const d = modelRes.data;
      modelProviders.value = Array.isArray(d) ? d : (d as any)?.data || [];
    }
  } catch {
    // ignore fetch errors
  }
  loading.value = false;
});
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="限流配置" :bordered="false" size="small">
      <NSpin :show="loading">
        <NDataTable
          v-if="rateLimits.length > 0"
          :columns="[
            { key: 'name', title: '名称' },
            { key: 'limitType', title: '限制类型' },
            { key: 'maxRequests', title: '最大请求数' },
            { key: 'windowSeconds', title: '窗口 (秒)' },
            {
              key: 'enabled',
              title: '状态',
              render: (row: RateLimitSetting) => row.enabled ? '启用' : '禁用'
            }
          ]"
          :data="rateLimits"
          size="small"
        />
        <LookForward v-else-if="!loading">
          <h3 class="text-24px text-primary font-500">API 用量统计</h3>
          <p class="text-stone-400 text-sm mt-2">限流配置和模型提供商数据将在这里展示</p>
        </LookForward>
      </NSpin>
    </NCard>
  </div>
</template>
