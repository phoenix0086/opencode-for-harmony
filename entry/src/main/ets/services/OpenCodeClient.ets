import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { Runner, runnerBaseUrl } from '../models/Runner'
import {
  HealthInfo, ConfigInfo, SessionInfo,
  WithParts, RawPart, NormalizedMessage, NormalizedPart,
  PermissionRequest, FileDiff, VcsInfo, VcsFileStatus,
  ProjectInfo, AgentInfo, PathInfo,
  ProviderListResult, ProviderPublicInfo
} from '../models/Event'

/**
 * OpenCode Server API 客户端
 * 严格对齐 OpenCode v1.16.2 HTTP API (source-verified)
 */
export class OpenCodeClient {
  private baseUrl: string = ''
  private username: string = 'opencode'
  private password: string = ''
  private directory: string = ''
  private defaultAgent: string = 'build'

  constructor(runner: Runner) {
    this.baseUrl = runnerBaseUrl(runner)
    if (runner.token) {
      this.password = runner.token
    }
  }

  setDirectory(dir: string): void {
    this.directory = dir
  }

  setDefaultAgent(agent: string): void {
    this.defaultAgent = agent
  }

  private buildAuthHeader(): string {
    if (this.password.length === 0) {
      return ''
    }
    const encoder = new util.TextEncoder()
    const data = encoder.encodeInto(`${this.username}:${this.password}`)
    const base64Helper = new util.Base64Helper()
    const encoded = base64Helper.encodeToStringSync(data)
    return `Basic ${encoded}`
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {}
    headers['Content-Type'] = 'application/json'
    const auth = this.buildAuthHeader()
    if (auth.length > 0) {
      headers['Authorization'] = auth
    }
    if (this.directory.length > 0) {
      headers['x-opencode-directory'] = this.directory
    }
    return headers
  }

  /**
   * Append ?directory=... to any URL (respects existing query params)
   */
  private appendDir(url: string): string {
    if (this.directory.length === 0) return url
    const sep = url.includes('?') ? '&' : '?'
    return `${url}${sep}directory=${encodeURIComponent(this.directory)}`
  }

