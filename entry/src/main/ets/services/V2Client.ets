import { http } from '@kit.NetworkKit'
import { OpenCodeClient } from './OpenCodeClient'
import {
  SnapshotInfo, SnapshotDiff,
  PtySessionInfo, PtyChunk,
  PluginInfo,
  CompactResult,
  AgentDetail,
  UnsupportedV2Endpoint,
  V2Response
} from './V2Type'

/**
 * V2 API wrapper.
 *
 * 设计目标：
 *  - 在 v1 server 上优雅降级（抛 UnsupportedV2Endpoint），不 crash
 *  - 复用 OpenCodeClient 的 baseUrl / auth / directory
 *  - 不持有内部状态，可以随时 new 一个
 *
 * 用法：
 *   const v2 = new V2Client(client)
 *   try { v2.listSnapshots(sessionID) } catch (e) { if (e instanceof UnsupportedV2Endpoint) ... }
 */
export class V2Client {
  private client: OpenCodeClient
  private streamPollers: Map<string, V2StreamPoller> = new Map()

  constructor(client: OpenCodeClient) {
    this.client = client
  }

  // ══════════ Snapshot API ══════════

  /**
   * GET /snapshot?sessionID=...
   * v1: 返回 [] 或 404
   */
  async listSnapshots(sessionID: string): Promise<SnapshotInfo[]> {
    const path = `/snapshot?sessionID=${encodeURIComponent(sessionID)}`
    const resp = await this.get(path)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(path, resp.status)
    }
    const out: SnapshotInfo[] = []
    if (Array.isArray(resp.data)) {
      for (const raw of resp.data) {
        if (raw === null || raw === undefined) continue
        out.push(this.parseSnapshot(raw))
      }
    }
    return out
  }

  /**
   * POST /snapshot
   * body: { sessionID, messageID?, description? }
   */
  async createSnapshot(sessionID: string, messageID: string = '', description: string = ''): Promise<SnapshotInfo> {
    const body: Record<string, Object> = {}
    body['sessionID'] = sessionID
    if (messageID.length > 0) body['messageID'] = messageID
    if (description.length > 0) body['description'] = description
    const resp = await this.post(`/snapshot`, body)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint('/snapshot', resp.status)
    }
    return this.parseSnapshot(resp.data)
  }

  /**
   * POST /snapshot/:id/restore
   */
  async restoreSnapshot(snapshotID: string): Promise<boolean> {
    const resp = await this.post(`/snapshot/${encodeURIComponent(snapshotID)}/restore`, {})
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/snapshot/${snapshotID}/restore`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  /**
   * GET /snapshot/:id/diff
   */
  async snapshotDiff(snapshotID: string): Promise<SnapshotDiff[]> {
    const path = `/snapshot/${encodeURIComponent(snapshotID)}/diff`
    const resp = await this.get(path)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(path, resp.status)
    }
    const out: SnapshotDiff[] = []
    if (Array.isArray(resp.data)) {
      for (const raw of resp.data) {
        if (raw === null || raw === undefined) continue
        out.push(this.parseSnapshotDiff(raw))
      }
    }
    return out
  }

  // ══════════ PTY API ══════════

  /**
   * GET /pty
   */
  async listPty(): Promise<PtySessionInfo[]> {
    const resp = await this.get(`/pty`)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint('/pty', resp.status)
    }
    const out: PtySessionInfo[] = []
    if (Array.isArray(resp.data)) {
      for (const raw of resp.data) {
        if (raw === null || raw === undefined) continue
        out.push(this.parsePtySession(raw))
      }
    }
    return out
  }

  /**
   * POST /pty
   * body: { command, cwd?, cols?, rows?, title? }
   */
  async startPty(command: string, cwd: string = '', cols: number = 80, rows: number = 24, title: string = ''): Promise<PtySessionInfo> {
    const body: Record<string, Object> = {}
    body['command'] = command
    if (cwd.length > 0) body['cwd'] = cwd
    if (cols > 0) body['cols'] = cols
    if (rows > 0) body['rows'] = rows
    if (title.length > 0) body['title'] = title
    const resp = await this.post(`/pty`, body)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint('/pty', resp.status)
    }
    return this.parsePtySession(resp.data)
  }

  /**
   * POST /pty/:id/input
   * body: { data: "ls\n" }
   */
  async writePtyInput(sessionID: string, data: string): Promise<boolean> {
    const body: Record<string, Object> = {}
    body['data'] = data
    const resp = await this.post(`/pty/${encodeURIComponent(sessionID)}/input`, body)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/pty/${sessionID}/input`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  /**
   * POST /pty/:id/resize
   * body: { cols, rows }
   */
  async resizePty(sessionID: string, cols: number, rows: number): Promise<boolean> {
    const body: Record<string, Object> = {}
    body['cols'] = cols
    body['rows'] = rows
    const resp = await this.post(`/pty/${encodeURIComponent(sessionID)}/resize`, body)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/pty/${sessionID}/resize`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  /**
   * DELETE /pty/:id
   */
  async closePty(sessionID: string): Promise<boolean> {
    const resp = await this.delete(`/pty/${encodeURIComponent(sessionID)}`)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/pty/${sessionID}`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  /**
   * GET /pty/:id/output?since=<seq>
   * v2 server 通过 SSE 或 polling 推送输出。
   * 这里提供 polling 模式：每 pollIntervalMs 拉一次,只返回 seq > since 的 chunk。
   * 启动后会持续 poll,直到 onClose 被调用或 session exit。
   */
  startPtyPoller(sessionID: string, onChunk: (chunk: PtyChunk) => void, onError: (msg: string) => void, pollIntervalMs: number = 1000): V2StreamPoller {
    const poller = new V2StreamPoller(this, sessionID, onChunk, onError, pollIntervalMs)
    this.streamPollers.set(`pty:${sessionID}`, poller)
    poller.start()
    return poller
  }

  stopPtyPoller(sessionID: string): void {
    const key = `pty:${sessionID}`
    const p = this.streamPollers.get(key)
    if (p) {
      p.stop()
      this.streamPollers.delete(key)
    }
  }

  /**
   * 拉取 PTY 输出(单次)。PTY poller 内部使用,也可独立调用。
   * 公开给 V2StreamPoller 复用。
   */
  async pollPtyOutput(sessionID: string, sinceSeq: number): Promise<V2Response> {
    return this.get(`/pty/${encodeURIComponent(sessionID)}/output?since=${sinceSeq}`)
  }

  // ══════════ Plugin API ══════════

  /**
   * GET /plugin
   */
  async listPlugins(): Promise<PluginInfo[]> {
    const resp = await this.get(`/plugin`)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint('/plugin', resp.status)
    }
    const out: PluginInfo[] = []
    if (Array.isArray(resp.data)) {
      for (const raw of resp.data) {
        if (raw === null || raw === undefined) continue
        out.push(this.parsePlugin(raw))
      }
    }
    return out
  }

  /**
   * POST /plugin/:id/enable
   */
  async enablePlugin(pluginID: string): Promise<boolean> {
    const resp = await this.post(`/plugin/${encodeURIComponent(pluginID)}/enable`, {})
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/plugin/${pluginID}/enable`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  /**
   * POST /plugin/:id/disable
   */
  async disablePlugin(pluginID: string): Promise<boolean> {
    const resp = await this.post(`/plugin/${encodeURIComponent(pluginID)}/disable`, {})
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/plugin/${pluginID}/disable`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  // ══════════ Compaction v2 ══════════

  /**
   * POST /session/:id/compact
   * v2 改进: 返回结构化结果。
   */
  async compactSession(sessionID: string): Promise<CompactResult> {
    const resp = await this.post(`/session/${encodeURIComponent(sessionID)}/compact`, {})
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/session/${sessionID}/compact`, resp.status)
    }
    const out = new CompactResult()
    if (resp.status === 200 || resp.status === 204) {
      out.ok = true
      if (typeof resp.data === 'object' && resp.data !== null) {
        const obj: Record<string, Object> = resp.data as Record<string, Object>
        out.compacted = (obj['compacted'] as number) || 0
        out.removedTokens = (obj['removedTokens'] as number) || 0
      }
    } else {
      out.ok = false
      out.error = resp.error
    }
    return out
  }

  // ══════════ Init (v2 引入) ══════════

  /**
   * POST /session/:id/init
   * v1 不支持。v2 用来预热 session(拉取 git/config/providers 等元数据)。
   */
  async initSession(sessionID: string): Promise<boolean> {
    const resp = await this.post(`/session/${encodeURIComponent(sessionID)}/init`, {})
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint(`/session/${sessionID}/init`, resp.status)
    }
    return resp.status === 200 || resp.status === 204
  }

  // ══════════ Agent List (v2 detail) ══════════

  /**
   * GET /agent (v2 返回 AgentDetail[], v1 只返回 name[])
   * 我们已经能从 /config 拿到 agents,但 v2 给更多字段。
   */
  async listAgentsV2(): Promise<AgentDetail[]> {
    const resp = await this.get(`/agent`)
    if (resp.status === 404 || resp.status === 405) {
      throw new UnsupportedV2Endpoint('/agent', resp.status)
    }
    const out: AgentDetail[] = []
    if (Array.isArray(resp.data)) {
      for (const raw of resp.data) {
        if (raw === null || raw === undefined) continue
        out.push(this.parseAgentDetail(raw))
      }
    }
    return out
  }

  // ══════════ Parsers ══════════

  private parseSnapshot(raw: Object): SnapshotInfo {
    const obj: Record<string, Object> = raw as Record<string, Object>
    const s = new SnapshotInfo()
    s.id = (obj['id'] as string) || ''
    s.messageID = (obj['messageID'] as string) || ''
    s.sessionID = (obj['sessionID'] as string) || ''
    const ts = obj['createdAt']
    s.createdAt = typeof ts === 'number' ? ts : 0
    s.description = (obj['description'] as string) || ''
    const fc = obj['fileCount']
    s.fileCount = typeof fc === 'number' ? fc : 0
    const files = obj['files']
    if (Array.isArray(files)) {
      for (const f of files) {
        if (typeof f === 'string') s.files.push(f)
      }
    }
    return s
  }

  private parseSnapshotDiff(raw: Object): SnapshotDiff {
    const obj: Record<string, Object> = raw as Record<string, Object>
    const d = new SnapshotDiff()
    d.file = (obj['file'] as string) || ''
    d.before = (obj['before'] as string) || ''
    d.after = (obj['after'] as string) || ''
    d.additions = (obj['additions'] as number) || 0
    d.deletions = (obj['deletions'] as number) || 0
    return d
  }

  private parsePtySession(raw: Object): PtySessionInfo {
    const obj: Record<string, Object> = raw as Record<string, Object>
    const p = new PtySessionInfo()
    p.id = (obj['id'] as string) || ''
    p.title = (obj['title'] as string) || ''
    p.command = (obj['command'] as string) || ''
    p.cwd = (obj['cwd'] as string) || ''
    p.cols = (obj['cols'] as number) || 80
    p.rows = (obj['rows'] as number) || 24
    p.status = (obj['status'] as string) || 'running'
    p.exitCode = (obj['exitCode'] as number) || 0
    const ts = obj['createdAt']
    p.createdAt = typeof ts === 'number' ? ts : 0
    return p
  }

  private parsePlugin(raw: Object): PluginInfo {
    const obj: Record<string, Object> = raw as Record<string, Object>
    const p = new PluginInfo()
    p.id = (obj['id'] as string) || (obj['name'] as string) || ''
    p.name = (obj['name'] as string) || p.id
    p.version = (obj['version'] as string) || ''
    p.description = (obj['description'] as string) || ''
    p.author = (obj['author'] as string) || ''
    p.enabled = obj['enabled'] === true
    p.path = (obj['path'] as string) || ''
    p.scope = (obj['scope'] as string) || 'user'
    p.error = (obj['error'] as string) || ''
    return p
  }

  private parseAgentDetail(raw: Object): AgentDetail {
    const obj: Record<string, Object> = raw as Record<string, Object>
    const a = new AgentDetail()
    a.name = (obj['name'] as string) || ''
    a.description = (obj['description'] as string) || ''
    a.mode = (obj['mode'] as string) || 'primary'
    a.model = (obj['model'] as string) || ''
    a.prompt = (obj['prompt'] as string) || ''
    a.enabled = obj['enabled'] !== false
    a.builtIn = obj['builtIn'] === true
    const tools = obj['tools']
    if (Array.isArray(tools)) {
      for (const t of tools) {
        if (typeof t === 'string') a.tools.push(t)
      }
    }
    return a
  }

  // ══════════ HTTP helpers (reuse OpenCodeClient primitives) ══════════

  private async get(path: string): Promise<V2Response> {
    try {
      const resp = await this.client.doGet(path)
      return this.toV2Response(resp)
    } catch (e) {
      const out = new V2Response()
      out.ok = false
      out.status = 0
      out.error = String(e)
      return out
    }
  }

  private async post(path: string, body: Record<string, Object>): Promise<V2Response> {
    try {
      const resp = await this.client.doPost(path, JSON.stringify(body))
      return this.toV2Response(resp)
    } catch (e) {
      const out = new V2Response()
      out.ok = false
      out.status = 0
      out.error = String(e)
      return out
    }
  }

  private async delete(path: string): Promise<V2Response> {
    try {
      // OpenCodeClient.doDelete 已在某些版本中存在;若没有,降级到 doFetch。
      const resp = await this.client.doDelete(path)
      return this.toV2Response(resp)
    } catch (e) {
      const out = new V2Response()
      out.ok = false
      out.status = 0
      out.error = String(e)
      return out
    }
  }

  private toV2Response(resp: http.HttpResponse): V2Response {
    const out = new V2Response()
    out.status = resp.responseCode
    out.ok = resp.responseCode >= 200 && resp.responseCode < 300
    if (resp.result !== undefined && resp.result !== null) {
      const text: string = typeof resp.result === 'string' ? resp.result : String(resp.result)
      out.raw = text
      if (text.length > 0) {
        try {
          const parsed: Object = JSON.parse(text)
          out.data = parsed
        } catch (_) {
          out.data = new Object()
        }
      }
    }
    return out
  }
}

/**
 * V2StreamPoller - PTY 输出轮询器
 *
 * v2 server 通常通过 SSE 推 PTY chunk,但部分实现只有 polling。
 * 这里用 polling 实现,每 pollIntervalMs 拉一次。
 *
 * onChunk 收到的是 PtyChunk。
 * onError 收到的是错误字符串(not throwable)。
 */
export class V2StreamPoller {
  private client: V2Client
  private sessionID: string
  private onChunk: (chunk: PtyChunk) => void
  private onError: (msg: string) => void
  private intervalMs: number
  private sinceSeq: number = 0
  private timerId: number = -1
  private running: boolean = false

  constructor(client: V2Client, sessionID: string, onChunk: (chunk: PtyChunk) => void, onError: (msg: string) => void, intervalMs: number = 1000) {
    this.client = client
    this.sessionID = sessionID
    this.onChunk = onChunk
    this.onError = onError
    this.intervalMs = intervalMs
  }

  start(): void {
    if (this.running) return
    this.running = true
    this.timerId = setInterval((): void => {
      this.poll()
    }, this.intervalMs)
  }

  stop(): void {
    this.running = false
    if (this.timerId !== -1) {
      clearInterval(this.timerId)
      this.timerId = -1
    }
  }

  private async poll(): Promise<void> {
    if (!this.running) return
    try {
      const resp = await this.client.pollPtyOutput(this.sessionID, this.sinceSeq)
      if (resp.status === 404 || resp.status === 405) {
        this.onError(`pty output endpoint not supported (HTTP ${resp.status})`)
        this.stop()
        return
      }
      if (!resp.ok) {
        this.onError(`pty poll failed: HTTP ${resp.status}`)
        return
      }
      if (Array.isArray(resp.data)) {
        for (const raw of resp.data) {
          if (raw === null || raw === undefined) continue
          const obj: Record<string, Object> = raw as Record<string, Object>
          const chunk = new PtyChunk()
          chunk.sessionID = this.sessionID
          chunk.seq = (obj['seq'] as number) || 0
          chunk.data = (obj['data'] as string) || ''
          chunk.isExit = obj['exit'] === true
          chunk.exitCode = (obj['exitCode'] as number) || 0
          if (chunk.seq > this.sinceSeq) {
            this.sinceSeq = chunk.seq
          }
          this.onChunk(chunk)
          if (chunk.isExit) {
            this.stop()
            return
          }
        }
      }
    } catch (e) {
      this.onError(`pty poll exception: ${String(e)}`)
    }
  }
}
