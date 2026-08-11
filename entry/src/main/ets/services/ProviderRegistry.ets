import { CNProvider, CNModel, ProviderHeader, createDefaultProviders } from '../models/Provider'
import { storageService } from './StorageService'

/**
 * OpenCode Provider registry.
 *
 * This version adds secret-safe config preview by default.
 */
export class ProviderRegistry {
  private providers: CNProvider[] = []

  async init(): Promise<void> {
    const defaults = createDefaultProviders()
    const saved = await storageService.loadProviders()

    if (saved.length === 0) {
      this.providers = defaults
      // Enable the first provider by default (if any)
      if (this.providers.length > 0) {
        this.providers[0].enabled = true
      }
      await this.save()
      return
    }

    // Merge: defaults provide structure, saved provides user customizations
    const merged: CNProvider[] = []
    for (const d of defaults) {
      const s = this.findProvider(saved, d.id)
      if (s) {
        merged.push(this.mergeProvider(d, s))
      } else {
        // Default not in saved — include it as-is (new built-in provider)
        d.enabled = false
        merged.push(d)
      }
    }

    // Preserve user-created custom providers not in defaults
    for (const s of saved) {
      if (!this.findProvider(merged, s.id)) {
        merged.push(this.normalizeProvider(s))
      }
    }
    this.providers = merged
  }

  /**
   * 清掉 storage 里的 provider 配置并把内存里的 providers 替换成
   * createDefaultProviders() 的输出。专治 baseURL/协议变更后旧 storage
   * 卡住的情况,无需用户去 DevEco 清 AppStorage。
   */
  async resetToDefaults(): Promise<void> {
    await storageService.resetProviders()
    const defaults = createDefaultProviders()
    this.providers = defaults
    if (this.providers.length > 0) {
      this.providers[0].enabled = true
    }
    await this.save()
  }

  private findProvider(list: CNProvider[], id: string): CNProvider | undefined {
    for (const p of list) if (p.id === id) return p
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
    p.apiKeyMode = raw.apiKeyMode || 'env'
    p.apiKey = raw.apiKey || ''
    p.apiKeyRef = raw.apiKeyRef || raw.authEnv || 'CUSTOM_API_KEY'
    p.headers = raw.headers || []
    p.models = raw.models || []
    p.enabled = raw.enabled === true
    p.authStatus = raw.authStatus || (p.apiKey.length > 0 || p.apiKeyMode === 'env' ? 'configured' : 'missing')
    p.builtIn = raw.builtIn !== false
    p.notes = raw.notes || ''
    return p
  }

  private mergeProvider(base: CNProvider, saved: CNProvider): CNProvider {
    const p = this.normalizeProvider(base)
    // C3 fix: 之前丢掉了 saved.name,改名后 init() 会被默认值覆盖回滚
    p.name = saved.name.length > 0 ? saved.name : base.name
    p.npm = saved.npm.length > 0 ? saved.npm : base.npm
    // User's enable/disable preference is preserved
    p.enabled = saved.enabled
    p.baseURL = saved.baseURL.length > 0 ? saved.baseURL : base.baseURL
    p.authEnv = saved.authEnv.length > 0 ? saved.authEnv : base.authEnv
    p.authMode = saved.authMode.length > 0 ? saved.authMode : base.authMode
    p.apiKeyMode = saved.apiKeyMode.length > 0 ? saved.apiKeyMode : 'env'
    p.apiKey = saved.apiKey
    p.apiKeyRef = saved.apiKeyRef.length > 0 ? saved.apiKeyRef : p.authEnv
    p.authStatus = saved.authStatus.length > 0 ? saved.authStatus : (p.apiKey.length > 0 || p.apiKeyMode === 'env' ? 'configured' : 'missing')
    p.notes = saved.notes
    p.builtIn = saved.builtIn
    // C2 fix: 深拷贝 headers/models 数组,避免 addOrUpdateHeader/removeModel
    // 之类的 mutator 反向污染 JSON.parse 解出来的 raw 对象,以及下次 init()
    // merge 时把污染状态持久化进 storage。
    if (saved.headers.length > 0) {
      const headersCopy: ProviderHeader[] = []
      for (const h of saved.headers) {
        const nh = new ProviderHeader()
        nh.name = h.name
        nh.value = h.value
        headersCopy.push(nh)
      }
      p.headers = headersCopy
    } else {
      p.headers = []
    }
    if (saved.models.length > 0) {
      const modelsCopy: CNModel[] = []
      for (const m of saved.models) {
        const nm = new CNModel()
        nm.id = m.id
        nm.name = m.name
        nm.coding = m.coding
        nm.contextWindow = m.contextWindow
        nm.maxOutput = m.maxOutput
        nm.recommended = m.recommended
        nm.enabled = m.enabled
        modelsCopy.push(nm)
      }
      p.models = modelsCopy
    }
    return p
  }

