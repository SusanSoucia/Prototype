declare namespace Api {
  namespace Document {
    interface DownloadResponse {
      fileName: string;
      downloadURL: string;
      fileSize: number;
      fileMd5?: string;
    }

    interface ReferenceDetailResponse extends Chat.ReferenceEvidence {
      referenceNumber: number;
    }
  }
}
