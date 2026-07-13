<script setup lang="tsx">
import { NButton, NPopconfirm } from 'naive-ui';
import { useAppStore } from '@/store/modules/app';
import { useTable, useTableOperate } from '@/hooks/common/table';
import { request } from '@/service/request';
import { fetchGetOrgTagList } from '@/service/api/org-tag';
import OrgTagOperateDialog from './modules/org-tag-operate-dialog.vue';

const appStore = useAppStore();

const { columns, columnChecks, data, loading, getData, mobilePagination } = useTable({
  apiFn: fetchGetOrgTagList,
  showTotal: true,
  columns: () => [
    {
      key: 'name',
      title: '标签名称',
      width: 300,
      ellipsis: {
        tooltip: true
      }
    },
    {
      key: 'description',
      title: '描述',
      minWidth: 200,
      ellipsis: {
        tooltip: true
      }
    },

    {
      key: 'operate',
      title: '操作',
      width: 240,
      render: (row: Api.OrgTag.Item) => (
        <div class="flex gap-2">
          <NButton type="success" ghost size="small" onClick={() => handleAddChild(row)}>
            新增下级
          </NButton>
          <NButton type="primary" ghost size="small" onClick={() => handleEdit(row)}>
            编辑
          </NButton>
          <NPopconfirm onPositiveClick={() => handleDelete(row.tagId)}>
            {{
              default: () => '确认删除当前标签吗？',
              trigger: () => (
                <NButton type="error" ghost size="small">
                  删除
                </NButton>
              )
            }}
          </NPopconfirm>
        </div>
      )
    }
  ]
});

const {
  dialogVisible,
  operateType,
  editingData,
  handleAdd,
  handleAddChild,
  handleEdit,
  onDeleted
} = useTableOperate<Api.OrgTag.Item>(getData);

async function handleDelete(tagId: string) {
  const { error } = await request({ url: `/admin/org-tags/${tagId}`, method: 'DELETE' });
  if (!error) {
    onDeleted();
  }
}
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="组织标签" :bordered="false" size="small" class="sm:flex-1-hidden card-wrapper">
      <template #header-extra>
        <TableHeaderOperation v-model:columns="columnChecks" :loading="loading" :show-batch-delete="false" @add="handleAdd" @refresh="getData" />
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
        :row-key="(item: Api.OrgTag.Item) => item.tagId"
        class="sm:h-full"
      />
      <OrgTagOperateDialog
        v-model:visible="dialogVisible"
        :operate-type="operateType"
        :row-data="editingData!"
        :data="data"
        @submitted="getData"
      />
    </NCard>
  </div>
</template>
