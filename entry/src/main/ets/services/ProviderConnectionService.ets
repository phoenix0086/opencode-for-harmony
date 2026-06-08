import { http } from '@kit.NetworkKit'
import { CNProvider, CNModel, ProviderHeader } from '../models/Provider'
import { Runner } from '../models/Runner'
import { providerRegistry } from './ProviderRegistry'
import { OpenCodeClient } from './OpenCodeClient'

export class ProviderModelInput {
  id: string = ''
  name: string = ''
}

export class ProviderHeaderInput {
  name: string = ''
  value: string = ''
}

export class ProviderConnectInput {
  providerId: string = ''
  displayName: string = ''
  apiType: string = 'openai_compatible' // 'openai_compatible' | 'anthropic'
  baseURL: string = ''
  apiKey: string = ''
  authEnv: string = ''
  models: ProviderModelInput[] = []
  headers: ProviderHeaderInput[] = []
}

export class TestConnectionResult {
  ok: boolean = false
  latencyMs: number = 0
  modelUsed: string = ''
  responsePreview: string = ''
  error: string = ''
}

export class ProviderConnectResult {
  ok: boolean = false
  providerId: string = ''
  connected: boolean = false
  localSaved: boolean = false
  serverConfigSaved: boolean = false
  serverAuthSaved: boolean = false
  message: string = ''
  error: string = ''
}

export class ProviderConnectionService {

  async testConnection(input: ProviderConnectInput): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    const startTime = Date.now()

    if (input.baseURL.length === 0 || input.apiKey.length === 0 || input.models.length === 0) {
      result.error = '需要填写 Base URL、API Key 并至少添加一个模型才能测试。'
      return result
    }

    const modelId = input.models[0].id
    result.modelUsed = modelId

