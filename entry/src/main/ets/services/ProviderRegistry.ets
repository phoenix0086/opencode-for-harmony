import { CNProvider, CNModel, createDefaultProviders, ProviderGenerateInput } from '../models/Provider'
import { storageService } from './StorageService'

/**
 * CN Provider 注册表服务
 * 管理国内大模型供应商的注册、启用、配置
 */
export class ProviderRegistry {
  private providers: CNProvider[] = []

  async init(): Promise<void> {
    const saved = await storageService.loadProviders()
    if (saved.length > 0) {
      this.providers = saved
    } else {
      this.providers = createDefaultProviders()
      // 默认启用前三个
      if (this.providers.length > 0) this.providers[0].enabled = true
      if (this.providers.length > 1) this.providers[1].enabled = true
      if (this.providers.length > 2) this.providers[2].enabled = true
      await this.save()
    }
  }

  getAll(): CNProvider[] {
    return this.providers
  }

  getEnabled(): CNProvider[] {
    const result: CNProvider[] = []
    for (const p of this.providers) {
      if (p.enabled) result.push(p)
    }
    return result
  }

  getById(id: string): CNProvider | undefined {
    for (const p of this.providers) {
      if (p.id === id) return p
    }
    return undefined
  }

  enable(providerId: string): void {
    const p = this.getById(providerId)
    if (p) p.enabled = true
  }

  disable(providerId: string): void {
    const p = this.getById(providerId)
    if (p) p.enabled = false
  }

  setAuthStatus(providerId: string, status: string): void {
    const p = this.getById(providerId)
    if (p) p.authStatus = status
  }

  setCustomBaseURL(providerId: string, url: string): void {
    const p = this.getById(providerId)
    if (p) p.baseURL = url
  }

  addCustomModel(providerId: string, model: CNModel): void {
    const p = this.getById(providerId)
    if (p) {
      p.models.push(model)
    }
  }

  getRecommendedModel(providerId: string): string {
    const p = this.getById(providerId)
    if (!p) return ''
    for (const m of p.models) {
      if (m.recommended) return `${p.id}/${m.id}`
    }
    if (p.models.length > 0) return `${p.id}/${p.models[0].id}`
    return ''
  }

  /**
   * 生成 opencode.json provider 配置片段
   */
  generateProviderConfig(providerId: string): string {
    const p = this.getById(providerId)
    if (!p || !p.enabled) return ''

    const modelsObj: Record<string, Object> = {}
    for (const m of p.models) {
      modelsObj[m.id] = { name: m.name }
    }

    const providerEntry: Record<string, Object> = {
      npm: p.npm,
      name: p.name,
      options: {
        baseURL: p.baseURL,
        apiKey: `{env:${p.authEnv}}`
      },
      models: modelsObj
    }

    return JSON.stringify({ [p.id]: providerEntry }, null, 2)
  }

  /**
   * 生成完整 opencode.json
   */
  generateFullConfig(defaultModel: string, smallModel: string): string {
    const providersMap: Record<string, Object> = {}

    for (const p of this.getEnabled()) {
      const modelsObj: Record<string, Object> = {}
      for (const m of p.models) {
        modelsObj[m.id] = { name: m.name }
      }
      providersMap[p.id] = {
        npm: p.npm,
        name: p.name,
        options: {
          baseURL: p.baseURL,
          apiKey: `{env:${p.authEnv}}`
        },
        models: modelsObj
      }
    }

    const config: Record<string, Object> = {
      '$schema': 'https://opencode.ai/config.json',
      server: {
        port: 4096,
        hostname: '127.0.0.1'
      },
      permission: {
        bash: 'ask',
        edit: 'ask',
        write: 'ask',
        webfetch: 'allow'
      },
      model: defaultModel,
      small_model: smallModel,
      provider: providersMap,
      autoupdate: false,
      snapshot: true
    }

    return JSON.stringify(config, null, 2)
  }

  async save(): Promise<void> {
    await storageService.saveProviders(this.providers)
  }
}

export const providerRegistry = new ProviderRegistry()
