export enum SetupStoreId {
  App = 'app-store',
  Theme = 'theme-store',
  Auth = 'auth-store',
  Route = 'route-store',
  Tab = 'tab-store',
  Chat = 'chat-store',
  KnowledgeBase = 'knowledge-base-store'
}

/** 值对齐 PaiSmart 后端 FileUpload status: 0=UPLOADING 1=COMPLETED 2=MERGING */
export enum UploadStatus {
  Uploading = 0,   // PaiSmart 0: 上传中
  Completed = 1,   // PaiSmart 1: 已完成
  Merging = 2,     // PaiSmart 2: 合并中
  Pending = 3,     // 前端本地：排队等待
  Break = 4        // 前端本地：上传中断
}
