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
   * 使用字符串拼接避免 ArkTS 对象字面量限制
   */
  generateProviderConfig(providerId: string): string {
    const p = this.getById(providerId)
    if (!p || !p.enabled) return ''

    const modelsEntries: string[] = []
    for (const m of p.models) {
      modelsEntries.push(`      "${m.id}": {\n        "name": "${this.escapeJson(m.name)}"\n      }`)
    }
    const modelsStr = modelsEntries.join(',\n')

    return `{
  "${p.id}": {
    "npm": "${this.escapeJson(p.npm)}",
    "name": "${this.escapeJson(p.name)}",
    "options": {
      "baseURL": "${this.escapeJson(p.baseURL)}",
      "apiKey": "{env:${p.authEnv}}"
    },
    "models": {
${modelsStr}
    }
  }
}`
  }

  /**
   * 生成完整 opencode.json
   * 使用字符串拼接避免 ArkTS 对象字面量限制
   */
  generateFullConfig(defaultModel: string, smallModel: string): string {
    const providerEntries: string[] = []

    for (const p of this.getEnabled()) {
      const modelsEntries: string[] = []
      for (const m of p.models) {
        modelsEntries.push(`        "${m.id}": {\n          "name": "${this.escapeJson(m.name)}"\n        }`)
      }
      const modelsStr = modelsEntries.join(',\n')

      providerEntries.push(`    "${p.id}": {
      "npm": "${this.escapeJson(p.npm)}",
      "name": "${this.escapeJson(p.name)}",
      "options": {
        "baseURL": "${this.escapeJson(p.baseURL)}",
        "apiKey": "{env:${p.authEnv}}"
      },
      "models": {
${modelsStr}
      }
    }`)
    }

    const providersStr = providerEntries.join(',\n')

    return `{
  "$schema": "https://opencode.ai/config.json",
  "server": {
    "port": 4096,
    "hostname": "127.0.0.1"
  },
  "permission": {
    "bash": "ask",
    "edit": "ask",
    "write": "ask",
    "webfetch": "allow"
  },
  "model": "${this.escapeJson(defaultModel)}",
  "small_model": "${this.escapeJson(smallModel)}",
  "provider": {
${providersStr}
  },
  "autoupdate": false,
  "snapshot": true
}`
  }

  /**
   * JSON 字符串转义
   */
  private escapeJson(s: string): string {
    return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r')
  }

  async save(): Promise<void> {
    await storageService.saveProviders(this.providers)
  }
}

export const providerRegistry = new ProviderRegistry()
