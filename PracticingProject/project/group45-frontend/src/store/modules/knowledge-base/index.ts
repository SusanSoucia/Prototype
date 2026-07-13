import { ref } from 'vue';
import { defineStore } from 'pinia';
import { SetupStoreId, UploadStatus } from '@/enum';
import { chunkSize } from '@/constants/common';
import { nanoid } from 'nanoid';
import { request } from '@/service/request';
import { calculateMD5 } from '@/utils/common';

const maxConcurrentChunksPerFile = 4;

export const useKnowledgeBaseStore = defineStore(SetupStoreId.KnowledgeBase, () => {
  const tasks = ref<Api.KnowledgeBase.UploadTask[]>([]);
  const activeUploads = ref<Set<string>>(new Set());

  function mergeUploadedChunks(currentUploadedChunks: number[], latestUploadedChunks: number[]) {
    return Array.from(new Set([...currentUploadedChunks, ...latestUploadedChunks])).sort((a, b) => a - b);
  }

  async function uploadChunk(task: Api.KnowledgeBase.UploadTask, chunkIndex: number): Promise<boolean> {
    const totalChunks = Math.ceil(task.totalSize / chunkSize);

    const chunkStart = chunkIndex * chunkSize;
    const chunkEnd = Math.min(chunkStart + chunkSize, task.totalSize);
    const chunk = task.file!.slice(chunkStart, chunkEnd);

    const requestId = nanoid();
    task.requestIds ??= [];
    task.requestIds.push(requestId);

    const formData = new FormData();
    formData.append('file', chunk, task.fileName);
    formData.append('fileMd5', task.fileMd5);
    formData.append('chunkIndex', String(chunkIndex));
    formData.append('totalSize', String(task.totalSize));
    formData.append('totalChunks', String(totalChunks));
    formData.append('fileName', task.fileName);
    if (task.orgTag) {
      formData.append('orgTag', task.orgTag);
    }
    formData.append('isPublic', String(task.isPublic ?? false));

    const { error, data } = await request<Api.KnowledgeBase.Progress>({
      url: '/upload/chunk',
      method: 'POST',
      data: formData,
      timeout: 10 * 60 * 1000
    });

    task.requestIds = task.requestIds.filter(id => id !== requestId);

    if (error) return false;

    const updatedTask = tasks.value.find(t => t.fileMd5 === task.fileMd5);
    if (!updatedTask) return true;

    updatedTask.chunkIndex = chunkIndex;
    updatedTask.uploadedChunks = mergeUploadedChunks(updatedTask.uploadedChunks, data.uploaded);
    updatedTask.progress = Number.parseFloat(((updatedTask.uploadedChunks.length / totalChunks) * 100).toFixed(2));

    return true;
  }

  async function uploadChunksInParallel(task: Api.KnowledgeBase.UploadTask, chunkIndexes: number[]) {
    if (chunkIndexes.length === 0) return;

    let uploadError: Error | null = null;
    const workerCount = Math.min(maxConcurrentChunksPerFile, chunkIndexes.length);

    const runWorker = async (): Promise<void> => {
      if (uploadError) return;

      const chunkIndex = chunkIndexes.shift();
      if (chunkIndex === undefined) return;

      const success = await uploadChunk(task, chunkIndex);
      if (!success) {
        uploadError = new Error(`分片 ${chunkIndex} 上传失败`);
        return;
      }

      await runWorker();
    };

    const workers = Array.from({ length: workerCount }, () => runWorker());
    await Promise.all(workers);

    if (uploadError) throw uploadError;
  }

  async function mergeFile(task: Api.KnowledgeBase.UploadTask) {
    try {
      const { error, data } = await request<Api.KnowledgeBase.MergeResult>({
        url: '/upload/merge',
        method: 'POST',
        data: { fileMd5: task.fileMd5, fileName: task.fileName }
      });
      if (error) return false;

      const index = tasks.value.findIndex(t => t.fileMd5 === task.fileMd5);
      tasks.value[index].status = UploadStatus.Completed;
      tasks.value[index].progress = 100;
      tasks.value[index].estimatedEmbeddingTokens = data?.estimatedEmbeddingTokens;
      tasks.value[index].estimatedChunkCount = data?.estimatedChunkCount;
      tasks.value[index].vectorizationStatus = 'PROCESSING';
      tasks.value[index].vectorizationErrorMessage = null;
      tasks.value[index].actualEmbeddingTokens = undefined;
      tasks.value[index].actualChunkCount = undefined;

      if (data?.estimatedEmbeddingTokens) {
        const tokenLabel = Number(data.estimatedEmbeddingTokens).toLocaleString();
        const chunkLabel = Number(data.estimatedChunkCount || 0).toLocaleString();
        window.$message?.success(`上传完成，预计向量化消耗 ${tokenLabel} Tokens（${chunkLabel} 个切片）`);
      }
      return true;
    } catch {
      return false;
    }
  }

  async function enqueueUpload(form: Api.KnowledgeBase.Form) {
    const file = form.fileList![0].file!;
    const md5 = await calculateMD5(file);

    const existingTask = tasks.value.find(t => t.fileMd5 === md5);
    if (existingTask) {
      if (existingTask.status === UploadStatus.Completed) {
        window.$message?.error('文件已存在');
        return;
      } else if (existingTask.status === UploadStatus.Pending || existingTask.status === UploadStatus.Uploading) {
        window.$message?.error('文件正在上传中');
        return;
      } else if (existingTask.status === UploadStatus.Break) {
        existingTask.status = UploadStatus.Pending;
        // 服务端返回的任务缺少本地属性，重新初始化
        existingTask.file = file;
        existingTask.uploadedChunks = existingTask.uploadedChunks || [];
        existingTask.progress = existingTask.progress ?? 0;
        existingTask.orgTag = form.orgTag;
        existingTask.orgTagName = form.orgTagName ?? null;
        existingTask.isPublic = form.isPublic;
        startUpload();
        return;
      }
    }

    const newTask: Api.KnowledgeBase.UploadTask = {
      file,
      chunk: null,
      chunkIndex: 0,
      fileMd5: md5,
      fileName: file.name,
      totalSize: file.size,
      public: form.isPublic,
      isPublic: form.isPublic,
      uploadedChunks: [],
      progress: 0,
      status: UploadStatus.Pending,
      orgTag: form.orgTag,
      vectorizationStatus: null,
      vectorizationErrorMessage: null
    };

    newTask.orgTagName = form.orgTagName ?? null;

    tasks.value.push(newTask);
    startUpload();
  }

  async function startUpload() {
    if (activeUploads.value.size >= 3) return;

    const pendingTasks = tasks.value.filter(
      t => t.status === UploadStatus.Pending && !activeUploads.value.has(t.fileMd5)
    );

    if (pendingTasks.length === 0) return;

    const task = pendingTasks[0];
    task.status = UploadStatus.Uploading;
    activeUploads.value.add(task.fileMd5);

    const totalChunks = Math.ceil(task.totalSize / chunkSize);

    // 防御：确保本地属性已初始化（服务端返回的任务没有这些字段）
    task.uploadedChunks = task.uploadedChunks || [];

    try {
      if (task.uploadedChunks.length === totalChunks) {
        const success = await mergeFile(task);
        if (!success) throw new Error('文件合并失败');
        return;
      }

      const pendingChunkIndexes: number[] = [];
      for (let i = 0; i < totalChunks; i += 1) {
        if (!task.uploadedChunks.includes(i)) {
          pendingChunkIndexes.push(i);
        }
      }

      await uploadChunksInParallel(task, pendingChunkIndexes);

      const updatedTask = tasks.value.find(t => t.fileMd5 === task.fileMd5);
      if (!updatedTask) return;

      updatedTask.uploadedChunks = updatedTask.uploadedChunks || [];

      if (updatedTask.uploadedChunks.length !== totalChunks) {
        throw new Error('分片上传未完成');
      }

      const success = await mergeFile(updatedTask);
      if (!success) throw new Error('文件合并失败');
    } catch (e) {
      console.error('Upload error:', e);
      const index = tasks.value.findIndex(t => t.fileMd5 === task.fileMd5);
      tasks.value[index].status = UploadStatus.Break;
    } finally {
      activeUploads.value.delete(task.fileMd5);
      startUpload();
    }
  }

  return {
    tasks,
    activeUploads,
    enqueueUpload,
    startUpload
  };
});
