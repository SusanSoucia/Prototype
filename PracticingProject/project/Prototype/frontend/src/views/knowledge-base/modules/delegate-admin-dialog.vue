<script setup lang="ts">
import { ref, watch } from 'vue';
import { NButton, NTag, NPopconfirm, NDivider, NSelect, NForm, NFormItem, NModal } from 'naive-ui';
import { fetchGetUserList, fetchAssignOrgTagsToUser } from '@/service/api/admin';
import { fetchGetOrgTagTree } from '@/service/api/org-tag';

defineOptions({ name: 'DelegateAdminDialog' });

const visible = defineModel<boolean>('visible', { default: false });
const loading = ref(false);

// ==================== 数据 ====================

/** 库管用户信息（一个库管只持有一个标签 = 管理一个知识库） */
interface LibraryAdmin {
  userId: number;
  username: string;
  /** 该库管持有的唯一标签（tagId） */
  managedTagId: string;
  /** 该库管持有的唯一标签名 */
  managedTagName: string;
}

const adminList = ref<LibraryAdmin[]>([]);
const tagOptions = ref<{ label: string; value: string }[]>([]);

async function fetchData() {
  loading.value = true;

  // 获取用户列表，筛选 LIBRARY_ADMIN
  const { error: userErr, data: userData } = await fetchGetUserList({ page: 1, size: 200 });
  if (!userErr && userData?.data) {
    adminList.value = (userData.data as any[])
      .filter(u => u.role === 'LIBRARY_ADMIN' || u.status === 2)
      .map(u => ({
        userId: u.userId,
        username: u.username,
        // 一个库管只持有一个标签
        managedTagId: u.orgTags?.[0]?.tagId || '',
        managedTagName: u.orgTags?.[0]?.name || '—'
      }));
  }

  // 获取标签树，只收集管理员标签下的子标签（库管标签）
  const { error: tagErr, data: tagData } = await fetchGetOrgTagTree();
  if (!tagErr && tagData) {
    const items = Array.isArray(tagData) ? tagData : ((tagData as any)?.data || []);
    const adminRoot = (Array.isArray(items) ? items : []).find(
      (n: any) => n.tagId === 'ADMIN' || n.name === '管理员'
    );
    const libTags: { label: string; value: string }[] = [];
    if (adminRoot?.children) {
      (function walk(nodes: any[]) {
        for (const n of nodes) {
          libTags.push({ label: n.name || n.label, value: n.tagId || n.value });
          if (n.children) walk(n.children);
        }
      })(adminRoot.children);
    }
    tagOptions.value = libTags;
  }

  loading.value = false;
}

watch(visible, () => {
  if (visible.value) {
    fetchData();
    resetNewForm();
  }
});

// ==================== 新增委托 ====================

const existingUserId = ref<number | null>(null);
/** 单个标签 — 一个用户只能持有一个标签 */
const selectedTag = ref<string | null>(null);
const submitting = ref(false);

function resetNewForm() {
  existingUserId.value = null;
  selectedTag.value = null;
}

// 搜索已有用户的选项
const userSearchOptions = ref<{ label: string; value: number }[]>([]);
async function handleUserSearch(query: string) {
  if (!query) {
    // 无搜索词时显示所有用户（排除超管自身）
    const { error, data } = await fetchGetUserList({ page: 1, size: 100 });
    if (!error && data?.data) {
      userSearchOptions.value = (data.data as any[])
        .filter((u: any) => u.role !== 'ADMIN')
        .map((u: any) => ({
          label: `${u.username}（角色: ${u.role === 'LIBRARY_ADMIN' ? '库管' : '用户'}）`,
          value: u.userId
        }));
    }
    return;
  }
  const { error, data } = await fetchGetUserList({ keyword: query, page: 1, size: 20 });
  if (!error && data?.data) {
    userSearchOptions.value = (data.data as any[])
      .filter((u: any) => u.role !== 'ADMIN')
      .map((u: any) => ({
        label: `${u.username}（角色: ${u.role === 'LIBRARY_ADMIN' ? '库管' : '用户'}）`,
        value: u.userId
      }));
  }
}

/** 为用户分配标签（单标签） */
async function handleAssignExisting() {
  if (!existingUserId.value || !selectedTag.value) {
    window.$message?.warning('请选择用户和标签');
    return;
  }
  submitting.value = true;
  const { error } = await fetchAssignOrgTagsToUser(existingUserId.value, [selectedTag.value]);
  submitting.value = false;
  if (!error) {
    window.$message?.success('委托成功（用户已升级为库管）');
    fetchData();
    resetNewForm();
  }
}