  private async doRequest(url: string, method: http.RequestMethod, body?: string): Promise<http.HttpResponse> {
    const req = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: method,
      header: this.buildHeaders(),
      connectTimeout: 10000,
      readTimeout: 60000,
    }
    if (body) {
      options.extraData = body
    }
    const resp = await req.request(url, options)
    req.destroy()
    return resp
  }

  private async doGet(path: string): Promise<http.HttpResponse> {
    const url = this.appendDir(`${this.baseUrl}${path}`)
    return this.doRequest(url, http.RequestMethod.GET)
  }

  private async doPost(path: string, body?: string): Promise<http.HttpResponse> {
    const url = this.appendDir(`${this.baseUrl}${path}`)
    return this.doRequest(url, http.RequestMethod.POST, body)
  }

  private async doPatch(path: string, body?: string): Promise<http.HttpResponse> {
    // ArkTS http.RequestMethod 枚举不包含 PATCH
    // 使用 POST + X-HTTP-Method-Override 头
    const url = this.appendDir(`${this.baseUrl}${path}`)
    const headers = this.buildHeaders()
    headers['X-HTTP-Method-Override'] = 'PATCH'
    const req = http.createHttp()
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      connectTimeout: 10000,
      readTimeout: 60000,
    }
    if (body) {
      options.extraData = body
    }
    const resp = await req.request(url, options)
    req.destroy()
    return resp
  }

  private async doPut(path: string, body?: string): Promise<http.HttpResponse> {
    const url = this.appendDir(`${this.baseUrl}${path}`)
    return this.doRequest(url, http.RequestMethod.PUT, body)
  }

  private async doDelete(path: string): Promise<http.HttpResponse> {
    const url = this.appendDir(`${this.baseUrl}${path}`)
    return this.doRequest(url, http.RequestMethod.DELETE)
  }

  private parseJson<T>(resp: http.HttpResponse): T {
    return JSON.parse(resp.result as string) as T
  }

  private checkResponse(resp: http.HttpResponse): void {
    if (resp.responseCode >= 400) {
      let errMsg = `HTTP ${resp.responseCode}`
      try {
        const body = JSON.parse(resp.result as string) as Record<string, string>
        if (body['error'] && body['error'].length > 0) {
          errMsg = body['error']
        } else if (body['message'] && body['message'].length > 0) {
          errMsg = body['message']
        }
      } catch (e) {
        // Use status code only
      }
      throw new Error(errMsg)
    }
  }

  // ══════════ Health ══════════
  // GET /global/health → { healthy: true, version: string }

  async health(): Promise<HealthResult> {
    try {
      const resp = await this.doGet('/global/health')
      if (resp.responseCode !== 200) {
        const r = new HealthResult()
        r.ok = false
        r.error = `HTTP ${resp.responseCode}`
        return r
      }
      const data = this.parseJson<HealthInfo>(resp)
      const r = new HealthResult()
      r.ok = data.healthy
      r.version = data.version
      return r
    } catch (e) {
      const r = new HealthResult()
      r.ok = false
      r.error = String(e)
      return r
    }
  }

  // ══════════ Config ══════════
  // GET /config → ConfigV1.Info
  // PATCH /config → ConfigV1.Info

  async getConfig(): Promise<ConfigInfo> {
    const resp = await this.doGet('/config')
    if (resp.responseCode !== 200) {
      return new ConfigInfo()
    }
    const raw = JSON.parse(resp.result as string) as Record<string, Object>
    const config = new ConfigInfo()
    config.model = (raw['model'] as string) || ''
    config.smallModel = (raw['small_model'] as string) || (raw['smallModel'] as string) || ''
    config.provider = (raw['provider'] as Record<string, Object>) || {}
    config.permission = (raw['permission'] as Record<string, string>) || {}
    return config
  }

  async updateConfig(config: Record<string, Object>): Promise<ConfigInfo> {
    const resp = await this.doPatch('/config', JSON.stringify(config))
    this.checkResponse(resp)
    return this.parseJson<ConfigInfo>(resp)
  }

  async getConfigProviders(): Promise<Record<string, Object>> {
    const resp = await this.doGet('/config/providers')
    this.checkResponse(resp)
    return this.parseJson<Record<string, Object>>(resp)
  }

  // ══════════ Provider ══════════
  // GET /provider → { all: ProviderPublicInfo[], default: Record, connected: string[] }

  async listProviders(): Promise<ProviderListResult> {
    const resp = await this.doGet('/provider')
    this.checkResponse(resp)
    const raw = this.parseJson<ProviderListResult>(resp)
    return raw
  }

  async getAuthMethods(): Promise<Record<string, Object>> {
    const resp = await this.doGet('/provider/auth')
    this.checkResponse(resp)
    return this.parseJson<Record<string, Object>>(resp)
  }

  // ══════════ Auth ══════════
  // PUT /auth/:providerID → body: { type:"api", key:string } → boolean
  // DELETE /auth/:providerID → boolean

  async setAuth(providerID: string, apiKey: string): Promise<boolean> {
    const body: Record<string, string> = {}
    body['type'] = 'api'
    body['key'] = apiKey
    const resp = await this.doPut(`/auth/${providerID}`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  async removeAuth(providerID: string): Promise<boolean> {
    const resp = await this.doDelete(`/auth/${providerID}`)
    return resp.responseCode === 200
  }

  // ══════════ Project ══════════
  // GET /project → ProjectInfo[]
  // GET /project/current → ProjectInfo

  async listProjects(): Promise<ProjectInfo[]> {
    const resp = await this.doGet('/project')
    this.checkResponse(resp)
    return this.parseJson<ProjectInfo[]>(resp)
  }

  async getCurrentProject(): Promise<ProjectInfo> {
    const resp = await this.doGet('/project/current')
    this.checkResponse(resp)
    return this.parseJson<ProjectInfo>(resp)
  }

  // ══════════ Path / File ══════════
  // GET /path → { home, state, config, worktree, directory }
  // GET /file?path=... → { name, path, absolute, type, ignored }[]
  // GET /file/content?path=... → FileContent

  async getPaths(): Promise<PathInfo> {
    const resp = await this.doGet('/path')
    this.checkResponse(resp)
    return this.parseJson<PathInfo>(resp)
  }

  async listFiles(path: string): Promise<Record<string, Object>[]> {
    const resp = await this.doGet(`/file?path=${encodeURIComponent(path)}`)
    this.checkResponse(resp)
    return this.parseJson<Record<string, Object>[]>(resp)
  }

  async readFile(filePath: string): Promise<Record<string, Object>> {
    const resp = await this.doGet(`/file/content?path=${encodeURIComponent(filePath)}`)
    this.checkResponse(resp)
    return this.parseJson<Record<string, Object>>(resp)
  }

  // ══════════ VCS ══════════
  // GET /vcs → { branch?, default_branch? }
  // GET /vcs/status → VcsFileStatus[]
  // GET /vcs/diff?mode=git|branch → FileDiff[]

  async getVcsInfo(): Promise<VcsInfo> {
    const resp = await this.doGet('/vcs')
    this.checkResponse(resp)
    const raw = this.parseJson<Record<string, string>>(resp)
    const info = new VcsInfo()
    info.branch = raw['branch'] || ''
    info.defaultBranch = raw['default_branch'] || ''
    return info
  }

  async getVcsStatus(): Promise<VcsFileStatus[]> {
    const resp = await this.doGet('/vcs/status')
    this.checkResponse(resp)
    return this.parseJson<VcsFileStatus[]>(resp)
  }

  async getVcsDiff(mode: string): Promise<FileDiff[]> {
    const m = mode.length > 0 ? mode : 'git'
    const resp = await this.doGet(`/vcs/diff?mode=${m}`)
    this.checkResponse(resp)
    return this.parseJson<FileDiff[]>(resp)
  }

  // ══════════ Session ══════════
  // GET /session → SessionInfo[]
  // POST /session → SessionInfo
  // GET /session/:id → SessionInfo
  // DELETE /session/:id → boolean
  // PATCH /session/:id → SessionInfo
  // POST /session/:id/abort → boolean

  async listSessions(limit?: number): Promise<SessionInfo[]> {
    let path = '/session'
    if (limit && limit > 0) {
      path = `/session?limit=${limit}`
    }
    const resp = await this.doGet(path)
    this.checkResponse(resp)
    return this.parseJson<SessionInfo[]>(resp)
  }

  async getSession(sessionID: string): Promise<SessionInfo> {
    const resp = await this.doGet(`/session/${sessionID}`)
    this.checkResponse(resp)
    return this.parseJson<SessionInfo>(resp)
  }

  async createSession(title?: string): Promise<SessionInfo> {
    const body: Record<string, string> = {}
    if (title && title.length > 0) {
      body['title'] = title
    }
    const resp = await this.doPost('/session', JSON.stringify(body))
    this.checkResponse(resp)
    return this.parseJson<SessionInfo>(resp)
  }

  async deleteSession(sessionID: string): Promise<boolean> {
    const resp = await this.doDelete(`/session/${sessionID}`)
    return resp.responseCode === 200
  }

  async updateSession(sessionID: string, updates: Record<string, Object>): Promise<SessionInfo> {
    const resp = await this.doPatch(`/session/${sessionID}`, JSON.stringify(updates))
    this.checkResponse(resp)
    return this.parseJson<SessionInfo>(resp)
  }

  async abortSession(sessionID: string): Promise<boolean> {
    const resp = await this.doPost(`/session/${sessionID}/abort`)
    return resp.responseCode === 200
  }

  // ══════════ Messages ══════════
  // GET /session/:id/message → WithParts[] (raw)
  // POST /session/:id/message → WithParts (sync prompt)
  // POST /session/:id/prompt_async → 204 No Content (async prompt)

  async getMessagesRaw(sessionID: string, limit?: number): Promise<WithParts[]> {
    let path = `/session/${sessionID}/message`
    if (limit && limit > 0) {
      path = `${path}?limit=${limit}`
    }
    const resp = await this.doGet(path)
    if (resp.responseCode !== 200) {
      const empty: WithParts[] = []
      return empty
    }
    return this.parseJson<WithParts[]>(resp)
  }

  /**
   * 获取消息并自动 normalize 为 UI 友好格式
   */
  async getMessages(sessionID: string, limit?: number): Promise<NormalizedMessage[]> {
    const raw = await this.getMessagesRaw(sessionID, limit)
    return normalizeMessages(raw)
  }

  /**
   * 同步发送消息 (阻塞直到 Agent 回复)
   */
  async sendMessage(sessionID: string, content: string): Promise<Record<string, Object>> {
    const body = this.buildPromptBody(content)
    const resp = await this.doPost(`/session/${sessionID}/message`, JSON.stringify(body))
    this.checkResponse(resp)
    return this.parseJson<Record<string, Object>>(resp)
  }

  /**
   * 异步发送消息 (立即返回, Agent 在后台处理)
   * 真实 API 返回 204 No Content
   */
  async sendMessageAsync(sessionID: string, content: string): Promise<boolean> {
    const body = this.buildPromptBody(content)
    const resp = await this.doPost(`/session/${sessionID}/prompt_async`, JSON.stringify(body))
    return resp.responseCode === 204 || resp.responseCode === 200
  }

  private buildPromptBody(content: string): Record<string, Object> {
    const textPart: Record<string, string> = {}
    textPart['type'] = 'text'
    textPart['text'] = content
    const parts: Record<string, string>[] = []
    parts.push(textPart)
    const body: Record<string, Object> = {}
    body['agent'] = this.defaultAgent
    body['parts'] = parts
    return body
  }

  // ══════════ Permission ══════════
  // GET /permission → PermissionRequest[]
  // POST /permission/:requestID/reply → { reply: "once"|"always"|"deny" } → boolean

  async listPermissions(): Promise<PermissionRequest[]> {
    const resp = await this.doGet('/permission')
    this.checkResponse(resp)
    return this.parseJson<PermissionRequest[]>(resp)
  }

  /**
   * 回复权限请求
   * @param reply - "once" (本次允许), "always" (永久允许), "deny" (拒绝)
   */
  async replyPermission(requestID: string, reply: string): Promise<boolean> {
    const body: Record<string, string> = {}
    body['reply'] = reply
    const resp = await this.doPost(`/permission/${requestID}/reply`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  // ══════════ Diff ══════════
  // GET /session/:id/diff?messageID=... → FileDiff[]

  async getSessionDiff(sessionID: string, messageID: string): Promise<FileDiff[]> {
    const resp = await this.doGet(`/session/${sessionID}/diff?messageID=${encodeURIComponent(messageID)}`)
    if (resp.responseCode !== 200) {
      const empty: FileDiff[] = []
      return empty
    }
    return this.parseJson<FileDiff[]>(resp)
  }

  // ══════════ Agent ══════════

  async listAgents(): Promise<AgentInfo[]> {
    const resp = await this.doGet('/agent')
    this.checkResponse(resp)
    return this.parseJson<AgentInfo[]>(resp)
  }

  // ══════════ Instance ══════════

  async disposeInstance(): Promise<boolean> {
    const resp = await this.doPost('/instance/dispose')
    this.checkResponse(resp)
    return resp.responseCode === 200
  }

  // ══════════ SSE Event Stream URL ══════════

  getEventStreamUrl(): string {
    return this.appendDir(`${this.baseUrl}/event`)
  }

  getAuthHeaders(): Record<string, string> {
    return this.buildHeaders()
  }
}

// ══════════ Health Result ══════════

export class HealthResult {
  ok: boolean = false
  version: string = ''
  error: string = ''
}

// ══════════ Normalize Functions ══════════

/**
 * WithParts[] → NormalizedMessage[]
 * 将原始 API 的 { info, parts } 结构转换为 UI 友好的扁平格式
 */
export function normalizeMessages(raw: WithParts[]): NormalizedMessage[] {
  const result: NormalizedMessage[] = []
  for (const item of raw) {
    const msg = new NormalizedMessage()
    msg.id = item.info.id
    msg.role = item.info.role
    msg.sessionID = item.info.sessionID

    for (const part of item.parts) {
      const np = new NormalizedPart()
      if (part.type === 'text') {
        np.type = 'text'
        np.content = part.text
      } else if (part.type === 'tool') {
        np.type = 'tool-invocation'
        np.id = part.callID
        np.toolName = part.tool
        np.toolState = (part.state['status'] as string) || ''
        np.toolResult = (part.state['output'] as string) || ''
        // Serialize input args to string for display
        try {
          const inputObj = part.state['input']
          if (inputObj !== undefined && inputObj !== null) {
            np.toolArgs = JSON.stringify(inputObj)
          } else {
            np.toolArgs = ''
          }
        } catch (e) {
          np.toolArgs = ''
        }
      } else if (part.type === 'reasoning') {
        np.type = 'reasoning'
        np.content = part.text
      } else {
        np.type = part.type
        np.content = part.text
      }
      msg.parts.push(np)
    }

    result.push(msg)
  }
  return result
}

/**
 * Normalize provider list from API response
 */
export function normalizeProviderList(raw: ProviderListResult): ProviderPublicInfo[] {
  return raw.all
}

/**
 * Normalize VCS info — extract branch name
 */
export function normalizeVcsBranch(raw: Record<string, string>): string {
  return raw['branch'] || raw['default_branch'] || ''
}

/**
 * Normalize file diff — ensure all fields have defaults
 */
export function normalizeFileDiffs(raw: FileDiff[]): FileDiff[] {
  const result: FileDiff[] = []
  for (const d of raw) {
    const diff = new FileDiff()
    diff.file = d.file || ''
    diff.patch = d.patch || ''
    diff.additions = d.additions || 0
    diff.deletions = d.deletions || 0
    diff.status = d.status || ''
    result.push(diff)
  }
  return result
}
