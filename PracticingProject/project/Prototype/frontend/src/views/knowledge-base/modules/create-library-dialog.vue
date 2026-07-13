<script setup lang="ts">
import { ref, watch } from 'vue';
import { NButton, NInput, NForm, NFormItem, NSpace, NModal } from 'naive-ui';
import { useFormRules, useNaiveForm } from '@/hooks/common/form';
import { request } from '@/service/request';

defineOptions({ name: 'CreateLibraryDialog' });

const emit = defineEmits<{ submitted: [] }>();

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);

const { formRef, validate, restoreValidation } = useNaiveForm();
const { defaultRequiredRule } = useFormRules();

/**
 * 表单字段：
 * - name: 库名称（也是标签显示名）
 * - tagId: 库管标签 ID（库的唯一标识，将作为 ADMIN 标签的子标签创建）
 * - description: 库描述
 */
const model = ref({
  name: '',
  tagId: '',
  description: ''
});

const rules = {
  name: [defaultRequiredRule],
  tagId: [defaultRequiredRule],
  description: [defaultRequiredRule]
};

function createDefaultModel() {
  return { name: '', tagId: '', description: '' };
}

/**
 * 提交：创建库管标签（ADMIN 的子标签），该标签即知识库的唯一标识。
 * 后续在"委托库管"中将此标签分配给用户，用户即成为该库的库管。
 */
async function handleSubmit() {
  await validate();
  loading.value = true;

  const { error } = await request({
    url: '/admin/org-tags',
    method: 'POST',
    data: {
      name: model.value.name,
      tagId: model.value.tagId,
      description: model.value.description,
      parentTag: 'ADMIN'
    }
  });

  loading.value = false;
  if (!error) {
    window.$message?.success('知识库创建成功');
    visible.value = false;
    emit('submitted');
  }
}

function close() {
  visible.value = false;
}

watch(visible, () => {
  if (visible.value) {
    model.value = createDefaultModel();
    restoreValidation();
  }
});
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="创建新知识库"
    :show-icon="false"
    :mask-closable="false"
    class="w-500px!"
    @positive-click="handleSubmit"
  >
    <NForm ref="formRef" :model="model" :rules="rules" label-placement="left" :label-width="100" mt-10>
      <NFormItem label="库名称" path="name">
        <NInput v-model:value="model.name" placeholder="请输入知识库名称" maxlength="60" />
      </NFormItem>
      <NFormItem label="库管标签" path="tagId">
        <NInput v-model:value="model.tagId" placeholder="标签 ID，作为库的唯一标识" maxlength="60" />
        <div class="text-12px text-stone-400 mt-4px">
          此标签将作为 ADMIN 的子标签创建，后续分配给库管用户
        </div>
      </NFormItem>
      <NFormItem label="库描述" path="description">
        <NInput
          v-model:value="model.description"
          type="textarea"
          placeholder="请输入库描述"
          maxlength="300"
          clearable
          show-count
          :autosize="{ minRows: 3, maxRows: 6 }"
        />
      </NFormItem>
    </NForm>
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" :loading="loading" @click="handleSubmit">创建</NButton>
      </NSpace>
    </template>
  </NModal>
</template>
