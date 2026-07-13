<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { NButton, NCard, NSpin, NEmpty } from 'naive-ui';
import { fetchGetOrgTagTree } from '@/service/api/org-tag';
import { request } from '@/service/request';
import OrgTagOperateDialog from './modules/org-tag-operate-dialog.vue';
import TagTreeNode from './modules/tag-tree-node.vue';

// ==================== 数据 ====================

const tagTree = ref<Api.OrgTag.Item[]>([]);
const loading = ref(false);

async function fetchTree() {
  loading.value = true;
  const { error, data } = await fetchGetOrgTagTree();
  if (!error && data) {
    const items = Array.isArray(data) ? data : ((data as any)?.data || []);
    tagTree.value = (Array.isArray(items) ? items : []) as Api.OrgTag.Item[];
  }
  loading.value = false;
}

onMounted(() => fetchTree());

// ==================== 增/删/改弹窗 ====================

const dialogVisible = ref(false);
const operateType = ref<NaiveUI.TableOperateType>('add');
const editingData = ref<Api.OrgTag.Item | null>(null);
const allFlatData = ref<Api.OrgTag.Item[]>([]);

function flattenTree(items: Api.OrgTag.Item[]): Api.OrgTag.Item[] {
  const result: Api.OrgTag.Item[] = [];
  for (const item of items) {
    result.push(item);
    if (item.children?.length) result.push(...flattenTree(item.children));
  }
  return result;
}

function openDialog(type: NaiveUI.TableOperateType, row?: Api.OrgTag.Item) {
  operateType.value = type;
  editingData.value = row || null;
  allFlatData.value = flattenTree(tagTree.value);
  dialogVisible.value = true;
}

function handleAddChild(node: Api.OrgTag.Item) {
  openDialog('addChild', node);
}

function handleEdit(node: Api.OrgTag.Item) {
  openDialog('edit', node);
}

async function handleDelete(tagId: string) {
  const { error } = await request({ url: `/admin/org-tags/${tagId}`, method: 'DELETE' });
  if (!error) {
    window.$message?.success('删除成功');
    fetchTree();
  }
}

function onSubmitted() {
  fetchTree();
}
</script>

<template>
  <div class="flex-col-stretch gap-16px overflow-hidden <sm:overflow-auto">
    <NCard title="组织标签" :bordered="false" size="small" class="sm:flex-1-hidden card-wrapper">
      <template #header-extra>
        <div class="flex items-center gap-8px">
          <NButton size="small" @click="fetchTree">
            刷新
          </NButton>
        </div>
      </template>

      <NSpin :show="loading">
        <NEmpty v-if="!loading && tagTree.length === 0" description="暂无标签数据" class="py-60px" />
        <div v-else class="flex flex-col">
          <TagTreeNode
            v-for="node in tagTree"
            :key="node.tagId"
            :node="node"
            :depth="0"
            :is-root="true"
            @add-child="handleAddChild"
            @edit="handleEdit"
            @delete="handleDelete"
          />
        </div>
      </NSpin>
    </NCard>

    <OrgTagOperateDialog
      v-model:visible="dialogVisible"
      :operate-type="operateType"
      :row-data="editingData!"
      :data="allFlatData"
      @submitted="onSubmitted"
    />
  </div>
</template>