  getAll(): CNProvider[] { return this.providers }

  getEnabled(): CNProvider[] {
    const result: CNProvider[] = []
    for (const p of this.providers) if (p.enabled) result.push(p)
    return result
  }

  getById(id: string): CNProvider | undefined { return this.findProvider(this.providers, id) }

  enable(providerId: string): void { const p = this.getById(providerId); if (p) p.enabled = true }
  disable(providerId: string): void { const p = this.getById(providerId); if (p) p.enabled = false }

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
    p.apiKeyMode = mode === 'direct' ? 'direct' : 'env'
    p.apiKey = apiKey
    p.authStatus = apiKey.length > 0 || p.apiKeyMode === 'env' ? 'configured' : 'missing'
    if (apiKey.length === 0) await storageService.removeProviderCredential(providerId)
    await this.save()
    return true
  }

  async addOrUpdateHeader(providerId: string, name: string, value: string): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p || name.length === 0) return false
    let found = false
    for (const h of p.headers) {
      if (h.name === name) { h.value = value; found = true }
    }
    if (!found) { const h = new ProviderHeader(); h.name = name; h.value = value; p.headers.push(h) }
    await this.save()
    return true
  }

  async removeHeader(providerId: string, name: string): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    const kept: ProviderHeader[] = []
    for (const h of p.headers) if (h.name !== name) kept.push(h)
    p.headers = kept
    await this.save()
  }

  async addOrUpdateModel(providerId: string, modelId: string, displayName: string, coding: boolean = true): Promise<boolean> {
    const p = this.getById(providerId)
    if (!p || modelId.length === 0) return false
    let found = false
    for (const m of p.models) {
      if (m.id === modelId) { m.name = displayName.length > 0 ? displayName : modelId; m.coding = coding; m.enabled = true; found = true }
    }
    if (!found) { const m = new CNModel(); m.id = modelId; m.name = displayName.length > 0 ? displayName : modelId; m.coding = coding; m.enabled = true; p.models.push(m) }
    await this.save()
    return true
  }

  async removeModel(providerId: string, modelId: string): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    const kept: CNModel[] = []
    for (const m of p.models) if (m.id !== modelId) kept.push(m)
    p.models = kept
    await this.save()
  }

  async removeProvider(providerId: string): Promise<void> {
    const kept: CNProvider[] = []
    for (const p of this.providers) if (p.id !== providerId) kept.push(p)
    this.providers = kept
    await storageService.removeProviderCredential(providerId)
    await this.save()
  }

  /**
   * Replace one provider atomically and persist once. This keeps edits exact:
   * removed models/headers stay removed and an intentionally cleared API key
   * is not restored by incremental update logic.
   */
  async upsertProvider(raw: CNProvider): Promise<void> {
    const p = new CNProvider()
    p.id = raw.id
    p.name = raw.name
    p.npm = raw.npm
    p.baseURL = raw.baseURL
    p.authEnv = raw.authEnv
    p.authMode = raw.authMode
    p.apiKeyMode = raw.apiKeyMode
    p.apiKey = raw.apiKey
    p.apiKeyRef = raw.apiKeyRef
    p.enabled = raw.enabled
    p.authStatus = raw.authStatus
    p.notes = raw.notes

    const existing = this.getById(raw.id)
    p.builtIn = existing !== undefined ? existing.builtIn : raw.builtIn
    if (existing !== undefined && existing.apiKey.length > 0 && raw.apiKey.length === 0) {
      await storageService.removeProviderCredential(raw.id)
    }

    for (const sourceHeader of raw.headers) {
      const header = new ProviderHeader()
      header.name = sourceHeader.name
      header.value = sourceHeader.value
      p.headers.push(header)
    }
    for (const sourceModel of raw.models) {
      const model = new CNModel()
      model.id = sourceModel.id
      model.name = sourceModel.name
      model.coding = sourceModel.coding
      model.contextWindow = sourceModel.contextWindow
      model.maxOutput = sourceModel.maxOutput
      model.recommended = sourceModel.recommended
      model.enabled = sourceModel.enabled
      p.models.push(model)
    }

    let replaced = false
    const next: CNProvider[] = []
    for (const current of this.providers) {
      if (current.id === p.id) {
        next.push(p)
        replaced = true
      } else {
        next.push(current)
      }
    }
    if (!replaced) next.push(p)
    this.providers = next
    await this.save()
  }

  async setModelEnabled(providerId: string, modelId: string, enabled: boolean): Promise<void> {
    const p = this.getById(providerId)
    if (!p) return
    for (const m of p.models) if (m.id === modelId) m.enabled = enabled
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
    p.apiKeyMode = apiKey.length > 0 ? 'direct' : 'env'
    p.apiKey = apiKey
    p.enabled = true
    p.builtIn = false
    p.authStatus = apiKey.length > 0 ? 'configured' : 'missing'
    if (modelId.length > 0) { const m = new CNModel(); m.id = modelId; m.name = modelId; m.coding = true; m.recommended = true; p.models.push(m) }
    this.providers.push(p)
    await this.save()
    return true
  }

  getRecommendedModel(providerId: string): string {
    const p = this.getById(providerId)
    if (!p) return ''
    for (const m of p.models) if (m.enabled !== false && m.recommended) return `${p.id}/${m.id}`
    for (const m of p.models) if (m.enabled !== false) return `${p.id}/${m.id}`
    return ''
  }

  getAllModelRefs(): string[] {
    const refs: string[] = []
    for (const p of this.providers) {
      if (!p.enabled) continue
      for (const m of p.models) if (m.enabled !== false) refs.push(`${p.id}/${m.id}`)
    }
    return refs
  }

  /**
   * 返回启用的 provider 中 authStatus === 'missing' 的子集。
   * 用于首页判断"是否需要提示用户填 API key"。
   * 状态可能取值:'configured' | 'missing' | 'error',只有 'missing' 算真缺
   */
  getMissingProviders(): CNProvider[] {
    const missing: CNProvider[] = []
    for (const p of this.providers) {
      if (p.enabled && p.authStatus === 'missing') missing.push(p)
    }
    return missing
  }

  /** 是否有任何启用的 provider 缺 API key,首页 banner 用 */
  hasMissingApiKey(): boolean {
    return this.getMissingProviders().length > 0
  }

  maskApiKey(apiKey: string): string {
    if (apiKey.length === 0) return ''
    if (apiKey.length <= 8) return '****'
    return `${apiKey.substring(0, 3)}****${apiKey.substring(apiKey.length - 4)}`
  }

  private apiKeyExpression(p: CNProvider, includeSecrets: boolean): string {
    if (p.apiKeyMode === 'env') return `{env:${p.authEnv}}`
    if (includeSecrets) return p.apiKey
    if (p.apiKey.length > 0) return this.maskApiKey(p.apiKey)
    return `{env:${p.authEnv}}`
  }

  private headersConfig(p: CNProvider, includeSecrets: boolean): string {
    const entries: string[] = []
    for (const h of p.headers) {
      if (h.name.length > 0) {
        const val = includeSecrets ? h.value : this.maskHeaderValue(h.value)
        entries.push(`        "${this.escapeJson(h.name)}": "${this.escapeJson(val)}"`)
      }
    }
    if (entries.length === 0) return ''
    return `,\n      "headers": {\n${entries.join(',\n')}\n      }`
  }

  private maskHeaderValue(value: string): string {
    if (value.length === 0) return ''
    if (value.length <= 6) return '****'
    return `${value.substring(0, 2)}****${value.substring(value.length - 2)}`
  }

  generateFullConfig(defaultModel: string, smallModel: string, includeSecrets: boolean = false): string {
    const providerEntries: string[] = []
    for (const p of this.getEnabled()) {
      const modelEntries: string[] = []
      for (const m of p.models) {
        if (m.enabled === false) continue
        modelEntries.push(`        "${this.escapeJson(m.id)}": {\n          "name": "${this.escapeJson(m.name)}"\n        }`)
      }
      providerEntries.push(`    "${this.escapeJson(p.id)}": {\n      "npm": "${this.escapeJson(p.npm)}",\n      "name": "${this.escapeJson(p.name)}",\n      "options": {\n        "baseURL": "${this.escapeJson(p.baseURL)}",\n        "apiKey": "${this.escapeJson(this.apiKeyExpression(p, includeSecrets))}"${this.headersConfig(p, includeSecrets)}\n      },\n      "models": {\n${modelEntries.join(',\n')}\n      }\n    }`)
    }

    let modelRef = defaultModel
    let smallRef = smallModel
    if (modelRef.length === 0) { const refs = this.getAllModelRefs(); if (refs.length > 0) modelRef = refs[0] }
    if (smallRef.length === 0) smallRef = modelRef

    return `{\n  "$schema": "https://opencode.ai/config.json",\n  "model": "${this.escapeJson(modelRef)}",\n  "small_model": "${this.escapeJson(smallRef)}",\n  "provider": {\n${providerEntries.join(',\n')}\n  },\n  "autoupdate": false,\n  "snapshot": true\n}`
  }

  generatePreviewConfig(defaultModel: string, smallModel: string): string {
    return this.generateFullConfig(defaultModel, smallModel, false)
  }

  generateConfigWithSecrets(defaultModel: string, smallModel: string): string {
    return this.generateFullConfig(defaultModel, smallModel, true)
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
