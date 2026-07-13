<script setup lang="ts">
import { uploadAccept } from '@/constants/common';

defineOptions({
  name: 'UploadDialog'
});

const loading = ref(false);
const visible = defineModel<boolean>('visible', { default: false });
const singleOrgOnly = ref(false);

const authStore = useAuthStore();

const { formRef, validate, restoreValidation } = useNaiveForm();
const { defaultRequiredRule } = useFormRules();

const model = ref<Api.KnowledgeBase.Form>(createDefaultModel());

/** 从后端拉取的合法组织标签 ID 集合，提交时以此为准做校验 */
const validOrgTagIds = ref<Set<string>>(new Set());

function createDefaultModel(): Api.KnowledgeBase.Form {
  return {
    orgTag: null,
    orgTagName: '',
    isPublic: false,
    fileList: []
  };
}

const rules = ref<FormRules>({
  orgTag: defaultRequiredRule,
  isPublic: defaultRequiredRule,
  fileList: defaultRequiredRule
});

/**
 * 提交前校验组织标签是否在后端合法标签列表中
 * 以后端数据为权威来源，防止前端持有的标签信息过期
 */
/** File size validation error (currently no size limit enforced; returns null = no error) */
const fileSizeLimitError = computed(() => null);

const orgTagValidationError = computed(() => {
  if (!model.value.orgTag) return ''; // requiredRule 已处理空值
  if (validOrgTagIds.value.size === 0) return ''; // 尚未加载完成，放行（避免阻塞）
  if (!validOrgTagIds.value.has(model.value.orgTag)) {
    return `组织标签 "${model.value.orgTag}" 在后端不存在，请重新选择`;
  }
  return '';
});

const submitDisabled = computed(
  () => loading.value || Boolean(fileSizeLimitError.value) || Boolean(orgTagValidationError.value)
);

function close() {
  visible.value = false;
}

const store = useKnowledgeBaseStore();
async function handleSubmit() {
  await validate();
  if (fileSizeLimitError.value) return;
  if (orgTagValidationError.value) {
    window.$message?.error(orgTagValidationError.value);
    return;
  }

  loading.value = true;
  await store.enqueueUpload(model.value);
  loading.value = false;
  close();
}

/** 将组织标签树扁平化，递归提取所有 tagId */
function flattenOrgTagTree(items: Api.OrgTag.Item[]): string[] {
  const ids: string[] = [];
  for (const item of items) {
    ids.push(item.tagId);
    if (item.children && item.children.length > 0) {
      ids.push(...flattenOrgTagTree(item.children));
    }
  }
  return ids;
}

/** 从后端拉取合法组织标签列表，作为校验的权威来源 */
async function fetchValidOrgTags() {
  if (authStore.isAdmin) {
    // Admin 从管理端标签树拉取全量标签
    const { error, data } = await request<{ data: Api.OrgTag.Item[] }>({ url: '/admin/org-tags/tree' });
    if (!error && data?.data) {
      validOrgTagIds.value = new Set(flattenOrgTagTree(data.data));
    }
  } else {
    // 普通用户从用户标签接口拉取
    const { error, data } = await request<Api.OrgTag.Mine>({ url: '/users/org-tags' });
    if (!error && data?.orgTags) {
      validOrgTagIds.value = new Set(data.orgTags);
    }
  }
}

async function presetSingleOrgForUser() {
  singleOrgOnly.value = false;
  const { error, data } = await request<Api.OrgTag.Mine>({ url: '/users/org-tags' });
  if (error || !visible.value) return;

  // 同时更新合法标签集合（非 admin 路径）
  if (data?.orgTags) {
    validOrgTagIds.value = new Set(data.orgTags);
  }

  const orgTagDetails = data.orgTagDetails || [];
  if (orgTagDetails.length !== 1) return;

  const singleOrg = orgTagDetails[0];
  model.value.orgTag = singleOrg.tagId;
  onUpdate(singleOrg);
  singleOrgOnly.value = true;
}

watch(visible, () => {
  if (visible.value) {
    model.value = createDefaultModel();
    singleOrgOnly.value = false;
    validOrgTagIds.value = new Set();
    // 弹窗打开时拉取后端标签数据作为权威来源
    fetchValidOrgTags();
    if (!authStore.isAdmin) {
      presetSingleOrgForUser();
    }
    restoreValidation();
  }
});

function onUpdate(option: unknown) {
  if (option) {
    const selected = option as Api.OrgTag.Item;
    model.value.orgTagName = selected.name;
    return;
  }
  model.value.orgTagName = '';
}
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="文件上传"
    :show-icon="false"
    :mask-closable="false"
    class="w-500px!"
    @positive-click="handleSubmit"
  >
    <NForm ref="formRef" :model="model" :rules="rules" label-placement="left" :label-width="100" mt-10>
      <NFormItem v-if="authStore.isAdmin" label="组织标签" path="orgTag">
        <OrgTagCascader v-model:value="model.orgTag" @change="onUpdate" />
        <div v-if="orgTagValidationError" class="mt-8px text-12px text-#ef4444">
          {{ orgTagValidationError }}
        </div>
      </NFormItem>
      <NFormItem v-else label="组织标签" path="orgTag">
        <TheSelect
          v-model:value="model.orgTag"
          url="/users/org-tags"
          key-field="orgTagDetails"
          label-field="name"
          value-field="tagId"
          :disabled="singleOrgOnly"
          @change="onUpdate"
        />
        <div v-if="orgTagValidationError" class="mt-8px text-12px text-#ef4444">
          {{ orgTagValidationError }}
        </div>
      </NFormItem>

      <NFormItem label="是否公开" path="isPublic">
        <NRadioGroup v-model:value="model.isPublic" name="radiogroup">
          <NSpace :size="16">
            <NRadio :value="true">公开</NRadio>
            <NRadio :value="false">私有</NRadio>
          </NSpace>
        </NRadioGroup>
      </NFormItem>
      <NFormItem label="标签描述" path="fileList">
        <NUpload
          v-model:file-list="model.fileList"
          :accept="uploadAccept"
          :max="1"
          :multiple="false"
          :default-upload="false"
        >
          <NButton>上传文件</NButton>
        </NUpload>
      </NFormItem>
    </NForm>
    <template #action>
      <NSpace :size="16">
        <NButton @click="close">取消</NButton>
        <NButton type="primary" :disabled="submitDisabled" @click="handleSubmit">保存</NButton>
      </NSpace>
    </template>
  </NModal>
</template>

<style scoped></style>
