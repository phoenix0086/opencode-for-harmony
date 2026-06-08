/**
 * Approval 数据模型
 */
export interface Approval {
  id: string
  sessionId: string
  toolCallId?: string
  type: 'edit' | 'write' | 'delete' | 'bash' | 'git' | 'network' | 'dependency'
  title: string
  description: string
  riskLevel: 'low' | 'medium' | 'high'
  status: 'pending' | 'approved' | 'rejected' | 'expired'
  createdAt: number
}
