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
      const patch: Record<string, Object> = {}
      patch['model'] = modelRef
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = `默认模型已同步：${modelRef}`
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
      const patch: Record<string, Object> = {}
      patch['small_model'] = modelRef
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = `Small Model 已同步：${modelRef}`
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
      const patch: Record<string, Object> = {}
      patch['model'] = modelRef
      await client.updateConfig(patch)

      const session = await client.createSession(`model-test-${Date.now()}`)
      client.setDefaultAgent('build')
      await client.sendMessageAsync(session.id, 'Say OK.')
      return `测试请求已发送到 ${modelRef}。请查看会话 ${session.id}。`
    } catch (e) {
      return `模型测试失败：${String(e)}`
    }
  }
}

export const modelSelectionService = new ModelSelectionService()
