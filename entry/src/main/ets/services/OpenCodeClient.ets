import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { Runner, runnerBaseUrl } from '../models/Runner'
import {
  HealthInfo, ConfigInfo, SessionInfo,
  WithParts, RawPart, NormalizedMessage, NormalizedPart,
  PermissionRequest, QuestionRequest, FileDiff, VcsInfo, VcsFileStatus,
  ProjectInfo, AgentInfo, PathInfo,
  ProviderListResult, ProviderPublicInfo, TodoItem
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
    const encoded = encoder.encodeInto(`${this.username}:${this.password}`)
    const base64Helper = new util.Base64Helper()
    const b64 = base64Helper.encodeToStringSync(encoded)
    return `Basic ${b64}`
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
    // PATCH /config in v1.16.2 may return 200 with empty body, or a partial
    // ConfigInfo. Avoid JSON.parse('') crash — return a fresh ConfigInfo on
    // empty / non-JSON bodies.
    const raw = resp.result as string
    if (!raw || raw.length === 0) {
      const fallback = new ConfigInfo()
      fallback.model = (config['model'] as string) || ''
      return fallback
    }
    try {
      return this.parseJson<ConfigInfo>(resp)
    } catch (e) {
      const fallback = new ConfigInfo()
      fallback.model = (config['model'] as string) || ''
      return fallback
    }
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
    const raw = this.parseJson<Record<string, Object>[]>(resp)
    const out: SessionInfo[] = []
    for (const item of raw) {
      out.push(normalizeSession(item))
    }
    return out
  }

  async getSession(sessionID: string): Promise<SessionInfo> {
    const resp = await this.doGet(`/session/${sessionID}`)
    this.checkResponse(resp)
    return normalizeSession(this.parseJson<Record<string, Object>>(resp))
  }

  async createSession(title?: string): Promise<SessionInfo> {
    const body: Record<string, string> = {}
    if (title && title.length > 0) {
      body['title'] = title
    }
    const resp = await this.doPost('/session', JSON.stringify(body))
    this.checkResponse(resp)
    return normalizeSession(this.parseJson<Record<string, Object>>(resp))
  }

  async deleteSession(sessionID: string): Promise<boolean> {
    const resp = await this.doDelete(`/session/${sessionID}`)
    return resp.responseCode === 200
  }

  /**
   * Rename a session by title.
   */
  async renameSession(sessionID: string, title: string): Promise<SessionInfo> {
    const body: Record<string, Object> = {}
    body['title'] = title
    return this.updateSession(sessionID, body)
  }

  /**
   * Fork a session.
   * v1 server does not implement /session/:id/fork; call will fail with 404.
   * Fall back to a copy of the title.
   */
  async forkSession(sessionID: string): Promise<SessionInfo> {
    let parentTitle = ''
    try {
      const parent = await this.getSession(sessionID)
      parentTitle = parent.title
    } catch (e) {
      // ignore
    }
    const body: Record<string, string> = {}
    body['parentID'] = sessionID
    if (parentTitle.length > 0) {
      body['title'] = `${parentTitle} (fork)`
    }
    const resp = await this.doPost(`/session/${sessionID}/fork`, JSON.stringify(body))
    if (resp.responseCode === 404 || resp.responseCode === 405) {
      // Server does not support fork — fall back to plain createSession
      return this.createSession(parentTitle.length > 0 ? `${parentTitle} (copy)` : '')
    }
    this.checkResponse(resp)
    return normalizeSession(this.parseJson<Record<string, Object>>(resp))
  }

  async updateSession(sessionID: string, updates: Record<string, Object>): Promise<SessionInfo> {
    const resp = await this.doPatch(`/session/${sessionID}`, JSON.stringify(updates))
    this.checkResponse(resp)
    return normalizeSession(this.parseJson<Record<string, Object>>(resp))
  }

  async abortSession(sessionID: string): Promise<boolean> {
    const resp = await this.doPost(`/session/${sessionID}/abort`)
    return resp.responseCode === 200
  }

  /**
   * POST /session/:id/compact to request context compaction.
   * v1 server returns 404/405; we surface that to the caller as `false`
   * so the UI can show "unsupported" instead of crashing.
   */
  async requestCompact(sessionID: string): Promise<boolean> {
    try {
      const resp = await this.doPost(`/session/${sessionID}/compact`, '{}')
      if (resp.responseCode === 200 || resp.responseCode === 204) {
        return true
      }
      return false
    } catch (e) {
      return false
    }
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
   * Same as getMessages() but also returns the raw WithParts list so the
   * caller can read info.tokens / info.cost without a second request.
   * Used by Index.loadMessages to update the context usage indicator.
   */
  async getMessagesWithRaw(sessionID: string, limit?: number): Promise<MessagesWithRaw> {
    const raw = await this.getMessagesRaw(sessionID, limit)
    const out = new MessagesWithRaw()
    out.normalized = normalizeMessages(raw)
    out.raw = raw
    return out
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
  // POST /session/:sessionID/permissions/:requestID/reply (M14: session-scoped reply)

  async listPermissions(): Promise<PermissionRequest[]> {
    const resp = await this.doGet('/permission')
    this.checkResponse(resp)
    return this.parseJson<PermissionRequest[]>(resp)
  }

  /**
   * Reply to a permission request at the global /permission endpoint.
   * @param reply - "once" (本次允许), "always" (永久允许), "deny" (拒绝)
   */
  async replyPermission(requestID: string, reply: string): Promise<boolean> {
    const body: Record<string, string> = {}
    body['reply'] = reply
    const resp = await this.doPost(`/permission/${requestID}/reply`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  /**
   * M14: Reply to a session-scoped permission request.
   * Some v1.x servers route /permission/:id/reply under the session namespace;
   * we hit the more specific endpoint first and fall back to the global one
   * if the server returns 404/405.
   *
   * @param sessionID - the session that owns the request
   * @param requestID - the permission request id
   * @param reply     - "once" | "always" | "deny"
   */
  async replySessionPermission(sessionID: string, requestID: string, reply: string): Promise<boolean> {
    if (sessionID.length === 0 || requestID.length === 0) return false
    const body: Record<string, string> = {}
    body['reply'] = reply
    const sessionPath = `/session/${encodeURIComponent(sessionID)}/permissions/${encodeURIComponent(requestID)}/reply`
    try {
      const resp = await this.doPost(sessionPath, JSON.stringify(body))
      if (resp.responseCode === 200) return true
      // Server does not implement session-scoped route — fall through to global
    } catch (e) {
      // network/parse error: try the global endpoint as a last resort
    }
    return this.replyPermission(requestID, reply)
  }

  // ══════════ Question (Sprint 1-A.2) ══════════
  // Server may not implement /question in v1.x; calls fail soft.
  // v2 server: GET /question?sessionID=... ; POST /question/:id/reply

  async listQuestions(sessionID: string): Promise<QuestionRequest[]> {
    const url = `/question?sessionID=${encodeURIComponent(sessionID)}`
    const resp = await this.doGet(url)
    if (resp.responseCode !== 200) {
      const empty: QuestionRequest[] = []
      return empty
    }
    try {
      return this.parseJson<QuestionRequest[]>(resp)
    } catch (e) {
      const empty: QuestionRequest[] = []
      return empty
    }
  }

  async replyQuestion(requestID: string, optionIDs: string[]): Promise<boolean> {
    const body: Record<string, Object> = {}
    body['optionIDs'] = optionIDs
    const resp = await this.doPost(`/question/${requestID}/reply`, JSON.stringify(body))
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

  // ══════════ MCP / LSP / Formatter ══════════
  // GET /mcp → McpServer[]
  // GET /lsp → LspStatus[]
  // GET /formatter → FormatterStatus[]

  private async fetchJsonList(path: string): Promise<Record<string, Object>[]> {
    try {
      const resp = await this.doGet(path)
      if (resp.responseCode !== 200) {
        const empty: Record<string, Object>[] = []
        return empty
      }
      return this.parseJson<Record<string, Object>[]>(resp)
    } catch (e) {
      const empty: Record<string, Object>[] = []
      return empty
    }
  }

  async listMcpServers(): Promise<Record<string, Object>[]> {
    return this.fetchJsonList('/mcp')
  }

  async listLspStatus(): Promise<Record<string, Object>[]> {
    return this.fetchJsonList('/lsp')
  }

  async listFormatters(): Promise<Record<string, Object>[]> {
    return this.fetchJsonList('/formatter')
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

// ══════════ Messages With Raw ══════════

/**
 * Combined result for getMessagesWithRaw(): normalized view + raw WithParts
 * so callers can read info.tokens / info.cost without a second HTTP request.
 */
export class MessagesWithRaw {
  normalized: NormalizedMessage[] = []
  raw: WithParts[] = []
}

// ══════════ Normalize Functions ══════════

/**
 * WithParts[] → NormalizedMessage[]
 * 将原始 API 的 { info, parts } 结构转换为 UI 友好的扁平格式
 */
/**
 * Record<string, Object> → SessionInfo
 * 保证 model / time / tokens / summary 四个嵌套对象一定有默认实例
 * (parseJson<T> 不会跑类初始化器,直接 JSON.parse 后嵌套对象是 undefined)
 */
export function normalizeSession(raw: Record<string, Object>): SessionInfo {
  const info = new SessionInfo()
  info.id = (raw['id'] as string) || ''
  info.slug = (raw['slug'] as string) || ''
  info.title = (raw['title'] as string) || ''
  info.projectID = (raw['projectID'] as string) || (raw['project_id'] as string) || ''
  info.directory = (raw['directory'] as string) || ''
  info.agent = (raw['agent'] as string) || ''
  info.version = (raw['version'] as string) || ''
  info.cost = (raw['cost'] as number) || 0

  // defensive: extra fields the API may also include
  info.workspaceID = (raw['workspaceID'] as string) || (raw['workspace_id'] as string) || ''
  info.path = (raw['path'] as string) || ''

  const time = raw['time'] as Record<string, Object> | undefined
  if (time) {
    info.time.created = (time['created'] as number) || 0
    info.time.updated = (time['updated'] as number) || 0
  }

  const model = raw['model'] as Record<string, Object> | undefined
  if (model) {
    info.model.id = (model['id'] as string) || ''
    info.model.providerID = (model['providerID'] as string) || (model['provider_id'] as string) || ''
    info.model.variant = (model['variant'] as string) || ''
  }

  const tokens = raw['tokens'] as Record<string, Object> | undefined
  if (tokens) {
    info.tokens.input = (tokens['input'] as number) || 0
    info.tokens.output = (tokens['output'] as number) || 0
    info.tokens.reasoning = (tokens['reasoning'] as number) || 0
  }

  const summary = raw['summary'] as Record<string, Object> | undefined
  if (summary) {
    info.summary.additions = (summary['additions'] as number) || 0
    info.summary.deletions = (summary['deletions'] as number) || 0
    info.summary.files = (summary['files'] as number) || 0
  }

  return info
}

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
      } else if (part.type === 'todo') {
        np.type = 'todo'
        np.content = ''
        np.todos = parseTodosFromPart(part)
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
 * Parse todos from a RawPart whose type is 'todo'.
 * Tolerates a few shapes seen in the wild:
 * - { type:'todo', todos:[{id,content,status,priority}] }
 * - { type:'todo', text:'[ ] ...' }  (markdown fallback)
 */
function parseTodosFromPart(part: RawPart): TodoItem[] {
  const direct: Object = part.state['todos']
  if (Array.isArray(direct)) {
    const out: TodoItem[] = []
    for (let i = 0; i < direct.length; i++) {
      const entry: Object = direct[i]
      if (entry === null || entry === undefined) continue
      const obj: Record<string, Object> = entry as Record<string, Object>
      const item = new TodoItem()
      item.id = (obj['id'] as string) || ''
      item.content = (obj['content'] as string) || (obj['text'] as string) || ''
      item.status = ((obj['status'] as string) || 'pending').toLowerCase()
      item.priority = ((obj['priority'] as string) || '').toLowerCase()
      if (item.content.length > 0) {
        out.push(item)
      }
    }
    return out
  }
  // Fallback: parse markdown checkboxes from text
  if (part.text.length > 0) {
    const out: TodoItem[] = []
    const lines = part.text.split('\n')
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      if (line.indexOf('[x]') >= 0 || line.indexOf('[X]') >= 0) {
        const item = new TodoItem()
        item.id = `t_${i}`
        item.status = 'completed'
        item.content = line.replace(/^\s*-\s*\[[xX]\]\s*/, '')
        out.push(item)
      } else if (line.indexOf('[ ]') >= 0) {
        const item = new TodoItem()
        item.id = `t_${i}`
        item.status = 'pending'
        item.content = line.replace(/^\s*-\s*\[\s\]\s*/, '')
        out.push(item)
      }
    }
    return out
  }
  return []
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
