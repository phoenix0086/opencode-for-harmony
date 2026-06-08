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
      result.serverSynced = false
      result.message = `默认模型已保存到本地：${modelRef}。OpenCode Server 未连接，暂未同步到服务端。`
      return result
    }

    try {
      const client = new OpenCodeClient(runner)
      const patch: Record<string, Object> = {}
      patch['model'] = modelRef
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = `默认模型已保存并同步到 OpenCode Server：${modelRef}`
      return result
    } catch (e) {
      result.ok = false
      result.serverSynced = false
      result.message = `默认模型已保存到本地，但同步 OpenCode Server 失败：${String(e)}`
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
      result.serverSynced = false
      result.message = `Small Model 已保存到本地：${modelRef}。OpenCode Server 未连接，暂未同步到服务端。`
      return result
    }

    try {
      const client = new OpenCodeClient(runner)
      const patch: Record<string, Object> = {}
      patch['small_model'] = modelRef
      await client.updateConfig(patch)
      result.ok = true
      result.serverSynced = true
      result.message = `Small Model 已保存并同步到 OpenCode Server：${modelRef}`
      return result
    } catch (e) {
      result.ok = false
      result.serverSynced = false
      result.message = `Small Model 已保存到本地，但同步 OpenCode Server 失败：${String(e)}`
      return result
    }
  }

  async testModel(modelRef: string, runner: Runner | null): Promise<string> {
    if (runner === null) {
      return '无法测试模型：OpenCode Server 未连接。请先在“服务器”页连接 opencode serve，然后再测试小米或其他模型。'
    }

    try {
      const client = new OpenCodeClient(runner)

      // Make the tested model active before sending a tiny prompt.
      const patch: Record<string, Object> = {}
      patch['model'] = modelRef
      await client.updateConfig(patch)

      const session = await client.createSession(`model-test-${Date.now()}`)
      client.setDefaultAgent('build')
      await client.sendMessageAsync(session.id, 'Say OK.')
      return `测试请求已发送到 ${modelRef}。请查看会话 ${session.id} 的返回结果。`
    } catch (e) {
      return `模型测试失败：${String(e)}`
    }
  }
}

export const modelSelectionService = new ModelSelectionService()
