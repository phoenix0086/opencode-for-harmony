import { FullProviderInput, FullModelInput, FullModelOption, FullRunner } from '../models/FullAppModels'
import { OpenCodeApiClient } from './OpenCodeApiClient'

export class ProviderModelManager {
  buildProviderConfig(input: FullProviderInput): Record<string, Object> {
    const models: Record<string, Object> = {}
    for (const m of input.models) {
      const entry: Record<string, string> = {}
      entry['name'] = m.name.length > 0 ? m.name : m.id
      models[m.id] = entry
    }

    const options: Record<string, Object> = {}
    options['baseURL'] = input.baseURL
    options['apiKey'] = `{env:${this.envName(input.providerId)}}`

    const provider: Record<string, Object> = {}
    provider['npm'] = '@ai-sdk/openai-compatible'
    provider['name'] = input.displayName
    provider['options'] = options
    provider['models'] = models

    const providers: Record<string, Object> = {}
    providers[input.providerId] = provider

    const patch: Record<string, Object> = {}
    patch['provider'] = providers
    return patch
  }

  envName(id: string): string {
    let out = ''
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i)
      if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) {
        out += c.toUpperCase()
      } else {
        out += '_'
      }
    }
    return `${out}_API_KEY`
  }

  validateProvider(input: FullProviderInput): string {
    if (input.providerId.length === 0) return 'Provider ID 不能为空'
    if (input.displayName.length === 0) return '显示名称不能为空'
    if (input.baseURL.length === 0) return 'Base URL 不能为空'
    if (!input.baseURL.startsWith('http://') && !input.baseURL.startsWith('https://')) return 'Base URL 必须以 http:// 或 https:// 开头'
    if (input.models.length === 0) return '至少需要一个模型'
    return ''
  }

  async syncProvider(input: FullProviderInput, runner: FullRunner | null): Promise<string> {
    const err = this.validateProvider(input)
    if (err.length > 0) return err
    if (runner === null) return 'Provider 已本地保存；Runtime 未连接，暂未同步。'

    const client = new OpenCodeApiClient(runner)
    await client.patchConfig(this.buildProviderConfig(input))

    if (input.apiKey.length > 0) {
      await client.setAuth(input.providerId, input.apiKey)
    }

    return 'Provider 已同步到 Runtime'
  }

  listModels(providers: FullProviderInput[]): FullModelOption[] {
    const result: FullModelOption[] = []
    for (const p of providers) {
      for (const m of p.models) {
        const opt = new FullModelOption()
        opt.providerId = p.providerId
        opt.providerName = p.displayName
        opt.modelId = m.id
        opt.modelName = m.name.length > 0 ? m.name : m.id
        opt.modelRef = `${p.providerId}/${m.id}`
        result.push(opt)
      }
    }
    return result
  }
}

export const providerModelManager = new ProviderModelManager()
