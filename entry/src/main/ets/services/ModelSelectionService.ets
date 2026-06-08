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

  async setDefaultModel(modelRef: string, runner: Runner | null): Promise<boolean> {
    const settings = await storageService.loadSettings()
    settings.defaultModel = modelRef
    await storageService.saveSettings(settings)

    if (runner !== null) {
      const client = new OpenCodeClient(runner)
      const patch: Record<string, Object> = {}
      patch['model'] = modelRef
      await client.updateConfig(patch)
    }

    return true
  }

  async setSmallModel(modelRef: string, runner: Runner | null): Promise<boolean> {
    const settings = await storageService.loadSettings()
    settings.defaultSmallModel = modelRef
    await storageService.saveSettings(settings)

    if (runner !== null) {
      const client = new OpenCodeClient(runner)
      const patch: Record<string, Object> = {}
      patch['small_model'] = modelRef
      await client.updateConfig(patch)
    }

    return true
  }

  async testModel(modelRef: string, runner: Runner | null): Promise<string> {
    if (runner === null) return 'OpenCode Server is not connected.'

    try {
      const client = new OpenCodeClient(runner)
      const session = await client.createSession(`model-test-${Date.now()}`)
      client.setDefaultAgent('build')
      await client.sendMessageAsync(session.id, 'Say OK.')
      return `Test prompt sent to ${modelRef}. Check session ${session.id}.`
    } catch (e) {
      return `Model test failed: ${String(e)}`
    }
  }
}

export const modelSelectionService = new ModelSelectionService()
