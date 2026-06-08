/**
 * Project 数据模型
 */
export interface Project {
  id: string
  name: string
  path: string
  branch?: string
  status: 'idle' | 'running' | 'approval_required' | 'error'
  pendingApprovals: number
  runningSessions: number
  lastSessionId?: string
  updatedAt: number
}
