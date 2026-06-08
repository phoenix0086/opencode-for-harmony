import { Runner } from '../models/Runner'
import {
  SessionInfo, NormalizedMessage, FileDiff,
  EventTypes, ServerEvent, LogEntry
} from '../models/Event'
import { OpenCodeClient, normalizeFileDiffs } from '../services/OpenCodeClient'
import { EventStreamClient, EventCallback } from '../services/EventStreamClient'
import { storageService } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'
import { AppShell } from '../components/AppShell'
import { TranscriptBlock } from '../components/AgentTranscript'
import { ToolTimelineEntry } from '../components/ToolTimelinePanel'
import { ToastManager } from '../components/ToastNotification'
import { DirectoryPicker, ProjectEntry } from '../components/DirectoryPicker'

/**
 * Index - OpenCode Harmony Native 主入口
 * 负责全局状态管理和 AppShell 三栏 IDE 布局
 */
@Entry
@Component
struct Index {
  // ══════════ Navigation State ══════════
  @State activeActivity: string = 'chat'

  // ══════════ Connection State ══════════
  @State runners: Runner[] = []
  @State activeRunner: Runner | null = null
  @State isConnected: boolean = false
  @State serverVersion: string = ''
  @State serverUrl: string = ''

  // ══════════ Session State ══════════
  @State sessions: SessionInfo[] = []
  @State activeSessionId: string = ''
  @State sessionTitle: string = ''

  // ══════════ Transcript State ══════════
  @State transcriptBlocks: TranscriptBlock[] = []
  @State toolEntries: ToolTimelineEntry[] = []
  @State diffs: FileDiff[] = []
  @State isStreaming: boolean = false
  @State logEntries: LogEntry[] = []
  @State lastAssistantMessageId: string = ''

  // ══════════ Composer State ══════════
  @State inputText: string = ''
  @State isSending: boolean = false

  // ══════════ Project State ══════════
  @State projects: ProjectEntry[] = []

  // ══════════ Info State ══════════
  @State projectName: string = ''
  @State branchName: string = ''
  @State modelName: string = ''
  @State tokenCost: string = '0 tokens'

  // ══════════ Init State ══════════
  @State isInitialized: boolean = false

  // ══════════ Services ══════════
  private eventClient: EventStreamClient | null = null
  private sendTimeoutId: number = -1
  private cachedClient: OpenCodeClient | null = null
  private cachedClientRunnerId: string = ''
  private loadMessagesInFlight: boolean = false
  private loadMessagesPending: boolean = false
  private loadDiffsInFlight: boolean = false

  private getClient(): OpenCodeClient | null {
    if (this.activeRunner === null) return null
    if (this.cachedClient !== null && this.cachedClientRunnerId === this.activeRunner.id) {
      return this.cachedClient
    }
    this.cachedClient = new OpenCodeClient(this.activeRunner)
    this.cachedClientRunnerId = this.activeRunner.id
    return this.cachedClient
  }

  async aboutToAppear(): Promise<void> {
    await this.initData()
  }

  aboutToDisappear(): void {
    if (this.eventClient) {
      this.eventClient.close()
      this.eventClient = null
    }
  }

  async initData(): Promise<void> {
    try {
      await storageService.init(getContext(this))
      this.runners = await storageService.loadRunners()

      const activeId = await storageService.getActiveRunnerId()
      if (activeId.length > 0) {
        for (const r of this.runners) {
          if (r.id === activeId) {
            this.activeRunner = r
            break
          }
        }
      }

      await providerRegistry.init()

      // Test connection if runner exists
      if (this.activeRunner !== null) {
        await this.testConnection()
        await this.loadSessions()
      }
    } catch (e) {
      ToastManager.show(`init error: ${String(e)}`, 'error')
      this.addLog(`init.error: ${String(e)}`, 'error', 'app')
    }
    this.isInitialized = true
  }

