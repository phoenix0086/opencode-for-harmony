import { WithParts, RawPart } from '../models/Event'

export class AgentExecutionSnapshot {
  hasAssistant: boolean = false
  hasTool: boolean = false
  hasError: boolean = false
  hasPermission: boolean = false
  errorText: string = ''
  toolCount: number = 0
  permissionCount: number = 0
  newMessageCount: number = 0
}

/**
 * Runtime message inspector.
 *
 * This deliberately avoids assuming a single exact part schema. OpenCode
 * versions may emit parts such as:
 *
 * - text
 * - tool-invocation
 * - tool
 * - step-start / step-finish
 * - error
 * - permission
 */
export class AgentExecutionInspector {
  inspect(raw: WithParts[], beforeCount: number): AgentExecutionSnapshot {
    const s = new AgentExecutionSnapshot()

    if (!raw || raw.length <= beforeCount) {
      return s
    }

    s.newMessageCount = raw.length - beforeCount

    for (let i = beforeCount; i < raw.length; i++) {
      const item = raw[i]
      const info = item.info
      const role = info ? info.role : ''

      if (role === 'assistant') {
        s.hasAssistant = true
      }

      const parts = item.parts || []
      for (const p of parts) {
        const type = p.type
        const text = this.extractPartText(p)

        if (this.isToolType(type)) {
          s.hasTool = true
          s.toolCount += 1
        }

        if (this.isPermissionType(type)) {
          s.hasPermission = true
          s.permissionCount += 1
        }

        if (this.isErrorType(type)) {
          s.hasError = true
          if (text.length > 0 && s.errorText.length === 0) {
            s.errorText = text
          }
        }

        if (!s.hasError && this.looksLikeError(text)) {
          s.hasError = true
          s.errorText = text
        }
      }
    }

    return s
  }

  private isToolType(type: string): boolean {
    return type === 'tool-invocation'
      || type === 'tool'
      || type === 'step-start'
      || type === 'step-finish'
      || type === 'tool-call'
      || type === 'tool-result'
  }

  private isPermissionType(type: string): boolean {
    return type === 'permission'
      || type === 'permission-request'
      || type === 'tool-permission'
  }

  private isErrorType(type: string): boolean {
    return type === 'error'
      || type === 'tool-error'
      || type === 'provider-error'
  }

  private extractPartText(p: RawPart): string {
    if (p.text.length > 0) return p.text
    const state = p.state || {}
    const msg = state['message']
    if (typeof msg === 'string' && msg.length > 0) return msg
    const err = state['error']
    if (typeof err === 'string' && err.length > 0) return err
    const out = state['output']
    if (typeof out === 'string' && out.length > 0) return out
    return ''
  }

  private looksLikeError(text: string): boolean {
    if (text.length === 0) return false
    const t = text.toLowerCase()
    return t.includes('error')
      || t.includes('exception')
      || t.includes('api key')
      || t.includes('auth')
      || t.includes('unauthorized')
      || t.includes('provider')
      || t.includes('model not found')
      || t.includes('invalid model')
  }
}

export const agentExecutionInspector = new AgentExecutionInspector()
