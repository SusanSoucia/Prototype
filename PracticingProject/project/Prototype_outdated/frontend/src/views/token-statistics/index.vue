<script setup lang="tsx">
import { ref, computed, onMounted } from 'vue';
import { NCard, NDataTable, NSpace } from 'naive-ui';
import { request } from '@/service/request';

defineOptions({
  name: 'TokenStatistics'
});

const loading = ref(false);
const data = ref<Api.TokenStatistics.DepartmentUsage[]>([]);

function flattenData(list: Api.TokenStatistics.DepartmentUsage[], depth = 0): any[] {
  const result: any[] = [];
  list.forEach((item) => {
    result.push({
      key: item.tagId,
      label: item.name,
      tagId: item.tagId,
      depth,
      lastDay: item.lastDay,
      lastWeek: item.lastWeek,
      lastMonth: item.lastMonth,
      lastYear: item.lastYear,
      total: item.total
    });
    if (item.children?.length) {
      result.push(...flattenData(item.children, depth + 1));
    }
  });
  return result;
}

const tableData = computed(() => {
  return flattenData(data.value);
});

function formatNumber(num: number): string {
  if (num >= 1000000) {
    return (num / 1000000).toFixed(2) + 'M';
  }
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'K';
  }
  return num.toString();
}

const columns = [
  {
    title: '部门名称',
    key: 'label',
    width: 220,
    render: (row: any) => {
      const paddingLeft = row.depth * 24;
      return <span style={{ paddingLeft: `${paddingLeft}px`, display: 'inline-block' }}>{row.label}</span>;
    }
  },
  {
    title: '过去一天',
    key: 'lastDay',
    width: 120,
    align: 'right',
    render: (row: any) => formatNumber(row.lastDay)
  },
  {
    title: '过去一周',
    key: 'lastWeek',
    width: 120,
    align: 'right',
    render: (row: any) => formatNumber(row.lastWeek)
  },
  {
    title: '过去一个月',
    key: 'lastMonth',
    width: 130,
    align: 'right',
    render: (row: any) => formatNumber(row.lastMonth)
  },
  {
    title: '过去一年',
    key: 'lastYear',
    width: 120,
    align: 'right',
    render: (row: any) => formatNumber(row.lastYear)
  },
  {
    title: '累计总量',
    key: 'total',
    width: 120,
    align: 'right',
    render: (row: any) => formatNumber(row.total)
  }
];

async function getData() {
  loading.value = true;
  const { error, data: responseData } = await request<Api.TokenStatistics.DepartmentUsage[]>({
    url: '/token-statistics/department'
  });
  if (!error) {
    data.value = responseData;
  }
  loading.value = false;
}

onMounted(() => {
  getData();
});
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden">
    <NCard title="Token 使用量统计" :bordered="false" size="small" class="card-wrapper">
      <NSpace vertical class="w-full">
        <NDataTable
          :columns="columns"
          :data="tableData"
          :loading="loading"
          size="small"
          :scroll-x="800"
          :pagination="false"
          :row-key="(row) => row.key"
        />
      </NSpace>
    </NCard>
  </div>
</template>
