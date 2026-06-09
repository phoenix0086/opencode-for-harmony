import { OpenCodeClient } from './OpenCodeClient'

export class AgentPollResult {
  ok: boolean = false
  timedOut: boolean = false
  message: string = ''
  messageCount: number = 0
}

export class AgentResponsePoller {
  async waitForAssistant(
    client: OpenCodeClient,
    sessionId: string,
    beforeCount: number,
    maxAttempts: number = 90,
    intervalMs: number = 1000
  ): Promise<AgentPollResult> {
    const result = new AgentPollResult()

    for (let i = 0; i < maxAttempts; i++) {
      await this.delay(intervalMs)
      try {
        const raw = await client.getMessagesRaw(sessionId)
        result.messageCount = raw.length

        if (raw.length > beforeCount) {
          let foundAssistant = false
          let foundError = false
          for (let j = beforeCount; j < raw.length; j++) {
            if (raw[j].info.role === 'assistant') {
              foundAssistant = true
              break
            }
            for (const p of raw[j].parts) {
              if (p.type === 'error') {
                foundError = true
                break
              }
            }
            if (foundError) {
              break
            }
          }

          if (foundAssistant) {
            result.ok = true
            result.message = 'assistant response received'
            return result
          }
          if (foundError) {
            result.message = 'Runtime 返回 error message，请打开 logs 查看 provider/model/API Key 错误。'
            return result
          }
        }
      } catch (e) {
        result.message = `轮询消息失败：${String(e)}`
        return result
      }
    }

    result.timedOut = true
    result.message = '等待 assistant 回复超时。用户消息可能已发出，但模型调用没有完成。请检查 config.model、provider auth、Runtime 日志。'
    return result
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms)
    })
  }
}

export const agentResponsePoller = new AgentResponsePoller()
