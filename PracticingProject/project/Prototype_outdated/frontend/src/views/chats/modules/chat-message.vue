<script setup lang="ts">
import { ref, computed } from 'vue';
import { router } from '@/router';
import { request } from '@/service/request';
import { formatDate } from '@/utils/common';
import { VueMarkdownIt } from 'vue-markdown-shiki/dist/index.mjs';
import { useAuthStore } from '@/store/modules/auth';
import { localStg } from '@/utils/storage';
import SvgIcon from '@/components/custom/svg-icon.vue';

defineOptions({
  name: 'ChatMessage'
});

const props = defineProps<{
  msg: Api.Chat.Message;
  sessionId?: string;
  retrievalQueryFallback?: string;
}>();

const authStore = useAuthStore();

function handleCopy(content: string) {
  navigator.clipboard.writeText(content);
  window.$message?.success('已复制');
}

const feedbackSubmitting = ref<Record<string, boolean>>({});

function getMessageFeedbackKey(message: Api.Chat.Message) {
  return message.generationId || `${message.conversationId || 'unknown'}:${message.timestamp || ''}`;
}

async function handleFeedback(message: Api.Chat.Message, rating: 'good' | 'bad') {
  if (message.role !== 'assistant') {
    return;
  }

  const key = getMessageFeedbackKey(message);
  if (feedbackSubmitting.value[key]) {
    return;
  }

  const { error } = await request({
    url: 'chat/feedback',
    method: 'post',
    data: {
      rating,
      reason: rating === 'good' ? '用户点击点赞，表示认可本次回答' : '用户点击点踩，表示不满意本次回答',
      conversationId: message.conversationId,
      generationId: message.generationId
    }
  });

  feedbackSubmitting.value = {
    ...feedbackSubmitting.value,
    [key]: false
  };

  if (error) {
    window.$message?.error('反馈记录失败');
    return;
  }

  message.feedbackRating = rating;
  window.$message?.success(rating === 'good' ? '已记录点赞反馈' : '已记录点踩反馈');
}

// 存储文件名和对应的事件处理
const sourceFiles = ref<
  Array<{ fileName: string; id: string; referenceNumber: number; fileMd5?: string; pageNumber?: number }>
