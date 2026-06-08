/**
 * Message 数据模型
 */
export interface Message {
  id: string
  sessionId: string
  role: 'user' | 'assistant' | 'system' | 'tool'
  content: string
  createdAt: number
}
