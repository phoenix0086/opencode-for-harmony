/**
 * Represents a single chat message in a conversation.
 */
export enum MessageRole {
  User = 'user',
  Assistant = 'assistant',
  System = 'system'
}

export enum MessageStatus {
  Pending = 'pending',
  Streaming = 'streaming',
  Complete = 'complete',
  Error = 'error'
}

export class ToolCall {
  id: string = '';
  name: string = '';
  arguments: string = '';
  result: string = '';
  status: string = 'pending'; // 'pending' | 'running' | 'complete' | 'error'
}

export class ChatMessage {
  id: string = '';
  role: MessageRole = MessageRole.User;
  content: string = '';
  timestamp: number = 0;
  status: MessageStatus = MessageStatus.Complete;
  sessionId: string = '';
  toolCalls: ToolCall[] = [];
  isError: boolean = false;
  isStreaming: boolean = false;

  static createUserMessage(content: string): ChatMessage {
    const msg = new ChatMessage();
    msg.id = generateId();
    msg.role = MessageRole.User;
    msg.content = content;
    msg.timestamp = Date.now();
    msg.status = MessageStatus.Complete;
    return msg;
  }

  static createAssistantMessage(): ChatMessage {
    const msg = new ChatMessage();
    msg.id = generateId();
    msg.role = MessageRole.Assistant;
    msg.content = '';
    msg.timestamp = Date.now();
    msg.status = MessageStatus.Streaming;
    msg.isStreaming = true;
    return msg;
  }

  static createSystemMessage(content: string): ChatMessage {
    const msg = new ChatMessage();
    msg.id = generateId();
    msg.role = MessageRole.System;
    msg.content = content;
    msg.timestamp = Date.now();
    msg.status = MessageStatus.Complete;
    return msg;
  }

  appendContent(delta: string): void {
    this.content += delta;
  }

  finalize(): void {
    this.isStreaming = false;
    this.status = MessageStatus.Complete;
  }

  setError(message: string): void {
    this.isError = true;
    this.isStreaming = false;
    this.status = MessageStatus.Error;
    this.content = message;
  }
}

let idCounter: number = 0;

function generateId(): string {
  idCounter++;
  return 'msg_' + Date.now().toString() + '_' + idCounter.toString();
}
