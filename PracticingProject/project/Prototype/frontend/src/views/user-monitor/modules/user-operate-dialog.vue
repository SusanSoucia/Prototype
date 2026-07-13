<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { NSelect } from 'naive-ui';
import { useFormRules, useNaiveForm } from '@/hooks/common/form';
import { fetchCreateAdminUser } from '@/service/api';

defineOptions({
  name: 'UserOperateDialog'
});

const props = defineProps<{
  operateType: 'create';
}>();

const emit = defineEmits<{ submitted: [] }>();

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);
const { formRef, validate, restoreValidation } = useNaiveForm();
const { defaultRequiredRule } = useFormRules();

const title = '创建管理员用户';

const roleOptions = [
  { label: '超级管理员 (ADMIN)', value: 'ADMIN' },
  { label: '库管 (LIBRARY_ADMIN)', value: 'LIBRARY_ADMIN' }
];

const model = ref({
  username: '',
  password: '',
  role: 'ADMIN' as string
});

const rules = ref({
  username: [defaultRequiredRule],
  password: [defaultRequiredRule],
  role: [defaultRequiredRule]
});

function close() {
  visible.value = false;
}

async function handleSubmit() {
  await validate();
  loading.value = true;

  const { error } = await fetchCreateAdminUser({
    username: model.value.username,
    password: model.value.password,
    role: model.value.role
  });

  if (!error) {
    window.$message?.success('创建成功');
    close();
    emit('submitted');
  } else {
    window.$message?.error('创建失败，请重试');
  }

  loading.value = false;
}

watch(visible, () => {
  if (visible.value) {
    model.value = { username: '', password: '', role: 'ADMIN' };
    restoreValidation();
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
    class="w-460px!"
    @positive-click="handleSubmit"
  >
    <NForm ref="formRef" :model="model" :rules="rules" label-placement="left" :label-width="80" mt-10>
      <NFormItem label="用户名" path="username">
        <NInput v-model:value="model.username" placeholder="请输入用户名" maxlength="60" />
      </NFormItem>
      <NFormItem label="密码" path="password">
        <NInput v-model:value="model.password" type="password" placeholder="请输入密码" maxlength="60" />
      </NFormItem>
      <NFormItem label="角色" path="role">
        <NSelect v-model:value="model.role" :options="roleOptions" placeholder="请选择角色" />
      </NFormItem>
    </NForm>
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" @click="handleSubmit">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>
