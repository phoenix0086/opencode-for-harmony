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
  apiType: string = 'openai_compatible'
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

  // ══════════ API Type → npm mapping ══════════

  private npmForApiType(apiType: string): string {
    if (apiType === 'anthropic') return '@ai-sdk/anthropic'
    if (apiType === 'openai_responses') return '@ai-sdk/openai'
    if (apiType === 'bedrock_converse') return '@ai-sdk/aws-bedrock'
    return '@ai-sdk/openai-compatible'
  }

  // ══════════ Test Connection ══════════

  async testConnection(input: ProviderConnectInput): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    const startTime = Date.now()

    if (input.apiKey.length === 0 || input.models.length === 0) {
      result.error = '需要填写 API Key 并至少添加一个模型才能测试。'
      return result
    }
    if (input.apiType !== 'anthropic' && input.apiType !== 'openai_responses' && input.baseURL.length === 0) {
      result.error = '需要填写 Base URL。'
      return result
    }

    const modelId = input.models[0].id
    result.modelUsed = modelId

    try {
      if (input.apiType === 'anthropic') {
        return await this.testAnthropic(input, modelId, startTime)
      } else if (input.apiType === 'openai_responses') {
        return await this.testOpenAIResponses(input, modelId, startTime)
      } else if (input.apiType === 'bedrock_converse') {
        return await this.testBedrockConverse(input, modelId, startTime)
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

    const url = this.buildUrl(input.baseURL, 'v1/chat/completions', 'chat/completions')

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['Authorization'] = `Bearer ${input.apiKey}`
    this.mergeCustomHeaders(headers, input.headers)

    const body = `{"model":"${this.esc(modelId)}","messages":[{"role":"user","content":"Say ok only."}],"max_tokens":10,"stream":false}`

    try {
      const resp = await this.httpPost(url, headers, body, 15000)
      result.latencyMs = Date.now() - startTime

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        result.ok = true
        result.responsePreview = this.extractOpenAIResponse(resp.result as string)
      } else {
        result.ok = false
        result.error = this.extractError(resp.result as string, resp.responseCode)
      }
    } catch (e) {
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = `请求 ${url} 失败: ${String(e)}`
    }

    return result
  }

  private async testAnthropic(input: ProviderConnectInput, modelId: string, startTime: number): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    result.modelUsed = modelId

    // Anthropic SDK 行为：baseURL + /v1/messages
    // 但很多代理（如小米 MiMo）的 baseURL 已经包含路径前缀，
    // SDK 会在 baseURL 后直接追加 /v1/messages
    let url = input.baseURL
    if (url.length === 0) url = 'https://api.anthropic.com'
    if (!url.endsWith('/')) url += '/'
    url += 'v1/messages'

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['x-api-key'] = input.apiKey
    headers['anthropic-version'] = '2023-06-01'
    this.mergeCustomHeaders(headers, input.headers)

    const body = `{"model":"${this.esc(modelId)}","max_tokens":10,"messages":[{"role":"user","content":"Say ok only."}]}`

    try {
      const resp = await this.httpPost(url, headers, body, 15000)
      result.latencyMs = Date.now() - startTime

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        result.ok = true
        result.responsePreview = this.extractAnthropicResponse(resp.result as string)
      } else {
        result.ok = false
        result.error = this.extractError(resp.result as string, resp.responseCode)
      }
    } catch (e) {
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = `请求 ${url} 失败: ${String(e)}`
    }

    return result
  }

  private async testOpenAIResponses(input: ProviderConnectInput, modelId: string, startTime: number): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    result.modelUsed = modelId

    const url = this.buildUrl(input.baseURL, 'v1/responses', 'responses')

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['Authorization'] = `Bearer ${input.apiKey}`
    this.mergeCustomHeaders(headers, input.headers)

    const body = `{"model":"${this.esc(modelId)}","input":"Say ok only.","max_output_tokens":10}`

    try {
      const resp = await this.httpPost(url, headers, body, 15000)
      result.latencyMs = Date.now() - startTime

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        result.ok = true
        result.responsePreview = this.extractResponsesApiResponse(resp.result as string)
      } else {
        result.ok = false
        result.error = this.extractError(resp.result as string, resp.responseCode)
      }
    } catch (e) {
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = `请求 ${url} 失败: ${String(e)}`
    }

    return result
  }

  private async testBedrockConverse(input: ProviderConnectInput, modelId: string, startTime: number): Promise<TestConnectionResult> {
    const result = new TestConnectionResult()
    result.modelUsed = modelId

    let region = 'us-east-1'
    const urlMatch = input.baseURL.match(/bedrock-runtime\.([a-z0-9-]+)\.amazonaws/)
    if (urlMatch !== null && urlMatch.length > 1) {
      region = urlMatch[1]
    }

    const url = `${input.baseURL}/model/${encodeURIComponent(modelId)}/converse`
    const now = new Date()
    const amzDate = this.awsAmzDate(now)

    const body = `{"messages":[{"role":"user","content":[{"text":"Say ok only."}]}],"inferenceConfig":{"maxTokens":10}}`

    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    headers['x-amz-date'] = amzDate
    headers['x-amz-target'] = 'AmazonBedrockGatewayService.Converse'
    this.mergeCustomHeaders(headers, input.headers)

    // AWS SigV4 signing
    const accessKeyId = input.apiKey.includes('|') ? input.apiKey.split('|')[0] : input.apiKey
    const secretKey = input.apiKey.includes('|') ? input.apiKey.split('|')[1] : ''

    if (secretKey.length > 0) {
      this.signAwsV4(headers, body, url, region, 'bedrock', accessKeyId, secretKey, now)
    } else {
      headers['Authorization'] = `AWS4-HMAC-SHA256 Credential=${accessKeyId}`
    }

    try {
      const resp = await this.httpPost(url, headers, body, 15000)
      result.latencyMs = Date.now() - startTime

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        result.ok = true
        result.responsePreview = this.extractBedrockResponse(resp.result as string)
      } else {
        result.ok = false
        result.error = this.extractError(resp.result as string, resp.responseCode)
      }
    } catch (e) {
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = `请求 ${url} 失败: ${String(e)}`
    }

    return result
  }

  // ══════════ URL builder ══════════

  private buildUrl(baseURL: string, fullSuffix: string, shortSuffix: string): string {
    let base = baseURL
    if (base.length === 0) base = 'https://api.openai.com'
    if (base.endsWith('/v1') || base.endsWith('/v1/')) {
      const sep = base.endsWith('/') ? '' : '/'
      return `${base}${sep}${shortSuffix}`
    }
    if (!base.endsWith('/')) base += '/'
    return `${base}${fullSuffix}`
  }

  // ══════════ Response parsers ══════════

  private extractOpenAIResponse(raw: string): string {
    try {
      const data = JSON.parse(raw) as Record<string, Object>
      const choices = data['choices'] as Array<Record<string, Object>>
      if (choices !== undefined && choices.length > 0) {
        const msg = choices[0]['message'] as Record<string, string>
        return (msg['content'] || '').substring(0, 100)
      }
    } catch (e) {
      // ignore
    }
    return '(parse error)'
  }

  private extractAnthropicResponse(raw: string): string {
    try {
      const data = JSON.parse(raw) as Record<string, Object>
      const content = data['content'] as Array<Record<string, string>>
      if (content !== undefined && content.length > 0) {
        return (content[0]['text'] || '').substring(0, 100)
      }
    } catch (e) {
      // ignore
    }
    return '(parse error)'
  }

  private extractResponsesApiResponse(raw: string): string {
    try {
      const data = JSON.parse(raw) as Record<string, Object>
      const output = data['output'] as Array<Record<string, Object>>
      if (output !== undefined && output.length > 0) {
        for (let i = 0; i < output.length; i++) {
          const item = output[i]
          if (item['type'] === 'message') {
            const content = item['content'] as Array<Record<string, string>>
            if (content !== undefined && content.length > 0) {
              return (content[0]['text'] || '').substring(0, 100)
            }
          }
        }
      }
    } catch (e) {
      // ignore
    }
    return '(parse error)'
  }

  private extractBedrockResponse(raw: string): string {
    try {
      const data = JSON.parse(raw) as Record<string, Object>
      const output = data['output'] as Record<string, Object>
      const msg = output['message'] as Record<string, Object>
      const content = msg['content'] as Array<Record<string, string>>
      if (content !== undefined && content.length > 0) {
        return (content[0]['text'] || '').substring(0, 100)
      }
    } catch (e) {
      // ignore
    }
    return '(parse error)'
  }

  private extractError(raw: string, statusCode: number): string {
    try {
      const err = JSON.parse(raw) as Record<string, Object>
      const errObj = err['error'] as Record<string, string>
      if (errObj !== undefined && errObj['message'] !== undefined && errObj['message'].length > 0) {
        return errObj['message']
      }
      const msg = err['message'] as string
      if (msg !== undefined && msg.length > 0) return msg
    } catch (e) {
      // ignore
    }
    return `HTTP ${statusCode}`
  }

  // ══════════ HTTP helper ══════════

  private async httpPost(url: string, headers: Record<string, string>, body: string, timeoutMs: number): Promise<http.HttpResponse> {
    const req = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      connectTimeout: Math.min(timeoutMs, 10000),
      readTimeout: timeoutMs,
      extraData: body
    }
    try {
      const resp = await req.request(url, options)
      return resp
    } catch (e) {
      throw new Error(String(e))
    } finally {
      req.destroy()
    }
  }

  private mergeCustomHeaders(target: Record<string, string>, customHeaders: ProviderHeaderInput[]): void {
    for (let i = 0; i < customHeaders.length; i++) {
      const h = customHeaders[i]
      if (h.name.length > 0) {
        target[h.name] = h.value
      }
    }
  }

  private esc(s: string): string {
    return s.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')
  }

  // ══════════ AWS SigV4 Helpers ══════════
  // NOTE: Real AWS SigV4 requires HMAC-SHA256 which is not available in ArkTS
  // without an external crypto library. Bedrock providers should configure
  // credentials externally and use a proxy or pre-signed URL.

  private awsAmzDate(d: Date): string {
    const y = d.getUTCFullYear()
    const m = String(d.getUTCMonth() + 1).padStart(2, '0')
    const day = String(d.getUTCDate()).padStart(2, '0')
    const h = String(d.getUTCHours()).padStart(2, '0')
    const min = String(d.getUTCMinutes()).padStart(2, '0')
    const s = String(d.getUTCSeconds()).padStart(2, '0')
    return `${y}${m}${day}T${h}${min}${s}Z`
  }

  private signAwsV4(headers: Record<string, string>, _body: string, _url: string, _region: string, _service: string, accessKeyId: string, secretKey: string, _now: Date): void {
    // ArkTS does not provide HMAC-SHA256 natively.
    // Fall back to a bearer-style auth header; real SigV4 signing must be
    // done externally (e.g. via a proxy or pre-signed URL).
    if (secretKey.length > 0) {
      headers['Authorization'] = `Bearer ${accessKeyId}:${secretKey}`
    } else {
      headers['Authorization'] = `Bearer ${accessKeyId}`
    }
  }

  // ══════════ Connect Provider ══════════

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
        result.message = 'Provider saved locally. Connect Runtime to sync config and auth.'
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
    if (input.apiType !== 'anthropic' && input.apiType !== 'openai_responses' && input.baseURL.length === 0) return 'Base URL is required.'
    if (input.baseURL.length > 0 && !input.baseURL.startsWith('http://') && !input.baseURL.startsWith('https://')) return 'Base URL must start with http:// or https://.'
    if (input.models.length === 0) return 'At least one model is required.'

    const seen: string[] = []
    for (let i = 0; i < input.models.length; i++) {
      const m = input.models[i]
      if (m.id.length === 0) return 'Model ID cannot be empty.'
      for (let j = 0; j < seen.length; j++) {
        if (seen[j] === m.id) return `Duplicated model ID: ${m.id}`
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
    p.npm = this.npmForApiType(input.apiType)
    p.baseURL = input.baseURL
    p.authEnv = input.authEnv.length > 0 ? input.authEnv : this.toEnvName(input.providerId)
    p.apiKeyRef = p.authEnv
    p.apiKeyMode = 'direct'
    p.apiKey = input.apiKey
    p.enabled = true
    p.builtIn = false
    p.authStatus = input.apiKey.length > 0 ? 'configured' : 'missing'

    for (let i = 0; i < input.models.length; i++) {
      const item = input.models[i]
      const m = new CNModel()
      m.id = item.id
      m.name = item.name.length > 0 ? item.name : item.id
      m.enabled = true
      m.coding = true
      p.models.push(m)
    }

    for (let i = 0; i < input.headers.length; i++) {
      const item = input.headers[i]
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

    for (let i = 0; i < provider.models.length; i++) {
      const m = provider.models[i]
      await providerRegistry.addOrUpdateModel(provider.id, m.id, m.name, true)
    }

    for (let i = 0; i < provider.headers.length; i++) {
      const h = provider.headers[i]
      await providerRegistry.addOrUpdateHeader(provider.id, h.name, h.value)
    }
  }

  private buildProviderPatch(provider: CNProvider): Record<string, Object> {
    const models: Record<string, Object> = {}
    for (let i = 0; i < provider.models.length; i++) {
      const m = provider.models[i]
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
      for (let i = 0; i < provider.headers.length; i++) {
        const h = provider.headers[i]
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
