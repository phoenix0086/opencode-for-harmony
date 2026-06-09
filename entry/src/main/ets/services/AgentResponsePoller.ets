import { OpenCodeClient } from './OpenCodeClient'
import { agentExecutionInspector, AgentExecutionSnapshot } from './AgentExecutionInspector'

export class AgentPollResult {
  ok: boolean = false
  timedOut: boolean = false
  hasAssistant: boolean = false
  hasTool: boolean = false
  hasError: boolean = false
  hasPermission: boolean = false
  message: string = ''
  messageCount: number = 0
  snapshot: AgentExecutionSnapshot = new AgentExecutionSnapshot()
}

/**
 * Waits for Runtime execution after prompt_async.
 *
 * prompt_async only means the request was accepted. It does not mean the
 * assistant finished. This poller turns async execution into a UI-visible
 * closed loop:
 *
 * prompt_async -> poll messages -> assistant/tool/error/permission -> refresh UI.
 */
export class AgentResponsePoller {
  async waitForExecution(
    client: OpenCodeClient,
    sessionId: string,
    beforeCount: number,
    maxAttempts: number = 120,
    intervalMs: number = 1000
  ): Promise<AgentPollResult> {
    const result = new AgentPollResult()

    for (let i = 0; i < maxAttempts; i++) {
      await this.delay(intervalMs)

      try {
        const raw = await client.getMessagesRaw(sessionId)
        result.messageCount = raw.length

        const snapshot = agentExecutionInspector.inspect(raw, beforeCount)
        result.snapshot = snapshot
        result.hasAssistant = snapshot.hasAssistant
        result.hasTool = snapshot.hasTool
        result.hasError = snapshot.hasError
        result.hasPermission = snapshot.hasPermission

        if (snapshot.hasError) {
          result.ok = false
          result.message = snapshot.errorText.length > 0
            ? snapshot.errorText
            : 'Runtime 返回 error message，请查看 Chat 错误块或右侧 Logs。'
          return result
        }

        if (snapshot.hasPermission) {
          result.ok = true
          result.message = 'Runtime 正在等待权限确认。'
          return result
        }

        if (snapshot.hasTool) {
          result.ok = true
          result.message = 'Runtime 已开始工具调用。'
          return result
        }

        if (snapshot.hasAssistant) {
          result.ok = true
          result.message = 'assistant response received'
          return result
        }
      } catch (e) {
        result.ok = false
        result.message = `轮询消息失败：${String(e)}`
        return result
      }
    }

    result.ok = false
    result.timedOut = true
    result.message = '等待 assistant/tool/error/permission 超时。用户消息可能已进入 session，但模型调用或 Runtime 执行没有完成。'
    return result
  }

  async waitForAssistant(
    client: OpenCodeClient,
    sessionId: string,
    beforeCount: number,
    maxAttempts: number = 90,
    intervalMs: number = 1000
  ): Promise<AgentPollResult> {
    return this.waitForExecution(client, sessionId, beforeCount, maxAttempts, intervalMs)
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms)
    })
  }
}

export const agentResponsePoller = new AgentResponsePoller()
