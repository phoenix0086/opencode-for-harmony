import { Runner } from '../models/Runner'
import { providerRegistry } from './ProviderRegistry'
import { storageService } from './StorageService'
import { OpenCodeClient } from './OpenCodeClient'
import { agentResponsePoller } from './AgentResponsePoller'
import { errStr } from '../utils/ErrorUtil'

export class ModelOption {
  providerId: string = ''
  providerName: string = ''
  modelId: string = ''
  modelName: string = ''
  modelRef: string = ''
}

export class ModelSelectionResult {
  ok: boolean = false
  localSaved: boolean = false
  serverSynced: boolean = false
  message: string = ''
}

export class ModelSelectionService {
  async listAvailableModels(): Promise<ModelOption[]> {
    await providerRegistry.init()
    const result: ModelOption[] = []

    for (const p of providerRegistry.getEnabled()) {
      for (const m of p.models) {
        if (m.enabled === false) continue
        const opt = new ModelOption()
        opt.providerId = p.id
        opt.providerName = p.name
        opt.modelId = m.id
        opt.modelName = m.name.length > 0 ? m.name : m.id
        opt.modelRef = `${p.id}/${m.id}`
        result.push(opt)
      }
    }

    return result
  }

  async getDefaultModel(): Promise<string> {
    const settings = await storageService.loadSettings()
    return settings.defaultModel
  }

  async getSmallModel(): Promise<string> {
    const settings = await storageService.loadSettings()
    return settings.defaultSmallModel
  }

  /**
   * Resolve a local modelRef like "xiaomi-mimo/mimo-v2.5-pro" to the server-side.
   * Match by both provider id and model id — exact match only.
   * 不要自动 fallback 到 anthropic。如果 provider 没同步，保留 localRef。
   */
  async resolveServerModelRef(localRef: string, runner: Runner | null): Promise<string> {
    if (runner === null) return localRef
    const slash = localRef.indexOf('/')
    if (slash < 0) return localRef

    const providerId = localRef.substring(0, slash)
    const modelId = localRef.substring(slash + 1)
    if (providerId.length === 0 || modelId.length === 0) return localRef

    try {
      const client = new OpenCodeClient(runner)
      const list = await client.listProviders()

      for (const p of list.all) {
        if (p.id !== providerId) continue
        for (const m of p.models) {
          if (m.id === modelId) {
            return `${p.id}/${m.id}`
          }
        }
      }

      // 不要自动 fallback 到 anthropic。
      // 如果 provider 没同步，保留 localRef，让 updateConfig/prompt 暴露真实错误。
      return localRef
    } catch {
      return localRef
    }
  }

  async setDefaultModel(modelRef: string, runner: Runner | null): Promise<ModelSelectionResult> {
    const result = new ModelSelectionResult()
    const settings = await storageService.loadSettings()
    settings.defaultModel = modelRef
    await storageService.saveSettings(settings)
    result.localSaved = true

    if (runner === null) {
      result.ok = true
      result.message = `默认模型已保存到本地：${modelRef}。Runtime 未连接，暂未同步。`
      return result
    }

    try {
      const client = new OpenCodeClient(runner)
      const resolved = await this.resolveServerModelRef(modelRef, runner)
      const patch: Record<string, Object> = {}
      patch['model'] = resolved
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = resolved === modelRef
        ? `默认模型已同步：${modelRef}`
        : `默认模型已同步：${modelRef} (→ server: ${resolved})`
      return result
    } catch (e) {
      result.ok = false
      result.message = `默认模型已本地保存，但同步失败：${errStr(e)}`
      return result
    }
  }

  async setSmallModel(modelRef: string, runner: Runner | null): Promise<ModelSelectionResult> {
    const result = new ModelSelectionResult()
    const settings = await storageService.loadSettings()
    settings.defaultSmallModel = modelRef
    await storageService.saveSettings(settings)
    result.localSaved = true

    if (runner === null) {
      result.ok = true
      result.message = `Small Model 已保存到本地：${modelRef}。Runtime 未连接，暂未同步。`
      return result
    }

    try {
      const client = new OpenCodeClient(runner)
      const resolved = await this.resolveServerModelRef(modelRef, runner)
      const patch: Record<string, Object> = {}
      patch['small_model'] = resolved
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = resolved === modelRef
        ? `Small Model 已同步：${modelRef}`
        : `Small Model 已同步：${modelRef} (→ server: ${resolved})`
      return result
    } catch (e) {
      result.ok = false
      result.message = `Small Model 已本地保存，但同步失败：${errStr(e)}`
      return result
    }
  }

  /**
   * M14: Drive the model test to completion.
   *
   * Old behavior only proved "prompt_async was sent" — it could not tell
   * whether the model actually replied. We now:
   *   1. resolve modelRef against server provider list
   *   2. PATCH /config so subsequent prompts go to the tested model
   *   3. create a fresh session
   *   4. prompt_async with "Say OK."
   *   5. waitForExecution (assistant | tool | error | permission | timeout)
   *
   * Result is one of three classes the UI surfaces explicitly:
   *   成功：assistant returned
   *   失败：Runtime error: <errorText>
   *   超时：poll timeout
   */
  async testModel(modelRef: string, runner: Runner | null): Promise<string> {
    if (runner === null) return '无法测试模型：本地 Runtime 未连接。请先到"本地 Runtime"页面连接。'

    let client: OpenCodeClient
    let resolved: string
    let sessionId: string
    try {
      client = new OpenCodeClient(runner)
      resolved = await this.resolveServerModelRef(modelRef, runner)
      const patch: Record<string, Object> = {}
      patch['model'] = resolved
      await client.updateConfig(patch)

      const session = await client.createSession(`model-test-${Date.now()}`)
      sessionId = session.id
      client.setDefaultAgent('build')
      const sent = await client.sendMessageAsync(sessionId, 'Say OK.')
      if (!sent) {
        return `模型测试失败：prompt_async 返回失败 (${modelRef})。请检查 Runtime 日志。`
      }

      const before = await client.getMessagesRaw(sessionId)
      const beforeCount = before.length

      // Wait up to ~30s for assistant / error / permission. Test probes are
      // tiny prompts, so the long prod timeout (120 × 1s) is wasteful here.
      const poll = await agentResponsePoller.waitForExecution(
        client,
        sessionId,
        beforeCount,
        30,
        1000
      )

      const suffix = resolved === modelRef ? '' : ` (已映射到 server: ${resolved})`
      if (poll.ok) {
        if (poll.hasAssistant) {
          return `模型测试成功：assistant returned — ${modelRef}${suffix}`
        }
        if (poll.hasError) {
          return `模型测试失败：Runtime error — ${poll.snapshot.errorText.length > 0 ? poll.snapshot.errorText : '未知错误'} (${modelRef}${suffix})`
        }
        if (poll.hasTool) {
          return `模型测试成功：触发了工具调用 (${modelRef}${suffix})`
        }
        if (poll.hasPermission) {
          return `模型测试需要权限：${modelRef}${suffix}`
        }
        return `模型测试完成，但未识别到明确结果 (${modelRef}${suffix})`
      }
      if (poll.timedOut) {
        return `模型测试超时：Runtime 没有返回 (${modelRef}${suffix})。请检查 Provider 配置或 Runtime 日志。`
      }
      return `模型测试失败：${poll.message.length > 0 ? poll.message : 'unknown'} (${modelRef}${suffix})`
    } catch (e) {
      return `模型测试失败：${errStr(e)}`
    }
  }
}

export const modelSelectionService = new ModelSelectionService()
