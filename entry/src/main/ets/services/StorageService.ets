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
    this.store = await preferences.getPreferences(context, STORE_NAME)
  }

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

  async saveProviders(providers: CNProvider[]): Promise<void> {
    if (this.store === null) return
    await this.store.put(PROVIDERS_KEY, JSON.stringify(providers))
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

  async saveServerUrl(url: string): Promise<void> {
    if (this.store === null) return
    await this.store.put(SERVER_URL_KEY, url)
    await this.store.flush()
  }

  async getServerUrl(): Promise<string> {
    if (this.store === null) return 'http://127.0.0.1:4096'
    return (await this.store.get(SERVER_URL_KEY, 'http://127.0.0.1:4096')) as string
  }

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
    const newList: string[] = [path]
    for (const p of list) {
      if (p !== path && newList.length < 20) newList.push(p)
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

  async clearAll(): Promise<void> {
    if (this.store === null) return
    await this.store.clear()
    await this.store.flush()
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
