import { Runner } from '../models/Runner'
import { providerRegistry } from './ProviderRegistry'
import { storageService } from './StorageService'
import { OpenCodeClient } from './OpenCodeClient'

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
      result.message = `默认模型已本地保存，但同步失败：${String(e)}`
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
      result.message = `Small Model 已本地保存，但同步失败：${String(e)}`
      return result
    }
  }

  async testModel(modelRef: string, runner: Runner | null): Promise<string> {
    if (runner === null) return '无法测试模型：本地 Runtime 未连接。请先到"本地 Runtime"页面连接。'

    try {
      const client = new OpenCodeClient(runner)
      const resolved = await this.resolveServerModelRef(modelRef, runner)
      const patch: Record<string, Object> = {}
      patch['model'] = resolved
      await client.updateConfig(patch)

      const session = await client.createSession(`model-test-${Date.now()}`)
      client.setDefaultAgent('build')
      await client.sendMessageAsync(session.id, 'Say OK.')
      const suffix = resolved === modelRef ? '' : ` (已映射到 server: ${resolved})`
      return `测试请求已发送到 ${modelRef}${suffix}。请查看会话 ${session.id}。`
    } catch (e) {
      return `模型测试失败：${String(e)}`
    }
  }
}

export const modelSelectionService = new ModelSelectionService()
