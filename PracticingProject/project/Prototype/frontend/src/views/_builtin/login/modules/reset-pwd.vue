<script setup lang="ts">
import { computed, reactive } from 'vue';
import { useRouterPush } from '@/hooks/common/router';
import { useFormRules, useNaiveForm } from '@/hooks/common/form';
import { useAuthStore } from '@/store/modules/auth';
import { $t } from '@/locales';

defineOptions({
  name: 'ResetPwd'
});

const { toggleLoginModule } = useRouterPush();
const { formRef, validate } = useNaiveForm();
const authStore = useAuthStore();

interface FormModel {
  userName: string;
  oldPassword: string;
  newPassword: string;
}

const model: FormModel = reactive({
  userName: '',
  oldPassword: '',
  newPassword: ''
});

const rules = computed<Record<keyof FormModel, App.Global.FormRule[]>>(() => {
  const { formRules } = useFormRules();

  return {
    userName: formRules.userName,
    oldPassword: formRules.pwd,
    newPassword: formRules.pwd
  };
});

async function handleSubmit() {
  await validate();
  await authStore.changePassword(model.userName, model.oldPassword, model.newPassword);
}
</script>

<template>
  <NForm ref="formRef" :model="model" :rules="rules" size="large" :show-label="false" @keyup.enter="handleSubmit">
    <NFormItem path="userName">
      <NInput v-model:value="model.userName" :placeholder="$t('page.login.common.userNamePlaceholder')" />
    </NFormItem>
    <NFormItem path="oldPassword">
      <NInput
        v-model:value="model.oldPassword"
        type="password"
        show-password-on="click"
        :placeholder="$t('page.login.resetPwd.oldPasswordPlaceholder')"
      />
    </NFormItem>
    <NFormItem path="newPassword">
      <NInput
        v-model:value="model.newPassword"
        type="password"
        show-password-on="click"
        :placeholder="$t('page.login.resetPwd.newPasswordPlaceholder')"
      />
    </NFormItem>
    <NSpace vertical :size="18" class="w-full">
      <NButton type="primary" size="large" round block :loading="authStore.changePasswordLoading" @click="handleSubmit">
        {{ $t('common.confirm') }}
      </NButton>
      <NButton size="large" round block @click="toggleLoginModule('pwd-login')">
        {{ $t('page.login.common.back') }}
      </NButton>
    </NSpace>
  </NForm>
</template>

<style scoped></style>
