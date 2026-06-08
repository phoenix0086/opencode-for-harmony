import { CNProvider, CNModel, ProviderHeader, createDefaultProviders } from '../models/Provider'
import { storageService } from './StorageService'

/**
 * OpenCode Provider registry.
 *
 * Responsibilities:
 * - Merge built-in providers with saved user customizations.
 * - Persist Base URL, API Key mode, direct API Key, headers, and model list.
 * - Generate OpenCode-compatible config JSON.
 * - Provide a single source of truth for Provider and Model pages.
 */
export class ProviderRegistry {
  private providers: CNProvider[] = []

  async init(): Promise<void> {
    const defaults = createDefaultProviders()
    const saved = await storageService.loadProviders()
    if (saved.length === 0) {
      this.providers = defaults
      if (this.providers.length > 0) this.providers[0].enabled = true
      if (this.providers.length > 1) this.providers[1].enabled = true
      await this.save()
      return
    }

    const merged: CNProvider[] = []
    for (const d of defaults) {
      const s = this.findProvider(saved, d.id)
      if (s) {
        merged.push(this.mergeProvider(d, s))
      } else {
        merged.push(d)
      }
    }

    // Preserve user-created providers that are not part of defaults.
    for (const s of saved) {
      if (!this.findProvider(merged, s.id)) {
        merged.push(this.normalizeProvider(s))
      }
    }
    this.providers = merged
  }

  private findProvider(list: CNProvider[], id: string): CNProvider | undefined {
    for (const p of list) {
      if (p.id === id) return p
    }
    return undefined
  }

  private normalizeProvider(raw: CNProvider): CNProvider {
    const p = new CNProvider()
    p.id = raw.id || ''
    p.name = raw.name || raw.id || 'Provider'
    p.npm = raw.npm || '@ai-sdk/openai-compatible'
    p.baseURL = raw.baseURL || ''
    p.authEnv = raw.authEnv || 'CUSTOM_API_KEY'
    p.authMode = raw.authMode || 'apiKey'
    p.apiKeyMode = raw.apiKeyMode || 'direct'
    p.apiKey = raw.apiKey || ''
    p.apiKeyRef = raw.apiKeyRef || raw.authEnv || 'CUSTOM_API_KEY'
    p.headers = raw.headers || []
    p.models = raw.models || []
    p.enabled = raw.enabled === true
    p.authStatus = raw.authStatus || (p.apiKey.length > 0 ? 'configured' : 'missing')
    p.builtIn = raw.builtIn !== false
    p.notes = raw.notes || ''
    return p
  }

  private mergeProvider(base: CNProvider, saved: CNProvider): CNProvider {
    const p = this.normalizeProvider(base)
    p.enabled = saved.enabled === true
    p.baseURL = saved.baseURL || base.baseURL
    p.authEnv = saved.authEnv || base.authEnv
    p.apiKeyMode = saved.apiKeyMode || 'direct'
    p.apiKey = saved.apiKey || ''
    p.authStatus = saved.authStatus || (p.apiKey.length > 0 ? 'configured' : 'missing')
    p.headers = saved.headers || []

    // Saved model list wins when the user added custom models.
    if (saved.models && saved.models.length > 0) {
      p.models = saved.models
    }
    return p
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
    return this.findProvider(this.providers, id)
  }

  enable(providerId: string): void {
    const p = this.getById(providerId)
    if (p) p.enabled = true
  }

  disable(providerId: string): void {
    const p = this.getById(providerId)
    if (p) p.enabled = false
  }

  async setProviderEnabled(providerId: string, enabled: boolean): Promise<void> {
    if (enabled) this.enable(providerId)
    else this.disable(providerId)
    await this.save()
  }