  async activateRunnerFromUi(runner: Runner): Promise<void> {
    this.activeRunner = runner
    this.serverUrl = `${runner.protocol}://${runner.host}:${runner.port}`
    this.addLog(`runner.activated ${this.serverUrl}`, 'info', 'server')
    await this.testConnection()
  }

  async testConnection(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      this.addLog(`Connecting to ${this.activeRunner!.host}:${this.activeRunner!.port}...`, 'info', 'server')
      const result = await client.health()
      this.isConnected = result.ok
      this.serverVersion = result.version
      this.serverUrl = `${this.activeRunner!.host}:${this.activeRunner!.port}`
      if (result.ok) {
        this.addLog(`server.connected v${result.version}`, 'info', 'server')
        ToastManager.show(`connected to server v${result.version}`, 'success')
        // Parallel load: project / vcs / config / projects list
        const pProj = client.getCurrentProject().then(
          (project) => {
            this.projectName = project.name
            this.addLog(`project: ${project.name}`, 'info', 'server')
          },
          (e) => { this.addLog(`project load failed: ${String(e)}`, 'warn', 'server') }
        )
        const pVcs = client.getVcsInfo().then(
          (vcs) => {
            this.branchName = vcs.branch
            this.addLog(`branch: ${vcs.branch}`, 'info', 'server')
          },
          (e) => { this.addLog(`vcs load failed: ${String(e)}`, 'warn', 'server') }
        )
        const pConfig = client.getConfig().then(
          (config) => {
            if (config.model.length > 0) {
              this.modelName = config.model
            }
            this.addLog(`config.model: ${config.model}`, 'info', 'server')
          },
          (e) => { this.addLog(`config load failed: ${String(e)}`, 'warn', 'server') }
        )
        const pProjects = this.loadProjects()
        await Promise.all([pProj, pVcs, pConfig, pProjects])
      } else {
        this.addLog(`Health check failed: ${result.error}`, 'error', 'server')
      }
    } catch (e) {
      this.isConnected = false
      this.addLog(`server.error: ${String(e)}`, 'error', 'server')
    }
  }

  async loadSessions(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      this.sessions = await client.listSessions()
    } catch (e) {
      // ignore
    }
  }

  async loadProjects(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const apiProjects = await client.listProjects()
      const entries: ProjectEntry[] = []
      for (const p of apiProjects) {
        const entry = new ProjectEntry()
        entry.id = p.id
        entry.name = p.name
        entry.directory = p.worktree
        entry.isActive = p.name === this.projectName
        entries.push(entry)
      }
      this.projects = entries
      this.addLog(`projects.loaded ${entries.length}`, 'info', 'project')
    } catch (e) {
      this.addLog(`projects.load.failed: ${String(e)}`, 'warn', 'project')
    }
  }

  // ══════════ Session Management ══════════

  async selectSession(sessionId: string): Promise<void> {
    if (this.activeRunner === null) return
    this.activeSessionId = sessionId

    // Find session title + info (model, cost)
    let title = 'untitled'
    for (const s of this.sessions) {
      if (s.id === sessionId) {
        title = s.title.length > 0 ? s.title : 'untitled'
        if (s.model.id.length > 0) {
          this.modelName = `${s.model.providerID}/${s.model.id}`
        }
        if (s.cost > 0) {
          this.tokenCost = `${s.cost.toFixed(4)} USD`
        }
        break
      }
    }
    this.sessionTitle = title

    this.addLog(`session.selected ${this.sessionTitle}`, 'info', 'session')
    const p1 = this.loadMessages()
    const p2 = this.loadDiffs()
    await Promise.all([p1, p2])
    this.connectEventStream()
  }

  async loadMessages(): Promise<void> {
    if (this.activeSessionId.length === 0) return

    if (this.loadMessagesInFlight) {
      this.loadMessagesPending = true
      return
    }

    const client = this.getClient()
    if (client === null) return

    this.loadMessagesInFlight = true
    try {
      const messages = await client.getMessages(this.activeSessionId)
      const blocks: TranscriptBlock[] = []
      const toolMap: Map<string, ToolTimelineEntry> = new Map()
      let lastAssistantId = ''

      for (const msg of messages) {
        if (msg.role === 'assistant') {
          lastAssistantId = msg.id
        }
        const msgBlocks = this.convertMessage(msg)
        for (const b of msgBlocks) {
          blocks.push(b)
          if (b.type === 'tool' && b.toolId.length > 0) {
            const entry = new ToolTimelineEntry()
            entry.id = b.toolId
            entry.toolName = b.toolName
            entry.status = b.toolStatus
            entry.input = b.toolInput
            entry.step = b.toolStep
            toolMap.set(b.toolId, entry)
          }
        }
      }

      this.lastAssistantMessageId = lastAssistantId
      this.transcriptBlocks = blocks
      const toolList: ToolTimelineEntry[] = []
      toolMap.forEach((entry: ToolTimelineEntry) => {
        toolList.push(entry)
      })
      this.toolEntries = toolList
    } catch (e) {
      this.addLog(`loadMessages failed: ${String(e)}`, 'error', 'message')
    } finally {
      this.loadMessagesInFlight = false
      if (this.loadMessagesPending) {
        this.loadMessagesPending = false
        this.loadMessages()
      }
    }
  }

  async refreshAfterToolSuccess(): Promise<void> {
    const p1 = this.loadMessages()
    const p2 = this.loadDiffs()
    await Promise.all([p1, p2])
  }

  async loadDiffs(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    if (this.loadDiffsInFlight) return
    this.loadDiffsInFlight = true
    this.addLog('diff.loading', 'debug', 'diff')
    try {
      if (this.activeSessionId.length > 0 && this.lastAssistantMessageId.length > 0) {
        try {
          const sessionDiffs = await client.getSessionDiff(this.activeSessionId, this.lastAssistantMessageId)
          this.diffs = normalizeFileDiffs(sessionDiffs)
          this.addLog(`diff.loaded ${this.diffs.length} files (session)`, 'info', 'diff')
          return
        } catch (sessionErr) {
          this.addLog('session diff failed, falling back to vcs diff', 'warn', 'diff')
        }
      }

      const rawDiffs = await client.getVcsDiff('git')
      this.diffs = normalizeFileDiffs(rawDiffs)
      this.addLog(`diff.loaded ${this.diffs.length} files (vcs)`, 'info', 'diff')
    } catch (e) {
      this.addLog(`diff.failed: ${String(e)}`, 'error', 'diff')
    } finally {
      this.loadDiffsInFlight = false
    }
  }

  // ══════════ Message Conversion ══════════

  convertMessage(msg: NormalizedMessage): TranscriptBlock[] {
    const blocks: TranscriptBlock[] = []

    if (msg.role === 'user') {
      let textContent = ''
      for (const part of msg.parts) {
        if (part.type === 'text') {
          textContent += part.content
        }
      }
      const block = new TranscriptBlock()
      block.id = msg.id
      block.type = 'user'
      block.role = 'user'
      block.content = textContent.length > 0 ? textContent : '[message]'
      blocks.push(block)
    } else if (msg.role === 'assistant') {
      let textContent = ''
      for (const part of msg.parts) {
        if (part.type === 'text') {
          textContent += part.content
        }
      }

      if (textContent.length > 0) {
        const textBlock = new TranscriptBlock()
        textBlock.id = `${msg.id}_text`
        textBlock.type = 'assistant'
        textBlock.role = 'assistant'
        textBlock.content = textContent
        blocks.push(textBlock)
      }

      for (const part of msg.parts) {
        if (part.type === 'tool-invocation') {
          const toolBlock = new TranscriptBlock()
          toolBlock.id = `tool_${part.id}`
          toolBlock.type = 'tool'
          toolBlock.toolId = part.id
          toolBlock.toolName = part.toolName.length > 0 ? part.toolName : 'unknown'
          toolBlock.toolStatus = part.toolState.length > 0 ? part.toolState : 'result'
          toolBlock.toolInput = part.toolArgs
          toolBlock.toolOutput = part.toolResult
          toolBlock.toolStep = part.step
          blocks.push(toolBlock)
        }
      }
    }

    return blocks
  }

  // ══════════ Event Stream ══════════

  private addLog(msg: string, level: string = 'info', source: string = 'app'): void {
    const now = new Date()
    const hh = String(now.getHours()).padStart(2, '0')
    const mm = String(now.getMinutes()).padStart(2, '0')
    const ss = String(now.getSeconds()).padStart(2, '0')
    const ms = String(now.getMilliseconds()).padStart(3, '0')
    const entry = new LogEntry()
    entry.timestamp = `${hh}:${mm}:${ss}.${ms}`
    entry.level = level
    entry.source = source
    entry.message = msg
    // Reassign to ensure @State re-render triggers; keep last 300 entries
    if (this.logEntries.length >= 300) {
      const trimmed: LogEntry[] = []
      for (let i = this.logEntries.length - 299; i < this.logEntries.length; i++) {
        trimmed.push(this.logEntries[i])
      }
      trimmed.push(entry)
      this.logEntries = trimmed
    } else {
      const list: LogEntry[] = []
      for (let i = 0; i < this.logEntries.length; i++) {
        list.push(this.logEntries[i])
      }
      list.push(entry)
      this.logEntries = list
    }
  }

  clearLogs(): void {
    this.logEntries = []
  }

  connectEventStream(): void {
    const client = this.getClient()
    if (client === null) return

    // Close existing connection
    if (this.eventClient) {
      this.eventClient.close()
    }

    this.eventClient = new EventStreamClient(client, this.activeSessionId)
    this.addLog('poll.started', 'info', 'poll')

    // Listen for new messages
    this.eventClient.on(EventTypes.SESSION_MESSAGE_UPDATED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.addLog(`poll.message.updated ${event.id}`, 'info', 'message')
        this.loadMessages()
      }
    })

    // Listen for LLM streaming
    this.eventClient.on(EventTypes.SESSION_LLM_DELTA, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isStreaming = true
      }
    })

    this.eventClient.on(EventTypes.SESSION_LLM_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.addLog('llm.started', 'info', 'message')
      }
    })

    this.eventClient.on(EventTypes.SESSION_LLM_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isStreaming = false
        this.isSending = false
        this.addLog('llm.ended', 'info', 'message')
      }
    })

    // Listen for tool calls
    this.eventClient.on(EventTypes.SESSION_TOOL_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.detected ${tn}`, 'info', 'tool')
        this.loadMessages()
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_SUCCESS, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.success ${tn}`, 'info', 'tool')
        this.refreshAfterToolSuccess()
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_FAILED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.failed ${tn}`, 'warn', 'tool')
        this.loadMessages()
      }
    })

    // Listen for permission requests
    this.eventClient.on(EventTypes.PERMISSION_ASKED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const permType = (event.properties['permType'] as string) || ''
        this.addLog(`permission.asked ${permType}`, 'warn', 'permission')
        const block = new TranscriptBlock()
        block.id = event.id
        block.type = 'permission'
        block.permType = permType.length > 0 ? permType : 'unknown'
        block.permTitle = (event.properties['title'] as string) || ''
        block.permDescription = (event.properties['description'] as string) || ''
        block.permRiskLevel = (event.properties['riskLevel'] as string) || 'low'
        block.permStatus = 'pending'
        const blocks: TranscriptBlock[] = []
        for (const b of this.transcriptBlocks) {
          blocks.push(b)
        }
        blocks.push(block)
        this.transcriptBlocks = blocks
      }
    })

    // Listen for session run ended
    this.eventClient.on(EventTypes.SESSION_RUN_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        if (this.sendTimeoutId !== -1) {
          clearTimeout(this.sendTimeoutId)
          this.sendTimeoutId = -1
        }
        this.isSending = false
        this.isStreaming = false
        if (this.eventClient) {
          this.eventClient.markIdle()
        }
        this.addLog('session.run.ended', 'info', 'session')
      }
    })

    // Listen for poll warnings
    this.eventClient.on('poll.warning', (event: ServerEvent) => {
      const errMsg = (event.properties['message'] as string) || 'unknown'
      this.addLog(`poll.warning: ${errMsg}`, 'error', 'poll')
    })

    // Listen for errors
    this.eventClient.on('error', (event: ServerEvent) => {
      const errMsg = (event.properties['message'] as string) || 'unknown error'
      this.addLog(`error: ${errMsg}`, 'error', 'server')
    })

    this.eventClient.on('connected', (_event: ServerEvent) => {
      this.addLog('poll.connected', 'info', 'poll')
    })

    this.eventClient.connect()
  }

  // ══════════ Actions ══════════

  async sendMessage(): Promise<void> {
    const text = this.inputText.trim()
    if (text.length === 0) return

    const client = this.getClient()
    if (client === null) {
      ToastManager.show('本地 Runtime 未连接，无法发送消息', 'error')
      this.addLog('message.blocked: runtime not connected', 'warn', 'message')
      return
    }

    if (this.activeSessionId.length === 0) {
      await this.createNewSession()
      if (this.activeSessionId.length === 0) {
        ToastManager.show('创建 session 失败，无法发送消息', 'error')
        this.addLog('message.blocked: no active session after create', 'error', 'message')
        return
      }
    }

    this.inputText = ''
    this.isSending = true

    // Safety timeout: reset streaming state after 5 minutes if no event clears it
    if (this.sendTimeoutId !== -1) {
      clearTimeout(this.sendTimeoutId)
    }
    this.sendTimeoutId = setTimeout((): void => {
      if (this.isSending) {
        this.isSending = false
        this.isStreaming = false
        this.addLog('message.timeout: auto-reset streaming state', 'warn', 'message')
      }
    }, 300000)

    // Add user block to transcript
    const userBlock = new TranscriptBlock()
    userBlock.id = `user_${Date.now()}`
    userBlock.type = 'user'
    userBlock.content = text
    const blocks: TranscriptBlock[] = []
    for (const b of this.transcriptBlocks) {
      blocks.push(b)
    }
    blocks.push(userBlock)
    this.transcriptBlocks = blocks

    try {
      this.addLog(`message.sending length=${text.length}`, 'info', 'message')

      // Ensure event stream is connected before marking active run
      if (!this.eventClient) {
        this.connectEventStream()
      }

      // Mark event stream as active run to catch new messages
      if (this.eventClient) {
        this.eventClient.markActiveRun()
      }

      await client.sendMessageAsync(this.activeSessionId, text)
      this.addLog('message.sent', 'info', 'message')
    } catch (e) {
      this.isSending = false
      this.addLog(`message.failed: ${String(e)}`, 'error', 'message')
      ToastManager.show(`send failed: ${String(e)}`, 'error')
      if (this.eventClient) {
        this.eventClient.markIdle()
      }
      const errBlock = new TranscriptBlock()
      errBlock.id = `err_${Date.now()}`
      errBlock.type = 'system'
      errBlock.content = `Error: ${String(e)}`
      const errBlocks: TranscriptBlock[] = []
      for (const b of this.transcriptBlocks) {
        errBlocks.push(b)
      }
      errBlocks.push(errBlock)
      this.transcriptBlocks = errBlocks
    }
  }

  async createNewSession(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const session = await client.createSession()
      this.addLog(`session.created ${session.id}`, 'info', 'session')
      ToastManager.show('session created', 'success')
      await this.loadSessions()
      await this.selectSession(session.id)
    } catch (e) {
      this.addLog(`session.create.failed: ${String(e)}`, 'error', 'session')
    }
  }

  async approvePermission(permId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      await client.replyPermission(permId, 'once')
      this.addLog(`permission.reply.once ${permId}`, 'info', 'permission')
      this.updatePermissionStatus(permId, 'approved')
    } catch (e) {
      this.addLog(`permission.reply.failed: ${String(e)}`, 'error', 'permission')
    }
  }

  async rejectPermission(permId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      await client.replyPermission(permId, 'deny')
      this.addLog(`permission.reply.deny ${permId}`, 'info', 'permission')
      this.updatePermissionStatus(permId, 'rejected')
    } catch (e) {
      this.addLog(`permission.reply.failed: ${String(e)}`, 'error', 'permission')
    }
  }

  updatePermissionStatus(permId: string, status: string): void {
    const blocks: TranscriptBlock[] = []
    for (const b of this.transcriptBlocks) {
      if (b.id === permId && b.type === 'permission') {
        const updated = new TranscriptBlock()
        updated.id = b.id
        updated.type = b.type
        updated.permType = b.permType
        updated.permTitle = b.permTitle
        updated.permDescription = b.permDescription
        updated.permRiskLevel = b.permRiskLevel
        updated.permStatus = status
        blocks.push(updated)
      } else {
        blocks.push(b)
      }
    }
    this.transcriptBlocks = blocks
  }

  async abortSession(): Promise<void> {
    if (this.activeSessionId.length === 0) return
    const client = this.getClient()
    if (client === null) return
    try {
      await client.abortSession(this.activeSessionId)
      this.isSending = false
      this.isStreaming = false
    } catch (e) {
      // ignore
    }
  }

  // ══════════ Session Actions (M15) ══════════

  async handleSessionAction(sessionId: string, action: string): Promise<void> {
    this.addLog(`session.action.${action} ${sessionId}`, 'info', 'session')
    if (action === 'fork') {
      await this.forkSession(sessionId)
    } else if (action === 'share') {
      await this.shareSession(sessionId)
    } else if (action === 'rename') {
      // Rename handled via session update API
      this.addLog('rename: not yet implemented via UI', 'info', 'session')
    } else if (action === 'delete') {
      await this.deleteSession(sessionId)
    }
  }

  async forkSession(sessionId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      // Fork = create new session, copy context hint
      const session = await client.createSession(`fork-of-${sessionId.substring(0, 8)}`)
      this.addLog(`session.forked ${session.id} from ${sessionId}`, 'info', 'session')
      ToastManager.show('session forked', 'success')
      await this.loadSessions()
      await this.selectSession(session.id)
    } catch (e) {
      this.addLog(`session.fork.failed: ${String(e)}`, 'error', 'session')
    }
  }

  async shareSession(sessionId: string): Promise<void> {
    this.addLog(`session.share ${sessionId} — share link generation not yet available`, 'warn', 'session')
    // In a full implementation, this would call a share API and copy to clipboard
  }

  async deleteSession(sessionId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      await client.deleteSession(sessionId)
      this.addLog(`session.deleted ${sessionId}`, 'info', 'session')
      ToastManager.show('session deleted', 'success')
      await this.loadSessions()
      // If we deleted the active session, select the first remaining one
      if (this.activeSessionId === sessionId) {
        this.activeSessionId = ''
        this.transcriptBlocks = []
        if (this.sessions.length > 0) {
          await this.selectSession(this.sessions[0].id)
        }
      }
    } catch (e) {
      this.addLog(`session.delete.failed: ${String(e)}`, 'error', 'session')
    }
  }

  closeSessionTab(sessionId: string): void {
    if (this.activeSessionId === sessionId) {
      // Select next available session
      const idx = this.sessions.findIndex((s: SessionInfo) => s.id === sessionId)
      if (idx >= 0 && this.sessions.length > 1) {
        const nextIdx = idx > 0 ? idx - 1 : idx + 1
        if (nextIdx < this.sessions.length) {
          this.selectSession(this.sessions[nextIdx].id)
        }
      } else {
        this.activeSessionId = ''
        this.transcriptBlocks = []
      }
    }
  }

  async retryLastMessage(): Promise<void> {
    // Find the last user message and resend it
    const lastUserContent = this.findLastUserMessage()
    if (lastUserContent.length > 0) {
      this.inputText = lastUserContent
      this.sendMessage()
    }
  }

  private findLastUserMessage(): string {
    let lastContent = ''
    for (const block of this.transcriptBlocks) {
      if (block.type === 'user' && block.content.length > 0) {
        lastContent = block.content
      }
    }
    return lastContent
  }

  async alwaysApprovePermission(permId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      await client.replyPermission(permId, 'always')
      this.addLog(`permission.reply.always ${permId}`, 'info', 'permission')
      this.updatePermissionStatus(permId, 'always_approved')
    } catch (e) {
      this.addLog(`permission.reply.failed: ${String(e)}`, 'error', 'permission')
    }
  }

  // ══════════ Build ══════════

  build() {
    if (!this.isInitialized) {
      // Loading screen
      Column() {
        Text('OC')
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#89b4fa')
          .fontFamily('monospace')
        Text('OpenCode Harmony Native')
          .fontSize(14)
          .fontColor('#6c7086')
          .fontFamily('monospace')
          .margin({ top: 12 })
        LoadingProgress()
          .width(24)
          .height(24)
          .color('#89b4fa')
          .margin({ top: 16 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#1e1e2e')
    } else {
      AppShell({
        // Navigation
        activeActivity: $activeActivity,
        activeSessionId: $activeSessionId,
        inputText: $inputText,
        isSending: $isSending,

        // Connection
        activeRunner: this.activeRunner,
        isConnected: this.isConnected,
        connectionStatus: this.isConnected ? 'connected' : 'disconnected',
        serverUrl: this.serverUrl,
        serverVersion: this.serverVersion,

        // Session
        sessions: this.sessions,
        sessionTitle: this.sessionTitle,

        // Content
        transcriptBlocks: this.transcriptBlocks,
        toolEntries: this.toolEntries,
        diffs: this.diffs,
        isStreaming: this.isStreaming,
        logEntries: this.logEntries,

        // Info
        projectName: this.projectName,
        branchName: this.branchName,
        modelName: this.modelName,
        tokenCost: this.tokenCost,

        // Projects (for DirectoryPicker)
        projects: this.projects,

        // Callbacks
        onSelectSession: (id: string) => {
          this.selectSession(id)
        },
        onNewSession: () => {
          this.createNewSession()
        },
        onSend: () => {
          this.sendMessage()
        },
        onAbort: () => {
          this.abortSession()
        },
        onApprovePermission: (id: string) => {
          this.approvePermission(id)
        },
        onRejectPermission: (id: string) => {
          this.rejectPermission(id)
        },
        onAlwaysApprovePermission: (id: string) => {
          this.alwaysApprovePermission(id)
        },
        onSessionAction: (sessionId: string, action: string) => {
          this.handleSessionAction(sessionId, action)
        },
        onCloseTab: (id: string) => {
          this.closeSessionTab(id)
        },
        onNewTab: () => {
          this.createNewSession()
        },
        onReconnect: () => {
          if (this.eventClient) {
            this.eventClient.reconnect()
            this.addLog('poll.reconnect', 'info', 'poll')
            ToastManager.show('reconnecting...', 'info')
          }
          this.testConnection()
        },
        onRunnerActivated: (runner: Runner) => {
          this.activateRunnerFromUi(runner)
        }
      })
    }
  }
}
