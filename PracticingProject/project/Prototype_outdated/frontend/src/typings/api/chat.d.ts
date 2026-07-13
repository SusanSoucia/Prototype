declare namespace Api {
  /**
   * namespace Chat
   *
   * backend api module: "chat"
   */
  namespace Chat {
    type GenerationStatus = 'STREAMING' | 'COMPLETED' | 'FAILED' | 'CANCELLED';

    interface ReferenceEvidence {
      fileMd5: string;
      fileName: string;
      pageNumber?: number | null;
      anchorText?: string | null;
      retrievalMode?: 'HYBRID' | 'TEXT_ONLY' | null;
      retrievalLabel?: string | null;
      retrievalQuery?: string | null;
      matchedChunkText?: string | null;
      evidenceSnippet?: string | null;
      score?: number | null;
      chunkId?: number | null;
    }

    interface Input {
      message: string;
      conversationId?: string;
    }

    interface Output {
      chunk: string;
    }

    interface AgentToolEvent {
      id?: string;
      tool: string;
      status: 'executing' | 'success' | 'failed';
      timestamp?: number;
    }

    interface Conversation {
      conversationId: string;
    }

    interface Message {
      role: 'user' | 'assistant';
      content: string;
      status?: 'pending' | 'loading' | 'finished' | 'error';
      timestamp?: string;
      conversationId?: string;
      generationId?: string;
      username?: string;
      referenceMappings?: Record<string, ReferenceEvidence>;
      toolEvents?: AgentToolEvent[];
      feedbackRating?: 'good' | 'bad';
    }

    interface Token {
      cmdToken: string;
    }

    interface GenerationSnapshot {
      generationId: string;
      userId: string;
      conversationId: string;
      question: string;
      status: GenerationStatus;
      content?: string;
      createdAt: string;
      updatedAt: string;
      errorMessage?: string;
      referenceMappings?: Record<string, ReferenceEvidence>;
      toolEvents?: AgentToolEvent[];
    }

    interface ConversationSession {
      id: number;
      conversationId: string;
      title: string;
      status: 'ACTIVE' | 'ARCHIVED';
      createdAt: string;
      updatedAt: string;
    }
  }
}
