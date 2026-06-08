import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { Runner, runnerBaseUrl } from '../models/Runner'
import {
  HealthInfo, ConfigInfo, ProviderInfo, SessionInfo,
  MessageInfo, MessagePart, PermissionRequest, FileDiff,
  ProjectInfo, VcsInfo, AgentInfo
} from '../models/Event'

/**
 * OpenCode Server API 客户端
 * 基于 OpenCode Server v1.16.2 OpenAPI spec
 */
export class OpenCodeClient {
  private baseUrl: string = ''
  private username: string = 'opencode'
  private password: string = ''
  private directory: string = ''

  constructor(runner: Runner) {
    this.baseUrl = runnerBaseUrl(runner)
    if (runner.token) {
      this.password = runner.token
    }
  }

  setDirectory(dir: string): void {
    this.directory = dir
  }

  private buildAuthHeader(): string {
    if (!this.password) {
      return ''
    }
    // Basic auth: base64(username:password)
    const encoder = new TextEncoder()
    const data = encoder.encode(`${this.username}:${this.password}`)
    // ArkTS 环境下使用简化的 base64 编码
    const base64Helper = new util.Base64Helper()
    const encoded = base64Helper.encodeToStringSync(data)
    return `Basic ${encoded}`
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    }
    const auth = this.buildAuthHeader()
    if (auth) {
      headers['Authorization'] = auth
    }
    if (this.directory) {
      headers['x-opencode-directory'] = this.directory
    }
    return headers
  }

  private dirQuery(): string {
    return this.directory ? `?directory=${encodeURIComponent(this.directory)}` : ''
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
    const sep = path.includes('?') ? '&' : '?'
    const dirPart = this.directory ? `${sep}directory=${encodeURIComponent(this.directory)}` : ''
    return this.doRequest(`${this.baseUrl}${path}${dirPart}`, http.RequestMethod.GET)
  }

  private async doPost(path: string, body?: string): Promise<http.HttpResponse> {
    return this.doRequest(`${this.baseUrl}${path}`, http.RequestMethod.POST, body)
  }

  private async doPatch(path: string, body?: string): Promise<http.HttpResponse> {
    return this.doRequest(`${this.baseUrl}${path}`, http.RequestMethod.PATCH, body)
  }

  private async doDelete(path: string): Promise<http.HttpResponse> {
    return this.doRequest(`${this.baseUrl}${path}`, http.RequestMethod.DELETE)
  }

  private parseJson<T>(resp: http.HttpResponse): T {
    return JSON.parse(resp.result as string) as T
  }

  // ══════════ 健康检查 ══════════

  async health(): Promise<HealthResult> {
    try {
      const resp = await this.doGet('/global/health')
      if (resp.responseCode !== 200) {
        return { ok: false, version: '', error: `HTTP ${resp.responseCode}` }
      }
      const data = JSON.parse(resp.result as string) as HealthInfo
      return { ok: true, version: data.version, error: '' }
    } catch (e) {
      return { ok: false, version: '', error: String(e) }
    }
  }

  // ══════════ Config ══════════

  async getConfig(): Promise<ConfigInfo> {
    const resp = await this.doGet('/config')
    return this.parseJson<ConfigInfo>(resp)
  }

  async updateConfig(config: Partial<ConfigInfo>): Promise<ConfigInfo> {
    const resp = await this.doPatch('/config', JSON.stringify(config))
    return this.parseJson<ConfigInfo>(resp)
  }

  async getConfigProviders(): Promise<Object> {
    const resp = await this.doGet('/config/providers')
    return this.parseJson<Object>(resp)
  }

  // ══════════ Provider ══════════

  async listProviders(): Promise<ProviderInfo[]> {
    const resp = await this.doGet('/provider')
    const data = this.parseJson<Object>(resp) as Record<string, ProviderInfo[]>
    return data.providers || []
  }

  async getAuthMethods(): Promise<Object> {
    const resp = await this.doGet('/provider/auth')
    return this.parseJson<Object>(resp)
  }

  // ══════════ Auth ══════════

  async setAuth(providerID: string, apiKey: string): Promise<boolean> {
    const body = JSON.stringify({ type: 'api', key: apiKey })
    const resp = await this.doRequest(
      `${this.baseUrl}/auth/${providerID}`,
      http.RequestMethod.PUT,
      body
    )
    return resp.responseCode === 200
  }

  async removeAuth(providerID: string): Promise<boolean> {
    const resp = await this.doDelete(`/auth/${providerID}`)
    return resp.responseCode === 200
  }

  // ══════════ Project ══════════

  async listProjects(): Promise<ProjectInfo[]> {
    const resp = await this.doGet('/project')
    return this.parseJson<ProjectInfo[]>(resp)
  }

  async getCurrentProject(): Promise<ProjectInfo> {
    const resp = await this.doGet('/project/current')
    return this.parseJson<ProjectInfo>(resp)
  }

  // ══════════ Session ══════════

  async listSessions(limit?: number): Promise<SessionInfo[]> {
    const path = limit ? `/session?limit=${limit}` : '/session'
    const resp = await this.doGet(path)
    return this.parseJson<SessionInfo[]>(resp)
  }

  async getSession(sessionID: string): Promise<SessionInfo> {
    const resp = await this.doGet(`/session/${sessionID}`)
    return this.parseJson<SessionInfo>(resp)
  }

  async createSession(): Promise<SessionInfo> {
    const resp = await this.doPost('/session', '{}')
    return this.parseJson<SessionInfo>(resp)
  }

  async deleteSession(sessionID: string): Promise<boolean> {
    const resp = await this.doDelete(`/session/${sessionID}`)
    return resp.responseCode === 200
  }

  async updateSession(sessionID: string, updates: Record<string, Object>): Promise<SessionInfo> {
    const resp = await this.doPatch(`/session/${sessionID}`, JSON.stringify(updates))
    return this.parseJson<SessionInfo>(resp)
  }

  async abortSession(sessionID: string): Promise<boolean> {
    const resp = await this.doPost(`/session/${sessionID}/abort`, '{}')
    return resp.responseCode === 200
  }

  // ══════════ Messages ══════════

  async getMessages(sessionID: string, limit?: number): Promise<MessageInfo[]> {
    const path = limit ? `/session/${sessionID}/message?limit=${limit}` : `/session/${sessionID}/message`
    const resp = await this.doGet(path)
    return this.parseJson<MessageInfo[]>(resp)
  }

  async sendMessage(sessionID: string, content: string, parts?: MessagePart[]): Promise<Object> {
    const body: Record<string, Object> = {
      parts: parts || [{ type: 'text', text: content }],
    }
    const resp = await this.doPost(`/session/${sessionID}/message`, JSON.stringify(body))
    return this.parseJson<Object>(resp)
  }

  async sendMessageAsync(sessionID: string, content: string): Promise<boolean> {
    const body: Record<string, Object> = {
      parts: [{ type: 'text', text: content }],
    }
    const resp = await this.doPost(`/session/${sessionID}/prompt_async`, JSON.stringify(body))
    return resp.responseCode === 202 || resp.responseCode === 200
  }

  // ══════════ Permission ══════════

  async listPermissions(): Promise<PermissionRequest[]> {
    const resp = await this.doGet('/permission')
    return this.parseJson<PermissionRequest[]>(resp)
  }

  async replyPermission(requestID: string, reply: string, message?: string): Promise<boolean> {
    const body: Record<string, Object> = { reply: reply }
    if (message) {
      body['message'] = message
    }
    const resp = await this.doPost(`/permission/${requestID}/reply`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  // ══════════ Diff / VCS ══════════

  async getSessionDiff(sessionID: string): Promise<FileDiff[]> {
    const resp = await this.doGet(`/session/${sessionID}/diff`)
    return this.parseJson<FileDiff[]>(resp)
  }

  async getVcsStatus(): Promise<VcsInfo> {
    const resp = await this.doGet('/vcs/status')
    return this.parseJson<VcsInfo>(resp)
  }

  async getVcsDiff(): Promise<FileDiff[]> {
    const resp = await this.doGet('/vcs/diff?mode=staged')
    return this.parseJson<FileDiff[]>(resp)
  }

  // ══════════ Agent ══════════

  async listAgents(): Promise<AgentInfo[]> {
    const resp = await this.doGet('/agent')
    return this.parseJson<AgentInfo[]>(resp)
  }

  // ══════════ File ══════════

  async listFiles(path: string): Promise<Object[]> {
    const resp = await this.doGet(`/file?path=${encodeURIComponent(path)}`)
    return this.parseJson<Object[]>(resp)
  }

  async readFile(filePath: string): Promise<Object> {
    const resp = await this.doGet(`/file/content?path=${encodeURIComponent(filePath)}`)
    return this.parseJson<Object>(resp)
  }

  // ══════════ Instance ══════════

  async getPaths(): Promise<Record<string, string>> {
    const resp = await this.doGet('/path')
    return this.parseJson<Record<string, string>>(resp)
  }

  async disposeInstance(): Promise<boolean> {
    const resp = await this.doPost('/instance/dispose', '{}')
    return resp.responseCode === 200
  }

  // ══════════ SSE Event Stream ══════════

  /**
   * 获取 SSE 事件流 URL（供 EventStreamClient 使用）
   */
  getEventStreamUrl(): string {
    const dirPart = this.directory ? `?directory=${encodeURIComponent(this.directory)}` : ''
    return `${this.baseUrl}/event${dirPart}`
  }

  getAuthHeaders(): Record<string, string> {
    return this.buildHeaders()
  }
}

// ══════════ 辅助类型 ══════════

export class HealthResult {
  ok: boolean = false
  version: string = ''
  error: string = ''
}