  async setProviderConfig(providerId: string, name: string, baseURL: string, npm: string, authEnv: string): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p) return false
    p.name = name.length > 0 ? name : p.name
    p.baseURL = baseURL
    p.npm = npm.length > 0 ? npm : '@ai-sdk/openai-compatible'
    p.authEnv = authEnv.length > 0 ? authEnv : p.authEnv
    p.apiKeyRef = p.authEnv
    await this.save()
    return true
  }

  async setApiKey(providerId: string, apiKey: string, mode: string): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p) return false
    p.apiKeyMode = mode === 'env' ? 'env' : 'direct'
    p.apiKey = apiKey
    p.authStatus = apiKey.length > 0 || p.apiKeyMode === 'env' ? 'configured' : 'missing'
    await this.save()
    return true
  }

  async addOrUpdateHeader(providerId: string, name: string, value: string): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p || name.length === 0) return false
    let found = false
    for (const h of p.headers) {
      if (h.name === name) {
        h.value = value
        found = true
      }
    }
    if (!found) {
      const h = new ProviderHeader()
      h.name = name
      h.value = value
      p.headers.push(h)
    }
    await this.save()
    return true
  }

  async removeHeader(providerId: string, name: string): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    const kept: ProviderHeader[] = []
    for (const h of p.headers) {
      if (h.name !== name) kept.push(h)
    }
    p.headers = kept
    await this.save()
  }

  async addOrUpdateModel(providerId: string, modelId: string, displayName: string, coding: boolean = true): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p || modelId.length === 0) return false
    let found = false
    for (const m of p.models) {
      if (m.id === modelId) {
        m.name = displayName.length > 0 ? displayName : modelId
        m.coding = coding
        m.enabled = true
        found = true
      }
    }
    if (!found) {
      const m = new CNModel()
      m.id = modelId
      m.name = displayName.length > 0 ? displayName : modelId
      m.coding = coding
      m.enabled = true
      p.models.push(m)
    }
    await this.save()
    return true
  }

  async removeModel(providerId: string, modelId: string): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    const kept: CNModel[] = []
    for (const m of p.models) {
      if (m.id !== modelId) kept.push(m)
    }
    p.models = kept
    await this.save()
  }

  async setModelEnabled(providerId: string, modelId: string, enabled: boolean): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    for (const m of p.models) {
      if (m.id === modelId) m.enabled = enabled
    }
    await this.save()
  }

  async createCustomProvider(id: string, name: string, baseURL: string, apiKey: string, modelId: string): Promise<boolean> {
    if (id.length === 0 || this.getById(id)) return false
    const p = new CNProvider()
    p.id = id
    p.name = name.length > 0 ? name : id
    p.baseURL = baseURL
    p.npm = '@ai-sdk/openai-compatible'
    p.authEnv = `${this.toEnvPrefix(id)}_API_KEY`
    p.apiKeyRef = p.authEnv
    p.apiKeyMode = 'direct'
    p.apiKey = apiKey
    p.enabled = true
    p.builtIn = false
    p.authStatus = apiKey.length > 0 ? 'configured' : 'missing'
    if (modelId.length > 0) {
      const m = new CNModel()
      m.id = modelId
      m.name = modelId
      m.coding = true
      m.recommended = true
      p.models.push(m)
    }
    this.providers.push(p)
    await this.save()
    return true
  }

  getRecommendedModel(providerId: string): string {
    const p = this.getById(providerId)
    if (!p) return ''
    for (const m of p.models) {
      if (m.enabled !== false && m.recommended) return `${p.id}/${m.id}`
    }
    for (const m of p.models) {
      if (m.enabled !== false) return `${p.id}/${m.id}`
    }
    return ''
  }

  getAllModelRefs(): string[] {
    const refs: string[] = []
    for (const p of this.providers) {
      if (!p.enabled) continue
      for (const m of p.models) {
        if (m.enabled !== false) refs.push(`${p.id}/${m.id}`)
      }
    }
    return refs
  }

  private apiKeyExpression(p: CNProvider): string {
    if (p.apiKeyMode === 'env') return `{env:${p.authEnv}}`
    return p.apiKey
  }

  private headersConfig(p: CNProvider): string {
    const entries: string[] = []
    for (const h of p.headers) {
      if (h.name.length > 0) {
        entries.push(`        "${this.escapeJson(h.name)}": "${this.escapeJson(h.value)}"`)
      }
    }
    if (entries.length === 0) return ''
    return `,\n      "headers": {\n${entries.join(',\n')}\n      }`
  }

  generateFullConfig(defaultModel: string, smallModel: string): string {
    const providerEntries: string[] = []
    for (const p of this.getEnabled()) {
      const modelEntries: string[] = []
      for (const m of p.models) {
        if (m.enabled === false) continue
        modelEntries.push(`        "${this.escapeJson(m.id)}": {\n          "name": "${this.escapeJson(m.name)}"\n        }`)
      }
      providerEntries.push(`    "${this.escapeJson(p.id)}": {\n      "npm": "${this.escapeJson(p.npm)}",\n      "name": "${this.escapeJson(p.name)}",\n      "options": {\n        "baseURL": "${this.escapeJson(p.baseURL)}",\n        "apiKey": "${this.escapeJson(this.apiKeyExpression(p))}"${this.headersConfig(p)}\n      },\n      "models": {\n${modelEntries.join(',\n')}\n      }\n    }`)
    }

    let modelRef = defaultModel
    let smallRef = smallModel
    if (modelRef.length === 0) {
      const refs = this.getAllModelRefs()
      if (refs.length > 0) modelRef = refs[0]
    }
    if (smallRef.length === 0) smallRef = modelRef

    return `{\n  "$schema": "https://opencode.ai/config.json",\n  "model": "${this.escapeJson(modelRef)}",\n  "small_model": "${this.escapeJson(smallRef)}",\n  "provider": {\n${providerEntries.join(',\n')}\n  },\n  "autoupdate": false,\n  "snapshot": true\n}`
  }

  private toEnvPrefix(id: string): string {
    let out = ''
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i)
      if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) out += c.toUpperCase()
      else out += '_'
    }
    return out
  }

  private escapeJson(s: string): string {
    return (s || '').replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r')
  }

  async save(): Promise<void> {
    await storageService.saveProviders(this.providers)
  }
}

export const providerRegistry = new ProviderRegistry()