    try {
      if (input.apiType === 'anthropic') {
        return await this.testAnthropic(input, modelId, startTime)
      } else {
        return await this.testOpenAICompatible(input, modelId, startTime)
      }
    } catch (e) {
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = String(e)
      return result
    }
  }

  private async testOpenAICompatible(input: ProviderConnectInput, modelId: string, startTime: number): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    result.modelUsed = modelId

    let url = input.baseURL
    if (!url.endsWith('/')) url += '/'
    url += 'v1/chat/completions'
    // Handle baseURL already ending with /v1 or /v1/
    if (input.baseURL.endsWith('/v1') || input.baseURL.endsWith('/v1/')) {
      url = input.baseURL.endsWith('/') ? `${input.baseURL}chat/completions` : `${input.baseURL}/chat/completions`
    }

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['Authorization'] = `Bearer ${input.apiKey}`
    for (const h of input.headers) {
      if (h.name.length > 0) headers[h.name] = h.value
    }

    const body = JSON.stringify({
      model: modelId,
      messages: [{ role: 'user', content: 'Say "ok" only.' }],
      max_tokens: 10,
      stream: false
    })

    const resp = await this.httpPost(url, headers, body, 15000)
    result.latencyMs = Date.now() - startTime

    if (resp.responseCode >= 200 && resp.responseCode < 300) {
      result.ok = true
      try {
        const data = JSON.parse(resp.result as string) as Record<string, Object>
        const choices = data['choices'] as Array<Record<string, Object>>
        if (choices && choices.length > 0) {
          const msg = choices[0]['message'] as Record<string, string>
          result.responsePreview = (msg['content'] || '').substring(0, 100)
        }
      } catch (e) {
        result.responsePreview = '(parse error)'
      }
    } else {
      result.ok = false
      try {
        const err = JSON.parse(resp.result as string) as Record<string, Object>
        const errObj = err['error'] as Record<string, string>
        result.error = errObj ? (errObj['message'] || `HTTP ${resp.responseCode}`) : `HTTP ${resp.responseCode}`
      } catch (e) {
        result.error = `HTTP ${resp.responseCode}`
      }
    }

    return result
  }

  private async testAnthropic(input: ProviderConnectInput, modelId: string, startTime: number): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    result.modelUsed = modelId

    let url = input.baseURL
    if (!url.endsWith('/')) url += '/'
    // Anthropic Messages API
    if (!url.includes('/v1/messages')) {
      url += 'v1/messages'
    }
    // Handle baseURL already ending with /v1 or /v1/
    if (input.baseURL.endsWith('/v1')) {
      url = `${input.baseURL}/messages`
    } else if (input.baseURL.endsWith('/v1/')) {
      url = `${input.baseURL}messages`
    }

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['x-api-key'] = input.apiKey
    headers['anthropic-version'] = '2023-06-01'
    for (const h of input.headers) {
      if (h.name.length > 0) headers[h.name] = h.value
    }

    const body = JSON.stringify({
      model: modelId,
      max_tokens: 10,
      messages: [{ role: 'user', content: 'Say "ok" only.' }]
    })

    const resp = await this.httpPost(url, headers, body, 15000)
    result.latencyMs = Date.now() - startTime

    if (resp.responseCode >= 200 && resp.responseCode < 300) {
      result.ok = true
      try {
        const data = JSON.parse(resp.result as string) as Record<string, Object>
        const content = data['content'] as Array<Record<string, string>>
        if (content && content.length > 0) {
          result.responsePreview = (content[0]['text'] || '').substring(0, 100)
        }
      } catch (e) {
        result.responsePreview = '(parse error)'
      }
    } else {
      result.ok = false
      try {
        const err = JSON.parse(resp.result as string) as Record<string, Object>
        const errObj = err['error'] as Record<string, string>
        result.error = errObj ? (errObj['message'] || `HTTP ${resp.responseCode}`) : `HTTP ${resp.responseCode}`
      } catch (e) {
        result.error = `HTTP ${resp.responseCode}`
      }
    }

    return result
  }

  private async httpPost(url: string, headers: Record<string, string>, body: string, timeoutMs: number): Promise<http.HttpResponse> {
    const req = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      connectTimeout: Math.min(timeoutMs, 10000),
      readTimeout: timeoutMs,
      extraData: body
    }
    const resp = await req.request(url, options)
    req.destroy()
    return resp
  }

  async connectProvider(input: ProviderConnectInput, runner: Runner | null): Promise<ProviderConnectResult> {
    const result = new ProviderConnectResult()
    result.providerId = input.providerId

    const validation = this.validate(input)
    if (validation.length > 0) {
      result.ok = false
      result.error = validation
      result.message = validation
      return result
    }

    try {
      await providerRegistry.init()
      const provider = this.toCNProvider(input)
      await this.saveLocal(provider)
      result.localSaved = true

      if (runner === null) {
        result.ok = true
        result.connected = false
        result.message = 'Provider saved locally. Connect OpenCode Server to sync config and auth.'
        return result
      }

      const client = new OpenCodeClient(runner)

      try {
        await client.updateConfig(this.buildProviderPatch(provider))
        result.serverConfigSaved = true
      } catch (e) {
        result.ok = true
        result.connected = false
        result.message = `Provider saved locally, but config patch failed: ${String(e)}`
        return result
      }

      if (input.apiKey.length > 0) {
        try {
          result.serverAuthSaved = await client.setAuth(input.providerId, input.apiKey)
        } catch (e) {
          result.serverAuthSaved = false
          result.message = `Provider config saved, but auth failed: ${String(e)}`
        }
      }

      try {
        const providerList = await client.listProviders()
        for (const id of providerList.connected) {
          if (id === input.providerId) {
            result.connected = true
            break
          }
        }
      } catch (e) {
        result.connected = false
      }

      result.ok = true
      if (result.connected) {
        result.message = 'Provider connected.'
      } else if (result.serverAuthSaved) {
        result.message = 'Provider saved and auth written, but server does not report it as connected yet.'
      } else if (input.apiKey.length === 0) {
        result.message = 'Provider saved. API Key is empty, so it is not connected.'
      } else {
        result.message = result.message.length > 0 ? result.message : 'Provider saved, but not connected.'
      }
      return result
    } catch (e) {
      result.ok = false
      result.error = String(e)
      result.message = String(e)
      return result
    }
  }

  validate(input: ProviderConnectInput): string {
    if (input.providerId.length === 0) return 'Provider ID is required.'
    if (!this.isValidProviderId(input.providerId)) return 'Provider ID can only use lowercase letters, numbers, hyphen, or underscore.'
    if (input.displayName.length === 0) return 'Display name is required.'
    if (input.baseURL.length === 0) return 'Base URL is required.'
    if (!input.baseURL.startsWith('http://') && !input.baseURL.startsWith('https://')) return 'Base URL must start with http:// or https://.'
    if (input.models.length === 0) return 'At least one model is required.'

    const seen: string[] = []
    for (const m of input.models) {
      if (m.id.length === 0) return 'Model ID cannot be empty.'
      for (const existing of seen) {
        if (existing === m.id) return `Duplicated model ID: ${m.id}`
      }
      seen.push(m.id)
    }

    return ''
  }

  private isValidProviderId(id: string): boolean {
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i)
      const ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c === '-' || c === '_'
      if (!ok) return false
    }
    return true
  }

  private toCNProvider(input: ProviderConnectInput): CNProvider {
    const p = new CNProvider()
    p.id = input.providerId
    p.name = input.displayName
    p.npm = input.apiType === 'anthropic' ? '@ai-sdk/anthropic' : '@ai-sdk/openai-compatible'
    p.baseURL = input.baseURL
    p.authEnv = input.authEnv.length > 0 ? input.authEnv : this.toEnvName(input.providerId)
    p.apiKeyRef = p.authEnv
    p.apiKeyMode = 'direct'
    p.apiKey = input.apiKey
    p.enabled = true
    p.builtIn = false
    p.authStatus = input.apiKey.length > 0 ? 'configured' : 'missing'

    for (const item of input.models) {
      const m = new CNModel()
      m.id = item.id
      m.name = item.name.length > 0 ? item.name : item.id
      m.enabled = true
      m.coding = true
      p.models.push(m)
    }

    for (const item of input.headers) {
      if (item.name.length > 0) {
        const h = new ProviderHeader()
        h.name = item.name
        h.value = item.value
        p.headers.push(h)
      }
    }

    return p
  }

  private async saveLocal(provider: CNProvider): Promise<void> {
    const existing = providerRegistry.getById(provider.id)
    if (!existing) {
      await providerRegistry.createCustomProvider(provider.id, provider.name, provider.baseURL, provider.apiKey, '')
    }
    await providerRegistry.setProviderConfig(provider.id, provider.name, provider.baseURL, provider.npm, provider.authEnv)
    await providerRegistry.setProviderEnabled(provider.id, true)
    if (provider.apiKey.length > 0) {
      await providerRegistry.setApiKey(provider.id, provider.apiKey, 'direct')
    }

    for (const m of provider.models) {
      await providerRegistry.addOrUpdateModel(provider.id, m.id, m.name, true)
    }

    for (const h of provider.headers) {
      await providerRegistry.addOrUpdateHeader(provider.id, h.name, h.value)
    }
  }

  private buildProviderPatch(provider: CNProvider): Record<string, Object> {
    const models: Record<string, Object> = {}
    for (const m of provider.models) {
      const entry: Record<string, string> = {}
      entry['name'] = m.name.length > 0 ? m.name : m.id
      models[m.id] = entry
    }

    const options: Record<string, Object> = {}
    if (provider.baseURL.length > 0) {
      options['baseURL'] = provider.baseURL
    }
    options['apiKey'] = `{env:${provider.authEnv}}`

    if (provider.headers.length > 0) {
      const headers: Record<string, string> = {}
      for (const h of provider.headers) {
        if (h.name.length > 0) headers[h.name] = h.value
      }
      options['headers'] = headers
    }

    const providerConfig: Record<string, Object> = {}
    providerConfig['npm'] = provider.npm
    providerConfig['name'] = provider.name
    providerConfig['options'] = options
    providerConfig['models'] = models

    const providers: Record<string, Object> = {}
    providers[provider.id] = providerConfig

    const patch: Record<string, Object> = {}
    patch['provider'] = providers
    return patch
  }

  private toEnvName(id: string): string {
    let out = ''
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i)
      if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) out += c.toUpperCase()
      else out += '_'
    }
    return `${out}_API_KEY`
  }
}

export const providerConnectionService = new ProviderConnectionService()
