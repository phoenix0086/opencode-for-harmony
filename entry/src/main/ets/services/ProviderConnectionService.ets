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
  baseURL: string = ''
  apiKey: string = ''
  authEnv: string = ''
  models: ProviderModelInput[] = []
  headers: ProviderHeaderInput[] = []
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
    p.npm = '@ai-sdk/openai-compatible'
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
    options['baseURL'] = provider.baseURL
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
