<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import type { TreeOption } from 'naive-ui';
import { NTag } from 'naive-ui';
import { fetchAssignOrgTagsToUser } from '@/service/api';
import { fetchGetOrgTagTree } from '@/service/api/org-tag';

defineOptions({
  name: 'AssignTagsDialog'
});

const props = defineProps<{
  user: Api.Admin.User | null;
}>();

const emit = defineEmits<{ submitted: [] }>();

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);
const submitting = ref(false);

interface TagNode {
  tagId: string;
  name: string;
  description: string;
  parentTag: string | null;
  children?: TagNode[];
}

const treeData = ref<TreeOption[]>([]);
const checkedKeys = ref<string[]>([]);

/** Convert org tag tree to naive-ui NTree options */
function buildTreeOptions(tags: TagNode[]): TreeOption[] {
  return tags.map(tag => ({
    key: tag.tagId,
    label: tag.name,
    disabled: false,
    children: tag.children?.length ? buildTreeOptions(tag.children) : undefined
  }));
}

/** Collect all tag IDs in a subtree (including the root) */
function collectAllTagIds(nodes: TagNode[]): string[] {
  const ids: string[] = [];
  function walk(list: TagNode[]) {
    for (const node of list) {
      ids.push(node.tagId);
      if (node.children?.length) walk(node.children);
    }
  }
  walk(nodes);
  return ids;
}

const allTagIds = ref<string[]>([]);

async function loadTags() {
  const { data, error } = await fetchGetOrgTagTree();
  if (!error && data) {
    const items: TagNode[] = Array.isArray(data)
      ? (data as unknown as TagNode[])
      : ((data as any)?.data || (data as any)?.content || []);
    treeData.value = buildTreeOptions(items);
    allTagIds.value = collectAllTagIds(items);
  }
}

/** Extract org tag IDs from user's orgTags array ({tagId, name} objects from backend) */
function getUserCurrentTagIds(): string[] {
  if (!props.user) return [];
  const raw = props.user.orgTags;
  if (!raw || !Array.isArray(raw)) return [];
  return raw.map(t => t.tagId).filter(Boolean);
}

/** Currently assigned tags that exist in the tree */
const currentTags = computed(() => {
  const userTags = getUserCurrentTagIds();
  return userTags.filter(t => allTagIds.value.includes(t));
});

/** Tags the user has that are NOT in the tree (orphaned / deleted tags) */
const orphanedTags = computed(() => {
  const userTags = getUserCurrentTagIds();
  return userTags.filter(t => !allTagIds.value.includes(t));
});

/** Add a tag by ID (if not already checked) */
function addTag(tagId: string) {
  if (!checkedKeys.value.includes(tagId)) {
    checkedKeys.value.push(tagId);
  }
}

/** Remove a single tag */
function removeTag(tagId: string) {
  checkedKeys.value = checkedKeys.value.filter(k => k !== tagId);
}

/** Remove all tags (clear assignment) */
function removeAllTags() {
  checkedKeys.value = [];
}

/** Whether the user has any tags currently */
const hasChanges = computed(() => {
  const original = getUserCurrentTagIds().sort().join(',');
  const current = checkedKeys.value.sort().join(',');
  return original !== current;
});

async function handleSubmit() {
  if (!props.user) return;
  submitting.value = true;

  const { error } = await fetchAssignOrgTagsToUser(props.user.userId, checkedKeys.value);

  if (!error) {
    window.$message?.success('组织标签分配成功');
    close();
    emit('submitted');
  } else {
    window.$message?.error('组织标签分配失败，请重试');
  }

  submitting.value = false;
}

function close() {
  visible.value = false;
}

watch(visible, async (val) => {
  if (val) {
    loading.value = true;
    await loadTags();
    // Pre-populate with user's current tags
    checkedKeys.value = [...getUserCurrentTagIds()];
    loading.value = false;
  }
});
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="分配组织标签"
    :show-icon="false"
    :mask-closable="false"
    :positive-button-props="{ loading: submitting, disabled: !hasChanges }"
    class="w-640px!"
    @positive-click="handleSubmit"
  >
    <!-- User info header -->
    <div v-if="user" class="mb-4 flex items-center gap-3">
      <span class="text-sm text-stone-500">用户</span>
      <strong class="text-stone-800">{{ user.username }}</strong>
      <NTag :bordered="false" size="small" type="info">
        {{ user.role === 'ADMIN' ? '超级管理员' : user.role === 'LIBRARY_ADMIN' ? '库管' : '用户' }}
      </NTag>
    </div>

    <NSpin :show="loading">
      <!-- Currently assigned tags (quick remove) -->
      <div v-if="checkedKeys.length > 0" class="mb-4">
        <div class="mb-2 flex items-center justify-between">
          <span class="text-xs font-500 text-stone-500">
            已分配 {{ checkedKeys.length }} 个标签
          </span>
          <NButton text size="tiny" type="warning" @click="removeAllTags">清除全部</NButton>
        </div>
        <div class="flex flex-wrap gap-1.5">
          <NTag
            v-for="key in checkedKeys"
            :key="key"
            closable
            size="small"
            type="success"
            @close="removeTag(key)"
          >
            {{ key }}
          </NTag>
        </div>
      </div>
      <div v-else class="mb-4">
        <span class="text-xs text-stone-400">该用户暂无组织标签</span>
      </div>

      <!-- Orphaned tags warning -->
      <div v-if="orphanedTags.length > 0" class="mb-4">
        <span class="text-xs text-amber-600">
          以下标签已不存在于标签树中，提交后将自动移除：{{ orphanedTags.join(', ') }}
        </span>
      </div>

      <!-- Tag tree -->
      <div class="mb-2 text-xs font-500 text-stone-500">选择组织标签</div>
      <div v-if="treeData.length > 0" class="max-h-360px overflow-y-auto rounded-lg border border-stone-200 p-2">
        <NTree
          v-model:checked-keys="checkedKeys"
          :data="treeData"
          checkable
          block-line
          :default-expand-all="false"
          default-expand-level="1"
          virtual-scroll
        />
      </div>
      <div v-else class="py-8 text-center text-sm text-stone-400">
        暂无组织标签数据
      </div>
    </NSpin>

    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" :loading="submitting" :disabled="!hasChanges" @click="handleSubmit">
          保存
        </NButton>
      </NSpace>
    </template>
  </NModal>
</template>
