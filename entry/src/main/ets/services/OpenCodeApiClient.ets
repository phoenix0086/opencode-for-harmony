import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import {
  FullRunner, runnerBaseUrl, FullHealth, FullSession, FullMessage,
  FullFileItem, FullFileContent, FullDiff, FullPermission
} from '../models/FullAppModels'
import { errStr } from '../utils/ErrorUtil'

export class OpenCodeApiClient {
  private baseUrl: string = ''
  private username: string = 'opencode'
  private password: string = ''
  private directory: string = ''
  private defaultAgent: string = 'build'

  constructor(runner: FullRunner) {
    this.baseUrl = runnerBaseUrl(runner)
    this.password = runner.token
  }

  setDirectory(dir: string): void {
    this.directory = dir
  }

  setDefaultAgent(agent: string): void {
    this.defaultAgent = agent
  }

  private buildAuthHeader(): string {
    if (this.password.length === 0) return ''
    const encoder = new util.TextEncoder()
    const data = encoder.encodeInto(`${this.username}:${this.password}`)
    const base64Helper = new util.Base64Helper()
    return `Basic ${base64Helper.encodeToStringSync(data)}`
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = {}
    h['Content-Type'] = 'application/json'
    const auth = this.buildAuthHeader()
    if (auth.length > 0) h['Authorization'] = auth
    if (this.directory.length > 0) h['x-opencode-directory'] = this.directory
    return h
  }

  private appendDir(url: string): string {
    if (this.directory.length === 0) return url
    const sep = url.includes('?') ? '&' : '?'
    return `${url}${sep}directory=${encodeURIComponent(this.directory)}`
  }

  private async request(path: string, method: http.RequestMethod, body?: string, extraHeaders?: Record<string, string>): Promise<http.HttpResponse> {
    const req = http.createHttp()
    try {
      const hdrs = this.headers()
      if (extraHeaders) {
        for (const k of Object.keys(extraHeaders)) hdrs[k] = extraHeaders[k]
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: hdrs,
        connectTimeout: 10000,
        readTimeout: 60000,
      }
      if (body !== undefined) options.extraData = body
      const resp = await req.request(this.appendDir(`${this.baseUrl}${path}`), options)
      return resp
    } finally {
      req.destroy()
    }
  }

  private async get(path: string): Promise<http.HttpResponse> {
    return this.request(path, http.RequestMethod.GET)
  }

  private async post(path: string, body?: string): Promise<http.HttpResponse> {
    return this.request(path, http.RequestMethod.POST, body)
  }

  private async put(path: string, body?: string): Promise<http.HttpResponse> {
    return this.request(path, http.RequestMethod.PUT, body)
  }

  private async del(path: string): Promise<http.HttpResponse> {
    return this.request(path, http.RequestMethod.DELETE)
  }

  private async patch(path: string, body?: string): Promise<http.HttpResponse> {
    return this.request(path, http.RequestMethod.POST, body, { 'X-HTTP-Method-Override': 'PATCH' })
  }

  private parse<T>(resp: http.HttpResponse): T {
    return JSON.parse(resp.result as string) as T
  }

  private check(resp: http.HttpResponse): void {
    if (resp.responseCode >= 400) {
      let msg = `HTTP ${resp.responseCode}`
      try {
        const body = JSON.parse(resp.result as string) as Record<string, string>
        if (body['error']) msg = body['error']
        if (body['message']) msg = body['message']
      } catch (e) {}
      throw new Error(msg)
    }
  }

  async health(): Promise<FullHealth> {
    const r = new FullHealth()
    try {
      const resp = await this.get('/global/health')
      if (resp.responseCode !== 200) {
        r.ok = false
        r.error = `HTTP ${resp.responseCode}`
        return r
      }
      const raw = this.parse<Record<string, Object>>(resp)
      r.ok = raw['healthy'] as boolean
      r.version = (raw['version'] as string) || ''
      return r
    } catch (e) {
      r.ok = false
      r.error = errStr(e)
      return r
    }
  }

  async getConfig(): Promise<Record<string, Object>> {
    const resp = await this.get('/config')
    this.check(resp)
    return this.parse<Record<string, Object>>(resp)
  }

  async patchConfig(config: Record<string, Object>): Promise<Record<string, Object>> {
    const resp = await this.patch('/config', JSON.stringify(config))
    this.check(resp)
    return this.parse<Record<string, Object>>(resp)
  }

  async listProviders(): Promise<Record<string, Object>> {
    const resp = await this.get('/provider')
    this.check(resp)
    return this.parse<Record<string, Object>>(resp)
  }

