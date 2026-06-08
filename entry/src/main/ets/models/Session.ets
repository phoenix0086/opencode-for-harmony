/**
 * Session 数据模型
 */
export interface Session {
  id: string
  projectId: string
  title: string
  agent: string
  model: string
  status: SessionStatus
  lastMessage?: string
  createdAt: number
  updatedAt: number
}

export type SessionStatus = 'idle' | 'running' | 'approval_required' | 'done' | 'error' | 'stopped'
