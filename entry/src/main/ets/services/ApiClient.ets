import { http } from '@kit.NetworkKit'
import { Runner, runnerBaseUrl } from '../models/Runner'

/** HTTP 请求头 */
class RequestHeader {
  contentType: string = 'application/json'
  authorization: string = ''
}

export class ApiClient {
  private runner: Runner
  private baseUrl: string

  constructor(runner: Runner) {
    this.runner = runner
    this.baseUrl = runnerBaseUrl(runner)
  }

  private buildHeader(): RequestHeader {
    const h = new RequestHeader()
    if (this.runner.token) {
      h.authorization = `Bearer ${this.runner.token}`
    }
    return h
  }

  private httpRequest(url: string, method: http.RequestMethod, body?: string): Promise<http.HttpResponse> {
    const req = http.createHttp()
    const header = this.buildHeader()
    return req.request(url, {
      method: method,
      header: {
        'Content-Type': header.contentType,
        'Authorization': header.authorization,
      },
      extraData: body,
      connectTimeout: 10000,
      readTimeout: 30000,
    }).finally(() => req.destroy())
  }

  async health(): Promise<HealthResult> {
    try {
      const resp = await this.httpRequest(`${this.baseUrl}/health`, http.RequestMethod.GET)
      if (resp.responseCode !== 200) {
        const r = new HealthResult()
        r.ok = false
        r.error = `HTTP ${resp.responseCode}`
        return r
      }
      const data = JSON.parse(resp.result as string) as HealthResponse
      const r = new HealthResult()
      r.ok = true
      r.version = data.version
      return r
    } catch (e) {
      const r = new HealthResult()
      r.ok = false
      r.error = String(e)
      return r
    }
  }

  async getProjects(): Promise<ProjectItem[]> {
    const resp = await this.httpRequest(`${this.baseUrl}/projects`, http.RequestMethod.GET)
    const arr = JSON.parse(resp.result as string) as ProjectItem[]
    return arr
  }

  async getSessions(projectId?: string): Promise<SessionItem[]> {
    const path = projectId ? `/sessions?projectId=${projectId}` : '/sessions'
    const resp = await this.httpRequest(`${this.baseUrl}${path}`, http.RequestMethod.GET)
    return JSON.parse(resp.result as string) as SessionItem[]
  }

  async createSession(projectId: string, title: string, agent: string, model: string, initialMessage?: string): Promise<SessionItem> {
    const body = new CreateSessionBody()
    body.projectId = projectId
    body.title = title
    body.agent = agent
    body.model = model
    body.initialMessage = initialMessage || ''
    const resp = await this.httpRequest(`${this.baseUrl}/sessions`, http.RequestMethod.POST, JSON.stringify(body))
    return JSON.parse(resp.result as string) as SessionItem
  }

  async sendMessage(sessionId: string, content: string): Promise<MessageItem> {
    const body = new SendMessageBody()
    body.content = content
    const resp = await this.httpRequest(`${this.baseUrl}/sessions/${sessionId}/messages`, http.RequestMethod.POST, JSON.stringify(body))
    return JSON.parse(resp.result as string) as MessageItem
  }

  async getMessages(sessionId: string): Promise<MessageItem[]> {
    const resp = await this.httpRequest(`${this.baseUrl}/sessions/${sessionId}/messages`, http.RequestMethod.GET)
    return JSON.parse(resp.result as string) as MessageItem[]
  }

  async approveAction(approvalId: string): Promise<void> {
    await this.httpRequest(`${this.baseUrl}/approvals/${approvalId}/approve`, http.RequestMethod.POST, '{}')
  }

  async rejectAction(approvalId: string): Promise<void> {
    await this.httpRequest(`${this.baseUrl}/approvals/${approvalId}/reject`, http.RequestMethod.POST, '{}')
  }

  async getDiffSummary(sessionId: string): Promise<DiffSummary> {
    const resp = await this.httpRequest(`${this.baseUrl}/sessions/${sessionId}/diff`, http.RequestMethod.GET)
    return JSON.parse(resp.result as string) as DiffSummary
  }
}

// ── 请求体类 ──

class CreateSessionBody {
  projectId: string = ''
  title: string = ''
  agent: string = ''
  model: string = ''
  initialMessage: string = ''
}

class SendMessageBody {
  content: string = ''
  mode: string = 'normal'
}

// ── 响应类型 ──

class HealthResponse {
  version: string = ''
}

export class HealthResult {
  ok: boolean = false
  version: string = ''
  error: string = ''
}

export class ProjectItem {
  id: string = ''
  name: string = ''
  path: string = ''
  branch: string = ''
  status: string = ''
  pendingApprovals: number = 0
  runningSessions: number = 0
  updatedAt: number = 0
}

export class SessionItem {
  id: string = ''
  projectId: string = ''
  title: string = ''
  agent: string = ''
  model: string = ''
  status: string = ''
  lastMessage: string = ''
  createdAt: number = 0
  updatedAt: number = 0
}

export class MessageItem {
  id: string = ''
  sessionId: string = ''
  role: string = ''
  content: string = ''
  createdAt: number = 0
}

export class DiffSummary {
  sessionId: string = ''
  filesChanged: number = 0
  insertions: number = 0
  deletions: number = 0
  files: DiffFileItem[] = []
}

export class DiffFileItem {
  id: string = ''
  path: string = ''
  status: string = ''
  insertions: number = 0
  deletions: number = 0
}