  async setAuth(providerId: string, key: string): Promise<boolean> {
    const body: Record<string, string> = {}
    body['type'] = 'api'
    body['key'] = key
    const resp = await this.put(`/auth/${providerId}`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  async removeAuth(providerId: string): Promise<boolean> {
    const resp = await this.del(`/auth/${providerId}`)
    return resp.responseCode === 200
  }

  async getProject(): Promise<Record<string, Object>> {
    const resp = await this.get('/project/current')
    this.check(resp)
    return this.parse<Record<string, Object>>(resp)
  }

  async getPath(): Promise<Record<string, Object>> {
    const resp = await this.get('/path')
    this.check(resp)
    return this.parse<Record<string, Object>>(resp)
  }

  async listFiles(path: string): Promise<FullFileItem[]> {
    const resp = await this.get(`/file?path=${encodeURIComponent(path)}`)
    this.check(resp)
    return this.parse<FullFileItem[]>(resp)
  }

  async readFile(path: string): Promise<FullFileContent> {
    const resp = await this.get(`/file/content?path=${encodeURIComponent(path)}`)
    this.check(resp)
    return this.parse<FullFileContent>(resp)
  }

  async getVcs(): Promise<Record<string, string>> {
    const resp = await this.get('/vcs')
    this.check(resp)
    return this.parse<Record<string, string>>(resp)
  }

  async getVcsStatus(): Promise<Record<string, Object>[]> {
    const resp = await this.get('/vcs/status')
    this.check(resp)
    return this.parse<Record<string, Object>[]>(resp)
  }

  async getVcsDiff(mode: string = 'git'): Promise<FullDiff[]> {
    const resp = await this.get(`/vcs/diff?mode=${mode}`)
    this.check(resp)
    return this.parse<FullDiff[]>(resp)
  }

  async listSessions(limit: number = 0): Promise<FullSession[]> {
    const path = limit > 0 ? `/session?limit=${limit}` : '/session'
    const resp = await this.get(path)
    this.check(resp)
    return this.parse<FullSession[]>(resp)
  }

  async createSession(title: string = ''): Promise<FullSession> {
    const body: Record<string, string> = {}
    if (title.length > 0) body['title'] = title
    const resp = await this.post('/session', JSON.stringify(body))
    this.check(resp)
    return this.parse<FullSession>(resp)
  }

  async deleteSession(sessionId: string): Promise<boolean> {
    const resp = await this.del(`/session/${sessionId}`)
    return resp.responseCode === 200
  }

  async abortSession(sessionId: string): Promise<boolean> {
    const resp = await this.post(`/session/${sessionId}/abort`)
    return resp.responseCode === 200
  }

  async listMessagesRaw(sessionId: string): Promise<Record<string, Object>[]> {
    const resp = await this.get(`/session/${sessionId}/message`)
    if (resp.responseCode !== 200) return []
    return this.parse<Record<string, Object>[]>(resp)
  }

  async sendPromptAsync(sessionId: string, text: string): Promise<boolean> {
    const part: Record<string, string> = {}
    part['type'] = 'text'
    part['text'] = text
    const body: Record<string, Object> = {}
    body['agent'] = this.defaultAgent
    body['parts'] = [part]
    const resp = await this.post(`/session/${sessionId}/prompt_async`, JSON.stringify(body))
    return resp.responseCode === 204 || resp.responseCode === 200
  }

  async listPermissions(): Promise<FullPermission[]> {
    const resp = await this.get('/permission')
    this.check(resp)
    return this.parse<FullPermission[]>(resp)
  }

  async replyPermission(id: string, reply: string): Promise<boolean> {
    const body: Record<string, string> = {}
    body['reply'] = reply
    const resp = await this.post(`/permission/${id}/reply`, JSON.stringify(body))
    return resp.responseCode === 200
  }

  async listAgents(): Promise<Record<string, Object>[]> {
    const resp = await this.get('/agent')
    this.check(resp)
    return this.parse<Record<string, Object>[]>(resp)
  }

  async getSessionDiff(sessionId: string, messageId: string): Promise<FullDiff[]> {
    const resp = await this.get(`/session/${sessionId}/diff?messageID=${encodeURIComponent(messageId)}`)
    if (resp.responseCode !== 200) return []
    return this.parse<FullDiff[]>(resp)
  }

  eventUrl(): string {
    return this.appendDir(`${this.baseUrl}/event`)
  }
}
