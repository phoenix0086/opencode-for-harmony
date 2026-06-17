import { preferences } from '@kit.ArkData'
import { Runner } from '../models/Runner'
import { CNProvider } from '../models/Provider'
import { Logger } from '../utils/Logger'
import { errStr } from '../utils/ErrorUtil'

const STORE_NAME = 'opencode_prefs'
const RUNNERS_KEY = 'runners'
const ACTIVE_RUNNER_KEY = 'active_runner_id'
const PROVIDERS_KEY = 'cn_providers'
const SERVER_URL_KEY = 'server_url'
const WORKSPACE_KEY = 'workspace_path'
const RECENT_WORKSPACES_KEY = 'recent_workspaces'
const SETTINGS_KEY = 'app_settings'
const LOCAL_SERVER_CONFIG_KEY = 'local_server_config'

/**
 * Local persistence service.
 *
 * NOTE: For a production build, move provider API keys to Harmony KeyStore or
 * a secure credential service. This implementation intentionally stores the
 * configured key locally so the OpenCode-compatible Provider UX works without
 * external env var wiring on Harmony devices.
 */
export class StorageService {
  private store: preferences.Preferences | null = null

  async init(context: Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME)
    } catch (e) {
      return
    }
  }

  async saveRunners(runners: Runner[]): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(RUNNERS_KEY, JSON.stringify(runners))
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async loadRunners(): Promise<Runner[]> {
    if (this.store === null) return []
    try {
      const raw = await this.store.get(RUNNERS_KEY, '[]') as string
      return JSON.parse(raw) as Runner[]
    } catch {
      return []
    }
  }

  async setActiveRunnerId(id: string): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(ACTIVE_RUNNER_KEY, id)
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async getActiveRunnerId(): Promise<string> {
    if (this.store === null) return ''
    try {
      return (await this.store.get(ACTIVE_RUNNER_KEY, '')) as string
    } catch (e) {
      return ''
    }
  }

  async saveProviders(providers: CNProvider[]): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(PROVIDERS_KEY, JSON.stringify(providers))
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async loadProviders(): Promise<CNProvider[]> {
    if (this.store === null) return []
    try {
      const raw = await this.store.get(PROVIDERS_KEY, '[]') as string
      const parsed: Object = JSON.parse(raw)
      if (!Array.isArray(parsed)) {
        Logger.warn(`loadProviders: persisted value is not an array, discarding`)
        return []
      }
      // S2 fix: 校验每个元素的最小必填字段,无效项跳过而不是全量保留。
      // 之前直接 `as CNProvider[]` 会在后续访问 p.id / p.models 时才炸,
      // 错误定位更困难。这里一次性过滤。
      const valid: CNProvider[] = []
      for (const item of parsed as Object[]) {
        if (!item || typeof item !== 'object') continue
        const prov = item as Record<string, Object>
        if (typeof prov['id'] !== 'string' || (prov['id'] as string).length === 0) continue
        if (typeof prov['name'] !== 'string' || (prov['name'] as string).length === 0) continue
        const cp = new CNProvider()
        cp.id = prov['id'] as string
        cp.name = prov['name'] as string
        cp.baseURL = typeof prov['baseURL'] === 'string' ? (prov['baseURL'] as string) : ''
        cp.npm = typeof prov['npm'] === 'string' ? (prov['npm'] as string) : '@ai-sdk/openai-compatible'
        cp.apiKey = typeof prov['apiKey'] === 'string' ? (prov['apiKey'] as string) : ''
        cp.apiKeyMode = (prov['apiKeyMode'] === 'env' || prov['apiKeyMode'] === 'direct') ? (prov['apiKeyMode'] as string) : 'env'
        cp.authEnv = typeof prov['authEnv'] === 'string' ? (prov['authEnv'] as string) : 'OPENAI_API_KEY'
        cp.apiKeyRef = typeof prov['apiKeyRef'] === 'string' ? (prov['apiKeyRef'] as string) : cp.authEnv
        cp.enabled = prov['enabled'] === true
        cp.builtIn = prov['builtIn'] === true
        cp.authStatus = (prov['authStatus'] === 'configured' || prov['authStatus'] === 'missing' || prov['authStatus'] === 'error') ? (prov['authStatus'] as string) : (cp.apiKey.length > 0 ? 'configured' : 'missing')
        // headers / models 不在这里重建,留给 ProviderRegistry.mergeProvider 处理 (它有更完整的深拷贝逻辑)
        if (Array.isArray(prov['headers'])) cp.headers = prov['headers'] as Object[] as never
        if (Array.isArray(prov['models'])) cp.models = prov['models'] as Object[] as never
        valid.push(cp)
      }
      Logger.info(`loadProviders: kept ${valid.length}/${parsed.length} entries after validation`)
      return valid
    } catch (e) {
      Logger.warn(`loadProviders parse failed: ${errStr(e)}`)
      return []
    }
  }

  /**
   * 清掉 storage 里的 provider 配置,让应用启动时用 createDefaultProviders()
   * 重新生成。用于"重置为默认"按钮,尤其在 baseURL/协议变更后需要立刻生效。
   */
  async resetProviders(): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.delete(PROVIDERS_KEY)
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async saveServerUrl(url: string): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(SERVER_URL_KEY, url)
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async getServerUrl(): Promise<string> {
    if (this.store === null) return 'http://127.0.0.1:4096'
    try {
      return (await this.store.get(SERVER_URL_KEY, 'http://127.0.0.1:4096')) as string
    } catch (e) {
      return 'http://127.0.0.1:4096'
    }
  }

  async saveWorkspacePath(path: string): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(WORKSPACE_KEY, path)
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async getWorkspacePath(): Promise<string> {
    if (this.store === null) return ''
    try {
      return (await this.store.get(WORKSPACE_KEY, '')) as string
    } catch (e) {
      return ''
    }
  }

  async addRecentWorkspace(path: string): Promise<void> {
    if (this.store === null) return
    try {
      const raw = (await this.store.get(RECENT_WORKSPACES_KEY, '[]')) as string
      let list: string[] = []
      try {
        list = JSON.parse(raw) as string[]
      } catch (e) {
        list = []
      }
      const newList: string[] = [path]
      for (const p of list) {
        if (p !== path && newList.length < 20) newList.push(p)
      }
      await this.store.put(RECENT_WORKSPACES_KEY, JSON.stringify(newList))
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async getRecentWorkspaces(): Promise<string[]> {
    if (this.store === null) return []
    try {
      const raw = await this.store.get(RECENT_WORKSPACES_KEY, '[]') as string
      return JSON.parse(raw) as string[]
    } catch {
      return []
    }
  }

  async saveSettings(settings: AppSettings): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(SETTINGS_KEY, JSON.stringify(settings))
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async loadSettings(): Promise<AppSettings> {
    if (this.store === null) return new AppSettings()
    try {
      const raw = await this.store.get(SETTINGS_KEY, '{}') as string
      const parsed = JSON.parse(raw) as Record<string, Object>
      const s = new AppSettings()
      if (typeof parsed['fontSize'] === 'number') s.fontSize = parsed['fontSize'] as number
      if (typeof parsed['darkMode'] === 'boolean') s.darkMode = parsed['darkMode'] as boolean
      if (typeof parsed['defaultAgent'] === 'string') s.defaultAgent = parsed['defaultAgent'] as string
      if (typeof parsed['defaultModel'] === 'string') s.defaultModel = parsed['defaultModel'] as string
      if (typeof parsed['defaultSmallModel'] === 'string') s.defaultSmallModel = parsed['defaultSmallModel'] as string
      if (typeof parsed['networkTimeout'] === 'number') s.networkTimeout = parsed['networkTimeout'] as number
      return s
    } catch {
      return new AppSettings()
    }
  }

  async getLocalServerConfig(): Promise<Record<string, Object> | null> {
    if (this.store === null) return null
    try {
      const raw = (await this.store.get(LOCAL_SERVER_CONFIG_KEY, '')) as string
      if (!raw || raw.length === 0) return null
      return JSON.parse(raw) as Record<string, Object>
    } catch (e) {
      return null
    }
  }

  // ─── Generic KV pass-through ──────────────────────────────────────────
  // 让 MainViewModel / 其他模块能用统一的 getString/setString 接口
  // 直接操作 preferences,避免再分裂出第二个 StorageService 实例。

  async getString(key: string, defaultValue: string = ''): Promise<string> {
    if (this.store === null) return defaultValue
    try {
      return (await this.store.get(key, defaultValue)) as string
    } catch (e) {
      Logger.error(`StorageService.getString(${key}) failed: ${errStr(e)}`)
      return defaultValue
    }
  }

  async setString(key: string, value: string): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(key, value)
      await this.store.flush()
    } catch (e) {
      Logger.error(`StorageService.setString(${key}) failed: ${errStr(e)}`)
    }
  }

  async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    if (this.store === null) return defaultValue
    try {
      return (await this.store.get(key, defaultValue)) as number
    } catch (e) {
      Logger.error(`StorageService.getNumber(${key}) failed: ${errStr(e)}`)
      return defaultValue
    }
  }

  async setNumber(key: string, value: number): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(key, value)
      await this.store.flush()
    } catch (e) {
      Logger.error(`StorageService.setNumber(${key}) failed: ${errStr(e)}`)
    }
  }

  async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    if (this.store === null) return defaultValue
    try {
      return (await this.store.get(key, defaultValue)) as boolean
    } catch (e) {
      Logger.error(`StorageService.getBoolean(${key}) failed: ${errStr(e)}`)
      return defaultValue
    }
  }

  async setBoolean(key: string, value: boolean): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(key, value)
      await this.store.flush()
    } catch (e) {
      Logger.error(`StorageService.setBoolean(${key}) failed: ${errStr(e)}`)
    }
  }

  async deleteKey(key: string): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.delete(key)
      await this.store.flush()
    } catch (e) {
      Logger.error(`StorageService.delete(${key}) failed: ${errStr(e)}`)
    }
  }

  async setLocalServerConfig(config: Record<string, Object>): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.put(LOCAL_SERVER_CONFIG_KEY, JSON.stringify(config))
      await this.store.flush()
    } catch (e) {
      return
    }
  }

  async clearAll(): Promise<void> {
    if (this.store === null) return
    try {
      await this.store.delete(RUNNERS_KEY)
      await this.store.delete(ACTIVE_RUNNER_KEY)
      await this.store.delete(PROVIDERS_KEY)
      await this.store.delete(SERVER_URL_KEY)
      await this.store.delete(WORKSPACE_KEY)
      await this.store.delete(RECENT_WORKSPACES_KEY)
      await this.store.delete(SETTINGS_KEY)
      await this.store.delete(LOCAL_SERVER_CONFIG_KEY)
      await this.store.flush()
    } catch (e) {
      return
    }
  }
}

export class AppSettings {
  fontSize: number = 14
  darkMode: boolean = false
  defaultAgent: string = 'build'
  defaultModel: string = ''
  defaultSmallModel: string = ''
  networkTimeout: number = 30000
}

export const storageService = new StorageService()

/**
 * Initialize the global storageService singleton.
 * Must be called once during app startup (e.g. in Index.aboutToAppear).
 */
export async function initStorageService(context: Context): Promise<void> {
  await storageService.init(context)
}