// ==================== 编辑/移除 ====================

/** 正在编辑的用户 ID，以及为其选择的新标签 */
const editingUserId = ref<number | null>(null);
const editingTag = ref<string | null>(null);

function startEdit(user: LibraryAdmin) {
  editingUserId.value = user.userId;
  editingTag.value = user.managedTagId;
}

async function saveEdit() {
  if (!editingUserId.value || !editingTag.value) return;
  // 分配单个标签（覆盖旧标签）
  const { error } = await fetchAssignOrgTagsToUser(editingUserId.value, [editingTag.value]);
  if (!error) {
    window.$message?.success('标签已更新');
    editingUserId.value = null;
    fetchData();
  }
}

function cancelEdit() {
  editingUserId.value = null;
}

/** 移除委托：清空标签 → 后端自动降级为 USER */
async function handleRemoveDelegation(user: LibraryAdmin) {
  const { error } = await fetchAssignOrgTagsToUser(user.userId, []);
  if (!error) {
    window.$message?.success('已移除库管委托（用户降级为普通用户）');
    fetchData();
  }
}
</script>

<template>
  <NModal
    v-model:show="visible"
    preset="dialog"
    title="委托库管"
    :show-icon="false"
    :mask-closable="false"
    class="w-750px! max-w-[calc(100vw-4rem)]"
  >
    <div class="flex flex-col gap-20px">

      <!-- 区域 1：当前库管列表 -->
      <div>
        <h4 class="text-16px font-500 mb-12px">已委托的库管</h4>
        <div v-if="adminList.length === 0" class="text-stone-400 text-14px py-4">
          暂无库管委托记录
        </div>
        <div v-else class="flex flex-col gap-8px">
          <div
            v-for="user in adminList"
            :key="user.userId"
            class="flex items-center justify-between rounded-8px bg-stone-50 px-16px py-10px"
          >
            <div class="flex items-center gap-12px min-w-0">
              <span class="font-500 text-14px shrink-0">{{ user.username }}</span>
              <NTag size="small" type="info" :bordered="false">库管</NTag>
              <span class="text-13px text-stone-500 truncate">管理: {{ user.managedTagName }}</span>
            </div>

            <!-- 编辑模式 -->
            <div v-if="editingUserId === user.userId" class="flex items-center gap-8px shrink-0">
              <NSelect
                v-model:value="editingTag"
                :options="tagOptions"
                placeholder="更换标签"
                class="w-200px!"
                size="small"
              />
              <NButton size="tiny" type="primary" @click="saveEdit">保存</NButton>
              <NButton size="tiny" @click="cancelEdit">取消</NButton>
            </div>

            <!-- 展示模式 -->
            <div v-else class="flex items-center gap-8px shrink-0">
              <NButton size="tiny" ghost type="primary" @click="startEdit(user)">换标签</NButton>
              <NPopconfirm @positive-click="() => handleRemoveDelegation(user)">
                <template #default>
                  移除后将清空该用户的标签并降级为普通用户，确认？
                </template>
                <template #trigger>
                  <NButton size="tiny" ghost type="error">移除</NButton>
                </template>
              </NPopconfirm>
            </div>
          </div>
        </div>
      </div>

      <NDivider />

      <!-- 区域 2：新增委托 -->
      <div>
        <h4 class="text-16px font-500 mb-12px">新增委托</h4>

        <NForm label-placement="left" :label-width="80" size="small">
          <NFormItem label="选择用户">
            <NSelect
              v-model:value="existingUserId"
              :options="userSearchOptions"
              filterable
              remote
              placeholder="搜索已有用户..."
              :loading="loading"
              clearable
              class="w-260px!"
              @search="handleUserSearch"
            />
          </NFormItem>

          <!-- 委托标签（单选：一个库管只管理一个知识库） -->
          <NFormItem label="委托标签">
            <NSelect
              v-model:value="selectedTag"
              :options="tagOptions"
              placeholder="选择一个知识库标签"
              class="w-300px!"
            />
            <div class="text-12px text-stone-400 mt-4px">
              一个库管只持有一个标签，对应一个知识库
            </div>
          </NFormItem>

          <NFormItem>
            <NButton
              type="primary"
              :loading="submitting"
              :disabled="!existingUserId || !selectedTag"
              @click="handleAssignExisting"
            >
              确认委托
            </NButton>
          </NFormItem>
        </NForm>
      </div>

    </div>
  </NModal>
</template>
