declare namespace Api {
  /**
   * namespace KnowledgeBase
   *
   * backend api module: "knowledge-base"
   */
  namespace KnowledgeBase {
    interface SearchParams {
      userId: string;
      query: string;
      topK: number;
    }

    interface SearchResult {
      fileMd5: string;
      chunkId: number;
      textContent: string;
      score: number;
      fileName: string;
    }

    interface UploadState {
      tasks: UploadTask[];
      activeUploads: Set<string>;
    }

    interface Form {
      orgTag: string | null;
      orgTagName: string | null;
      uploadMaxSizeBytes?: number | null;
      uploadMaxSizeMb?: number | null;
      isPublic: boolean;
      fileList?: import('naive-ui').UploadFileInfo[];
    }

    interface UploadTask {
      id?: number;
      file?: File;
      chunk: Blob | null;
      fileMd5: string;
      chunkIndex: number;
      totalSize: number;
      fileName: string;
      userId?: number;
      orgTag: string | null;
      orgTagName?: string | null;
      public: boolean;
      isPublic: boolean;
      uploadedChunks: number[];
      progress: number;
      status: import('@/enum').UploadStatus;
      estimatedEmbeddingTokens?: number;
      estimatedChunkCount?: number;
      actualEmbeddingTokens?: number;
      actualChunkCount?: number;
      vectorizationStatus?: 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED' | null;
      vectorizationErrorMessage?: string | null;
      createdAt?: string;
      mergedAt?: string;
      requestIds?: string[];
    }

    type List = Common.PaginatingQueryRecord<UploadTask>;

    type Merge = Pick<UploadTask, 'fileMd5' | 'fileName'>;

    interface Progress {
      uploaded: number[];
      progress: number;
      totalChunks: number;
    }

    interface MergeResult {
      objectUrl: string;
      estimatedEmbeddingTokens?: number;
      estimatedChunkCount?: number;
    }
  }
}
