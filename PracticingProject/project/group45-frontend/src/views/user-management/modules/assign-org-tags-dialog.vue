<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { fetchAssignOrgTagsToUser } from '@/service/api/user-management';

defineOptions({
  name: 'AssignOrgTagsDialog'
});

const props = defineProps<{
  user: Api.UserManagement.User | null;
  orgTagOptions: { label: string; value: string }[];
}>();

const emit = defineEmits<{ submitted: [] }>();

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);
const selectedTags = ref<string[]>([]);

const title = computed(() => `分配标签 — ${props.user?.username || ''}`);

function close() {
  visible.value = false;
}

async function handleSubmit() {
  if (!props.user?.userId) return;
  loading.value = true;

  const { error } = await fetchAssignOrgTagsToUser(props.user.userId, selectedTags.value);
  if (!error) {
    window.$message?.success('标签分配成功');
    close();
    emit('submitted');
  }
  loading.value = false;
}

watch(visible, () => {
  if (visible.value && props.user) {
    // backend orgTags are [{tagId, name}], extract tagId strings
    selectedTags.value = (props.user.orgTags || []).map(t => t.tagId);
  }
});
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    :title="title"
    :show-icon="false"
    :mask-closable="false"
    @positive-click="handleSubmit"
    @negative-click="close"
  >
    <NSelect
      v-model:value="selectedTags"
      :options="props.orgTagOptions"
      multiple
      placeholder="请选择组织标签"
      clearable
      :loading="!props.orgTagOptions.length"
    />
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" :loading="loading" @click="handleSubmit">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>