>([]);
const bareUrlPattern = /https?:\/\/[A-Za-z0-9\-._~:/?#[\]@!$&'()*+,;=%]+/g;
const toolNameLabels: Record<string, string> = {
  search_knowledge: '检索知识库',
  generate_summary: '生成知识摘要',
  submit_feedback: '记录反馈',
  knowledge_stats: '读取知识库统计'
};
const toolStatusLabels: Record<Api.Chat.AgentToolEvent['status'], string> = {
  executing: '执行中',
  success: '已完成',
  failed: '失败'
};

const toolEvents = computed(() => props.msg.toolEvents || []);

function getToolLabel(tool: string) {
  return toolNameLabels[tool] || tool;
}

function getToolStatusLabel(status: Api.Chat.AgentToolEvent['status']) {
  return toolStatusLabels[status] || status;
}

function splitTrailingUrlPunctuation(rawUrl: string) {
  let url = rawUrl;
  let trailing = '';

  while (url) {
    const lastChar = url.at(-1);
    if (!lastChar) break;

    if (/[，。！？；：、,.!?;:]/.test(lastChar)) {
      trailing = `${lastChar}${trailing}`;
      url = url.slice(0, -1);
      continue;
    }

    if (lastChar === ')' || lastChar === '）') {
      const openingChar = lastChar === ')' ? '(' : '（';
      const closingChar = lastChar;
      const openingCount = (url.match(new RegExp(`\\${openingChar}`, 'g')) || []).length;
      const closingCount = (url.match(new RegExp(`\\${closingChar}`, 'g')) || []).length;

      if (closingCount > openingCount) {
        trailing = `${lastChar}${trailing}`;
        url = url.slice(0, -1);
        continue;
      }
    }

    break;
  }

  return { url, trailing };
}

function normalizeBareUrls(text: string) {
  return text.replace(bareUrlPattern, (match, offset: number, source: string) => {
    const previousChar = source[offset - 1] || '';
    const previousTwoChars = source.slice(Math.max(0, offset - 2), offset);
    const previousTenChars = source.slice(Math.max(0, offset - 10), offset).toLowerCase();

    if (previousChar === '<' || previousTwoChars === '](' || /(?:href|src)=["']?$/.test(previousTenChars)) {
      return match;
    }

    const { url, trailing } = splitTrailingUrlPunctuation(match);
    return url ? `<${url}>${trailing}` : match;
  });
}

function createSourceLink(
  sourceNum: string,
  fileName: string,
  extras?: { fileMd5?: string; pageNumber?: number; displayName?: string }
): string {
  const linkClass = 'source-file-link';
  const trimmedFileName = fileName.trim();
  const fileId = `source-file-${sourceFiles.value.length}`;
  const referenceNumber = parseInt(sourceNum, 10);

  sourceFiles.value.push({
    fileName: trimmedFileName,
    id: fileId,
    referenceNumber,
    fileMd5: extras?.fileMd5,
    pageNumber: extras?.pageNumber
  });

  return `来源#${sourceNum}: <span class="${linkClass}" data-file-id="${fileId}">${extras?.displayName || trimmedFileName}</span>`;
}

// 处理来源文件链接的函数
function processSourceLinks(text: string): string {
  // 重置来源文件列表，避免重复
  sourceFiles.value = [];

  // 支持单个来源，也支持一个括号里包含多个来源：
  // (来源#1: test.pdf | 第5页; 来源#2: other.pdf | 第8页)
  const entryBoundary = '(?=\\s*(?:[;；,，、。！？!?\\)）]|$))';
  const pagePattern = new RegExp(
    `来源#(\\d+):\\s*([^|;；,，、。！？!?\\n\\r]+?)\\s*\\|\\s*第(\\d+)页${entryBoundary}`,
    'g'
  );
  const md5Pattern = new RegExp(
    `来源#(\\d+):\\s*([^|;；,，、。！？!?\\n\\r]+?)\\s*\\|\\s*MD5:\\s*([a-fA-F0-9]+)${entryBoundary}`,
    'g'
  );
  const simplePattern = new RegExp(`来源#(\\d+):\\s*([^<>\\n\\r|;；,，、。！？!?]+?)${entryBoundary}`, 'g');

  let processedText = text.replace(pagePattern, (_match, sourceNum, fileName, pageNum) => {
    return createSourceLink(sourceNum, fileName, {
      pageNumber: parseInt(pageNum, 10),
      displayName: `${fileName.trim()} (第${pageNum}页)`
    });
  });

  processedText = processedText.replace(md5Pattern, (_match, sourceNum, fileName, fileMd5) => {
    return createSourceLink(sourceNum, fileName, {
      fileMd5: fileMd5.trim()
    });
  });

  processedText = processedText.replace(simplePattern, (_match, sourceNum, fileName) => {
    return createSourceLink(sourceNum, fileName);
  });

  return processedText;
}

const content = computed(() => {
  const rawContent = props.msg.content ?? '';

  // 只对助手消息处理来源链接
  if (props.msg.role === 'assistant') {
    return normalizeBareUrls(processSourceLinks(rawContent));
  }

  return rawContent;
});

function extractContextAnchorText(target: HTMLElement) {
  const scope = target.closest('li, p, blockquote, td, th');
  const rawText = scope?.textContent?.replace(/\s+/g, ' ').trim() || '';
  if (!rawText) return '';

  const beforeCitation = rawText.split(/(?:\(|（)?来源#\d+:/)[0] || rawText;
  return beforeCitation
    .replace(/^\s*\d+\.\s*/, '')
    .replace(/[（(]\s*$/, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function openReferencePreviewPage(payload: {
  retrievalMode?: Api.Chat.ReferenceEvidence['retrievalMode'];
  retrievalLabel?: string | null;
  retrievalQuery?: string | null;
  evidenceSnippet?: string | null;
  matchedChunkText?: string | null;
  score?: number | null;
  chunkId?: number | null;
  fileName: string;
  fileMd5?: string | null;
  pageNumber?: number | null;
  anchorText?: string | null;
  sessionId?: string;
  referenceNumber: number;
}) {
  const previewKey = `reference-preview:${Date.now()}:${Math.random().toString(36).slice(2, 8)}`;

  // 将当前 token 和 refreshToken 也存入 payload，
  // 解决 WSL2 环境下 window.open 新标签页的 localStorage 与主标签页隔离的问题。
  // 新标签页的 route guard 会从 payload 中恢复 token 到 localStorage。
  const tokenForNewTab = localStg.get('token');
  const refreshTokenForNewTab = localStg.get('refreshToken');
  const payloadWithAuth = {
    ...payload,
    __authToken: tokenForNewTab,
    __authRefreshToken: refreshTokenForNewTab
  };

  localStorage.setItem(previewKey, JSON.stringify(payloadWithAuth));

  const routeLocation = router.resolve({
    path: '/chats',
    query: {
      preview: 'reference',
      previewKey
    }
  });

  window.open(routeLocation.href, '_blank', 'noopener,noreferrer');
}

// 处理内容点击事件（事件委托）
function handleContentClick(event: MouseEvent) {
  const target = event.target as HTMLElement;

  // 检查点击的是否是文件链接
  if (target.classList.contains('source-file-link')) {
    const fileId = target.getAttribute('data-file-id');
    if (fileId) {
      const file = sourceFiles.value.find(f => f.id === fileId);
      if (file) {
        const contextAnchorText = extractContextAnchorText(target);
        handleSourceFileClick({
          fileName: file.fileName,
          referenceNumber: file.referenceNumber,
          fileMd5: file.fileMd5,
          anchorText: contextAnchorText
        });
      }
    }
  }
}

// 处理来源文件点击事件
async function handleSourceFileClick(fileInfo: {
  fileName: string;
  referenceNumber: number;
  fileMd5?: string;
  anchorText?: string;
}) {
  const { fileName, referenceNumber, fileMd5: extractedMd5, anchorText: clickedAnchorText } = fileInfo;
  const persistedDetail =
    props.msg.referenceMappings?.[String(referenceNumber)] || props.msg.referenceMappings?.[referenceNumber];
  const referenceSessionId = props.msg.generationId || props.msg.conversationId || props.sessionId;
  console.log(
    '点击了来源文件:',
    fileName,
    '引用编号:',
    referenceNumber,
    '提取的MD5:',
    extractedMd5,
    '会话ID:',
    referenceSessionId
  );

  try {
    const fallbackRetrievalQuery = props.retrievalQueryFallback || '';

    // 优先使用 WebSocket completion 事件携带的 referenceMappings 中的数据；
    // 它有 fileMd5 就不需要调用 /documents/reference-detail API，
    // 从而避免该 API 意外返回登出码（8888/8889）触发 clearAuthStorage()
    // 导致后续 window.open 的新标签页因缺少 token 被路由守卫重定向到登录页。
    if (persistedDetail?.fileMd5) {
      openReferencePreviewPage({
        fileName: persistedDetail.fileName || fileName,
        fileMd5: persistedDetail.fileMd5,
        pageNumber: persistedDetail.pageNumber,
        anchorText: clickedAnchorText || persistedDetail.anchorText || '',
        retrievalMode: persistedDetail.retrievalMode,
        retrievalLabel: persistedDetail.retrievalLabel,
        retrievalQuery: persistedDetail.retrievalQuery || fallbackRetrievalQuery,
        evidenceSnippet: persistedDetail.evidenceSnippet,
        matchedChunkText: persistedDetail.matchedChunkText,
        score: persistedDetail.score,
        chunkId: persistedDetail.chunkId,
        sessionId: referenceSessionId,
        referenceNumber
      });
      return;
    }

    // persistedDetail 缺少 fileMd5，通过 API 补全
    let detail: Api.Document.ReferenceDetailResponse | null = null;

    if (referenceSessionId) {
      try {
        const { error: detailError, data: detailData } = await request<Api.Document.ReferenceDetailResponse>({
          url: 'documents/reference-detail',
          params: {
            sessionId: referenceSessionId,
            referenceNumber: referenceNumber.toString()
          }
        });

        if (!detailError && detailData?.fileMd5) {
          detail = detailData;
        }
      } catch (detailErr) {
        console.warn('通过API查询引用详情失败:', detailErr);
      }
    }

    // 安全检查：如果 API 调用触发了登出（logoutCodes），token 会被同步清除，
    // 此时 window.open 的新标签页必然被路由守卫拦截，所以直接放弃打开预览。
    if (!localStg.get('token')) {
      console.warn('检测到 token 已丢失，跳过打开引用预览（可能 API 返回了登出码）');
      return;
    }

    const targetMd5 = detail?.fileMd5 || extractedMd5 || null;
    openReferencePreviewPage({
      fileName: detail?.fileName || fileName,
      fileMd5: targetMd5,
      pageNumber: detail?.pageNumber,
      anchorText: clickedAnchorText || detail?.anchorText || '',
      retrievalMode: detail?.retrievalMode,
      retrievalLabel: detail?.retrievalLabel,
      retrievalQuery: detail?.retrievalQuery || fallbackRetrievalQuery,
      evidenceSnippet: detail?.evidenceSnippet,
      matchedChunkText: detail?.matchedChunkText,
      score: detail?.score,
      chunkId: detail?.chunkId,
      sessionId: referenceSessionId,
      referenceNumber
    });
  } catch (err) {
    console.error('文件下载失败:', err);
    window.$message?.error(`文件下载失败: ${fileName}`);
  }
}
</script>

<template>
  <div class="mb-8 flex-col gap-2">
    <div v-if="msg.role === 'user'" class="flex item-center gap-4">
      <NAvatar class="bg-success">
        <SvgIcon icon="ph:user-circle" class="text-icon-large color-white" />
      </NAvatar>
      <div class="flex-col gap-1">
        <NText class="text-4 font-bold">{{ msg.username || authStore.userInfo.userName }}</NText>
        <NText class="text-3 color-gray-500">{{ formatDate(msg.timestamp) }}</NText>
      </div>
    </div>
    <div v-else class="flex items-center gap-4">
      <NAvatar>
        <SystemLogo class="text-6 text-white" />
      </NAvatar>
      <div class="flex-col gap-1">
        <NText class="text-4 font-bold">NewBee AI</NText>
        <NText class="text-3 color-gray-500">{{ formatDate(msg.timestamp) }}</NText>
      </div>
    </div>
    <div v-if="msg.role === 'assistant' && toolEvents.length > 0" class="ml-12 mt-3 flex flex-col gap-2">
      <div
        v-for="value in toolEvents"
        :key="value.id || value.tool"
        class="tool-event"
        :class="`tool-event--${value.status}`"
      >
        <icon-eos-icons:three-dots-loading v-if="value.status === 'executing'" class="text-4" />
        <icon-material-symbols:check-circle-rounded v-else-if="value.status === 'success'" class="text-4" />
        <icon-material-symbols:error-rounded v-else class="text-4" />
        <span class="tool-event__name">{{ getToolLabel(value.tool) }}</span>
        <span class="tool-event__status">{{ getToolStatusLabel(value.status) }}</span>
      </div>
    </div>
    <NText v-if="msg.status === 'pending' || (msg.status === 'loading' && msg.role === 'assistant' && !msg.content)">
      <icon-eos-icons:three-dots-loading class="ml-12 mt-2 text-8" />
    </NText>
    <NText v-else-if="msg.status === 'error'" class="ml-12 mt-2 italic color-#d03050">
      {{ msg.content || '服务器繁忙，请稍后再试' }}
    </NText>
    <div v-else-if="msg.role === 'assistant'" class="mt-2 pl-12" @click="handleContentClick">
      <VueMarkdownIt :content="content" />
    </div>
    <NText v-else-if="msg.role === 'user'" class="mt-12 mt-2 text-4">{{ content }}</NText>
    <NDivider class="ml-12 w-[calc(100%-3rem)] mb-0! mt-2!" />
    <div class="ml-12 flex gap-2">
      <NButton quaternary title="复制回答" aria-label="复制回答" @click="handleCopy(msg.content)">
        <template #icon>
          <icon-mynaui:copy />
        </template>
      </NButton>
      <NButton
        v-if="msg.role === 'assistant'"
        quaternary
        title="点赞"
        aria-label="点赞"
        :type="msg.feedbackRating === 'good' ? 'primary' : 'default'"
        :loading="feedbackSubmitting[getMessageFeedbackKey(msg)]"
        @click="handleFeedback(msg, 'good')"
      >
        <template #icon>
          <icon-material-symbols:thumb-up-outline-rounded />
        </template>
      </NButton>

      <NButton
        v-if="msg.role === 'assistant'"
        quaternary
        title="点踩"
        aria-label="点踩"
        :type="msg.feedbackRating === 'bad' ? 'error' : 'default'"
        :loading="feedbackSubmitting[getMessageFeedbackKey(msg)]"
        @click="handleFeedback(msg, 'bad')"
      >
        <template #icon>
          <icon-material-symbols:thumb-down-outline-rounded />
        </template>
      </NButton>
    </div>
  </div>
</template>

<style scoped>
.tool-event {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border-radius: 8px;
  font-size: 13px;
  line-height: 1.4;
  background: #f5f5f5;
  color: #666;
  transition: all 0.25s ease;
  max-width: fit-content;
}

.tool-event--executing {
  background: #eff6ff;
  color: #3b82f6;
  border: 1px solid #bfdbfe;
}

.tool-event--success {
  background: #f0fdf4;
  color: #16a34a;
  border: 1px solid #bbf7d0;
}

.tool-event--failed {
  background: #fef2f2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.tool-event__name {
  font-weight: 600;
}

.tool-event__status {
  font-size: 11px;
  opacity: 0.75;
}

.tool-event--executing :deep(.text-4) {
  animation: tool-spin 1.2s linear infinite;
}

@keyframes tool-spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* dark mode overrides */
:global(.dark) .tool-event {
  background: #2a2a2a;
  color: #999;
}

:global(.dark) .tool-event--executing {
  background: rgba(59, 130, 246, 0.12);
  color: #60a5fa;
  border-color: rgba(59, 130, 246, 0.25);
}

:global(.dark) .tool-event--success {
  background: rgba(34, 197, 94, 0.12);
  color: #4ade80;
  border-color: rgba(34, 197, 94, 0.25);
}

:global(.dark) .tool-event--failed {
  background: rgba(239, 68, 68, 0.12);
  color: #f87171;
  border-color: rgba(239, 68, 68, 0.25);
}

/* 引用文档链接样式 */
:deep(.source-file-link) {
  color: #2563eb;
  font-weight: 500;
  cursor: pointer;
  text-decoration: underline;
  text-underline-offset: 2px;
  transition: color 0.15s;
}

:deep(.source-file-link):hover {
  color: #1d4ed8;
}

:global(.dark) :deep(.source-file-link) {
  color: #60a5fa;
}

:global(.dark) :deep(.source-file-link):hover {
  color: #93bbfd;
}
</style>
