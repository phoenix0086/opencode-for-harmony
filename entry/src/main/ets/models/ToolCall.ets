/**
 * ToolCall 数据模型
 */
export interface ToolCall {
  id: string
  sessionId: string
  name: string
  status: ToolCallStatus
  inputSummary: string
  outputSummary?: string
  riskLevel: 'low' | 'medium' | 'high'
  startedAt?: number
  endedAt?: number
}

export type ToolCallStatus = 'pending' | 'running' | 'success' | 'error' | 'approval_required' | 'cancelled'
