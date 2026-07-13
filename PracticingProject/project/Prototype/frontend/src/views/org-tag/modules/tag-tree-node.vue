<script setup lang="ts">
import { ref } from 'vue';
import { NButton, NPopconfirm, NTag } from 'naive-ui';

defineOptions({ name: 'TagTreeNode' });

const props = defineProps<{
  node: Api.OrgTag.Item;
  depth: number;
  isRoot: boolean;
}>();

const emit = defineEmits<{
  addChild: [node: Api.OrgTag.Item];
  edit: [node: Api.OrgTag.Item];
  delete: [tagId: string];
}>();

const expanded = ref(false);

function toggleExpand() {
  expanded.value = !expanded.value;
}

const hasChildren = computed(() => props.node.children && props.node.children.length > 0);
</script>

<template>
  <div>
    <div
      class="flex items-center gap-8px py-10px px-12px rounded-8px hover:bg-stone-50 transition-colors"
      :style="{ paddingLeft: `${12 + depth * 24}px` }"
    >
      <!-- 展开/折叠箭头 -->
      <span
        class="shrink-0 w-20px h-20px flex items-center justify-center cursor-pointer text-stone-400 hover:text-stone-700 select-none"
        :class="{ invisible: !hasChildren }"
        @click="toggleExpand"
      >
        {{ expanded ? '▾' : '▸' }}
      </span>

      <!-- 标签名 -->
      <span class="font-500 text-14px min-w-120px" :class="{ 'text-primary font-600': isRoot }">
        {{ node.name }}
        <NTag v-if="isRoot" size="tiny" :type="node.tagId === 'ADMIN' ? 'error' : 'info'" class="ml-8px" :bordered="false">
          {{ node.tagId === 'ADMIN' ? '超管' : '用户' }}
        </NTag>
      </span>

      <!-- 描述 -->
      <span class="text-13px text-stone-500 flex-1 truncate">{{ node.description || '—' }}</span>

      <!-- 操作按钮 -->
      <div class="flex gap-6px shrink-0">
        <NButton size="tiny" ghost type="success" @click="emit('addChild', node)">
          新增下级
        </NButton>
        <NButton size="tiny" ghost type="primary" @click="emit('edit', node)">
          编辑
        </NButton>
        <NPopconfirm v-if="!isRoot" @positive-click="emit('delete', node.tagId)">
          <template #default>
            确认删除标签「{{ node.name }}」及其所有子标签？
          </template>
          <template #trigger>
            <NButton size="tiny" ghost type="error">删除</NButton>
          </template>
        </NPopconfirm>
      </div>
    </div>

    <!-- 递归子节点 -->
    <div v-if="hasChildren && expanded">
      <TagTreeNode
        v-for="child in node.children"
        :key="child.tagId"
        :node="child"
        :depth="depth + 1"
        :is-root="false"
        @add-child="emit('addChild', $event)"
        @edit="emit('edit', $event)"
        @delete="emit('delete', $event)"
      />
    </div>
  </div>
</template>
