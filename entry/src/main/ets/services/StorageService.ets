import { preferences } from '@kit.ArkData'
import { Runner } from '../models/Runner'
import { CNProvider } from '../models/Provider'

const STORE_NAME = 'opencode_prefs'
const RUNNERS_KEY = 'runners'
const ACTIVE_RUNNER_KEY = 'active_runner_id'
const PROVIDERS_KEY = 'cn_providers'
const SERVER_URL_KEY = 'server_url'
const WORKSPACE_KEY = 'workspace_path'
const RECENT_WORKSPACES_KEY = 'recent_workspaces'
const SETTINGS_KEY = 'app_settings'

/**
 * 本地持久化服务
 * 使用 HarmonyOS Preferences API 存储配置
 */
export class StorageService {
  private store: preferences.Preferences | null = null

  async init(context: Context): Promise<void> {
    this.store = await preferences.getPreferences(context, STORE_NAME)
  }

  // ══════════ Runner ══════════

  async saveRunners(runners: Runner[]): Promise<void> {
    if (this.store === null) return
    await this.store.put(RUNNERS_KEY, JSON.stringify(runners))
    await this.store.flush()
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
    await this.store.put(ACTIVE_RUNNER_KEY, id)
    await this.store.flush()
  }

  async getActiveRunnerId(): Promise<string> {
    if (this.store === null) return ''
    return (await this.store.get(ACTIVE_RUNNER_KEY, '')) as string
  }

  // ══════════ Provider ══════════

  async saveProviders(providers: CNProvider[]): Promise<void> {
    if (this.store === null) return
    // 保存时脱敏 apiKey
    const safe: CNProvider[] = []
    for (const p of providers) {
      const copy = new CNProvider()
      copy.id = p.id
      copy.name = p.name
      copy.npm = p.npm
      copy.baseURL = p.baseURL
      copy.authEnv = p.authEnv
      copy.models = p.models
      copy.enabled = p.enabled
      copy.authStatus = p.authStatus
      copy.apiKeyRef = p.apiKeyRef
      // 不保存实际 key
      safe.push(copy)
    }
    await this.store.put(PROVIDERS_KEY, JSON.stringify(safe))
    await this.store.flush()
  }

  async loadProviders(): Promise<CNProvider[]> {
    if (this.store === null) return []
    try {
      const raw = await this.store.get(PROVIDERS_KEY, '[]') as string
      return JSON.parse(raw) as CNProvider[]
    } catch {
      return []
    }
  }

  // ══════════ Server URL ══════════

  async saveServerUrl(url: string): Promise<void> {
    if (this.store === null) return
    await this.store.put(SERVER_URL_KEY, url)
    await this.store.flush()
  }

  async getServerUrl(): Promise<string> {
    if (this.store === null) return 'http://127.0.0.1:4096'
    return (await this.store.get(SERVER_URL_KEY, 'http://127.0.0.1:4096')) as string
  }

  // ══════════ Workspace ══════════

  async saveWorkspacePath(path: string): Promise<void> {
    if (this.store === null) return
    await this.store.put(WORKSPACE_KEY, path)
    await this.store.flush()
  }

  async getWorkspacePath(): Promise<string> {
    if (this.store === null) return ''
    return (await this.store.get(WORKSPACE_KEY, '')) as string
  }

  async addRecentWorkspace(path: string): Promise<void> {
    if (this.store === null) return
    const raw = await this.store.get(RECENT_WORKSPACES_KEY, '[]') as string
    let list: string[] = []
    try {
      list = JSON.parse(raw) as string[]
    } catch {
      list = []
    }
    // 去重
    const newList: string[] = [path]
    for (const p of list) {
      if (p !== path && newList.length < 20) {
        newList.push(p)
      }
    }
    await this.store.put(RECENT_WORKSPACES_KEY, JSON.stringify(newList))
    await this.store.flush()
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

  // ══════════ Settings ══════════

  async saveSettings(settings: AppSettings): Promise<void> {
    if (this.store === null) return
    await this.store.put(SETTINGS_KEY, JSON.stringify(settings))
    await this.store.flush()
  }

  async loadSettings(): Promise<AppSettings> {
    if (this.store === null) return new AppSettings()
    try {
      const raw = await this.store.get(SETTINGS_KEY, '{}') as string
      const parsed = JSON.parse(raw) as AppSettings
      // 填充默认值
      const s = new AppSettings()
      if (parsed.fontSize) s.fontSize = parsed.fontSize
      if (parsed.darkMode !== undefined) s.darkMode = parsed.darkMode
      if (parsed.defaultAgent) s.defaultAgent = parsed.defaultAgent
      if (parsed.defaultModel) s.defaultModel = parsed.defaultModel
      if (parsed.defaultSmallModel) s.defaultSmallModel = parsed.defaultSmallModel
      if (parsed.networkTimeout) s.networkTimeout = parsed.networkTimeout
      return s
    } catch {
      return new AppSettings()
    }
  }

  // ══════════ 清除 ══════════

  async clearAll(): Promise<void> {
    if (this.store === null) return
    await this.store.clear()
    await this.store.flush()
  }
}

/** 应用设置 */
export class AppSettings {
  fontSize: number = 14
  darkMode: boolean = false
  defaultAgent: string = 'build'
  defaultModel: string = ''
  defaultSmallModel: string = ''
  networkTimeout: number = 30000
}

export const storageService = new StorageService()
