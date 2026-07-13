import { request } from '../request';

export interface ChatMessage {
  role: string;
  content: string;
  timestamp: string;
  conversationId: string;
  referenceMappings?: Record<string, Record<string, any>>;
  username?: string;
}

export interface FetchChatHistoryParams {
  start_date?: string;
  end_date?: string;
}

/**
 * Fetch chat history with optional time range filter
 *
 * Backend: GET /api/v1/users/conversation
 */
export function fetchChatHistory(params: FetchChatHistoryParams = {}) {
  const requestParams: Record<string, string> = {};

  if (params.start_date) {
    requestParams.start_date = params.start_date;
  }
  if (params.end_date) {
    requestParams.end_date = params.end_date;
  }

  return request<ChatMessage[]>({
    url: '/users/conversation',
    params: requestParams
  });
}
