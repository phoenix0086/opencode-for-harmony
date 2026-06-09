import { Runner } from '../models/Runner'
import {
  SessionInfo, NormalizedMessage, FileDiff,
  EventTypes, ServerEvent, LogEntry
} from '../models/Event'
import { OpenCodeClient, normalizeFileDiffs } from '../services/OpenCodeClient'
import { EventStreamClient, EventCallback } from '../services/EventStreamClient'
import { storageService } from '../services/StorageService'
import { modelSelectionService } from '../services/ModelSelectionService'
import { agentResponsePoller } from '../services/AgentResponsePoller'
import { parseSlashCommand, buildHelpText, SlashCommand } from '../services/SlashCommandService'
import { providerRegistry } from '../services/ProviderRegistry'
import { AppShell } from '../components/AppShell'
import { TranscriptBlock } from '../components/AgentTranscript'
import { ToolTimelineEntry } from '../components/ToolTimelinePanel'
import { ToastManager } from '../components/ToastNotification'
import { DirectoryPicker, ProjectEntry } from '../components/DirectoryPicker'
import { MCPServer } from '../components/MCPPanel'
import { LspServer } from '../components/LSPPanel'
import { FormatterEntry } from '../components/FormatterPanel'
import { formatLocalSessionTitle, formatServerTitle } from '../utils/DateTimeUtil'

/**
 * Index - OpenCode Harmony Native 主入口
 * 负责全局状态管理和 AppShell 三栏 IDE 布局
 */
@Entry
@Component
struct Index {
  // ══════════ Navigation State ══════════
  @State activeActivity: string = 'chat'
  // M14: parent-controlled right-panel tab. Auto-switched by sendMessage()
  // based on what the runtime actually did: tools / diff / logs / permission.
  @State rightPanelTab: string = 'tools'
  @State showRightPanel: boolean = true

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
  @State agentMode: string = 'build'
  @State mcpServers: MCPServer[] = []
  @State lspServers: LspServer[] = []
  @State formatterList: FormatterEntry[] = []
  @State isSending: boolean = false

  // ══════════ Project State ══════════
  @State projects: ProjectEntry[] = []

  // ══════════ Info State ══════════
  @State projectName: string = ''
  @State branchName: string = ''
  @State modelName: string = ''
  @State tokenCost: string = '0 tokens'
  @State tokensUsed: number = 0
  @State tokensMax: number = 128000

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
        // Sprint 2: pre-warm MCP/LSP/Formatter panels
        if (this.isConnected) {
          await Promise.all([
            this.loadMcpServers(),
            this.loadLspServers(),
            this.loadFormatters()
          ])
        }
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
            // /project/current returns {id, worktree, vcs, sandboxes} — no `name`.
            // Use worktree path as the workspace label; fall back to a trimmed path tail.
            const raw = (project.worktree && project.worktree.length > 0) ? project.worktree : ''
            const trimmed = raw.split('/').filter((s: string) => s.length > 0).pop() || 'workspace'
            this.projectName = trimmed
            this.addLog(`project: ${trimmed}`, 'info', 'server')
          },
          (e: Object) => { this.addLog(`project load failed: ${String(e)}`, 'warn', 'server') }
        )
        const pVcs = client.getVcsInfo().then(
          (vcs) => {
            this.branchName = vcs.branch
            this.addLog(`branch: ${vcs.branch}`, 'info', 'server')
          },
          (e: Object) => { this.addLog(`vcs load failed: ${String(e)}`, 'warn', 'server') }
        )
        const pConfig = client.getConfig().then(
          (config) => {
            if (config.model.length > 0) {
              this.modelName = config.model
            }
            this.addLog(`config.model: ${config.model}`, 'info', 'server')
          },
          (e: Object) => { this.addLog(`config load failed: ${String(e)}`, 'warn', 'server') }
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
        title = s.title.length > 0 ? formatServerTitle(s.title) : 'untitled'
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
      const data = await client.getMessagesWithRaw(this.activeSessionId)
      const messages = data.normalized
      const blocks: TranscriptBlock[] = []
      const toolMap: Map<string, ToolTimelineEntry> = new Map()
      let lastAssistantId = ''
      let totalTokens = 0

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

      // Sprint 2-C.19: sum tokens from the last assistant info.
      // We read raw (info.tokens) so the user sees real context usage.
      if (data.raw.length > 0) {
        for (let i = data.raw.length - 1; i >= 0; i--) {
          const info = data.raw[i].info
          if (info && info.role === 'assistant' && info.tokens) {
            const t = info.tokens
            totalTokens = (t.input || 0) + (t.output || 0) + (t.reasoning || 0)
            break
          }
        }
      }
      this.tokensUsed = totalTokens

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

  // ─────────────── Sprint 2-A.5/A.6/A.7: extension panel loaders ───────────────

  /**
   * Pull MCP server list, normalizing raw Record<string, Object> shape into
   * MCPServer instances for the panel.
   */
  async loadMcpServers(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const raw = await client.listMcpServers()
      const list: MCPServer[] = []
      for (const r of raw) {
        const s = new MCPServer()
        s.id = (r['name'] as string) || (r['id'] as string) || ''
        s.name = s.id
        const statusVal = r['status']
        s.status = typeof statusVal === 'string' ? statusVal : 'disconnected'
        const errVal = r['error']
        if (typeof errVal === 'string') s.errorMessage = errVal
        list.push(s)
      }
      this.mcpServers = list
    } catch (e) {
      this.addLog(`mcp.load.failed: ${String(e)}`, 'warn', 'mcp')
    }
  }

  async loadLspServers(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const raw = await client.listLspStatus()
      const list: LspServer[] = []
      for (const r of raw) {
        const s = new LspServer()
        s.id = (r['name'] as string) || (r['id'] as string) || ''
        s.name = s.id
        s.root = (r['root'] as string) || ''
        const statusVal = r['status']
        s.status = typeof statusVal === 'string' ? statusVal : 'disconnected'
        const errVal = r['error']
        if (typeof errVal === 'string') s.errorMessage = errVal
        list.push(s)
      }
      this.lspServers = list
    } catch (e) {
      this.addLog(`lsp.load.failed: ${String(e)}`, 'warn', 'lsp')
    }
  }

  async loadFormatters(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const raw = await client.listFormatters()
      const list: FormatterEntry[] = []
      for (const r of raw) {
        const f = new FormatterEntry()
        f.name = (r['name'] as string) || (r['id'] as string) || ''
        f.command = (r['command'] as string) || ''
        const enabledVal = r['enabled']
        f.enabled = enabledVal === undefined ? true : (enabledVal === true)
        const extsVal = r['extensions']
        if (Array.isArray(extsVal)) {
          for (const e of extsVal) {
            if (typeof e === 'string') f.extensions.push(e)
          }
        }
        list.push(f)
      }
      this.formatterList = list
    } catch (e) {
      this.addLog(`formatter.load.failed: ${String(e)}`, 'warn', 'formatter')
    }
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
        if (part.type === 'error') {
          const err = new TranscriptBlock()
          err.id = `${msg.id}_error_${blocks.length}`
          err.type = 'error'
          err.role = msg.role
          err.content = part.content && part.content.length > 0 ? part.content : 'Runtime returned an error.'
          blocks.push(err)
          this.addLog(`message.error ${err.content}`, 'error', 'message')
          continue
        }

        if (part.type === 'permission' || part.type === 'permission-request') {
          const perm = new TranscriptBlock()
          perm.id = `${msg.id}_permission_${blocks.length}`
          perm.type = 'permission'
          perm.role = msg.role
          perm.content = part.content && part.content.length > 0 ? part.content : 'Runtime is requesting permission.'
          perm.permTitle = part.toolName.length > 0 ? part.toolName : 'Permission'
          perm.permDescription = part.toolArgs
          perm.permStatus = 'pending'
          blocks.push(perm)
          continue
        }

        if (part.type === 'tool' || part.type === 'tool-call' || part.type === 'tool-result' || part.type === 'tool-invocation') {
          const toolBlock = new TranscriptBlock()
          toolBlock.id = `tool_${part.id.length > 0 ? part.id : msg.id + '_' + blocks.length}`
          toolBlock.type = 'tool'
          toolBlock.toolId = part.id
          toolBlock.toolName = part.toolName.length > 0 ? part.toolName : 'unknown'
          toolBlock.toolStatus = part.toolState.length > 0 ? part.toolState : 'result'
          toolBlock.toolInput = part.toolArgs
          toolBlock.toolOutput = part.toolResult
          toolBlock.toolStep = part.step
          blocks.push(toolBlock)
        }

        if (part.type === 'todo') {
          const todoBlock = new TranscriptBlock()
          todoBlock.id = `todo_${msg.id}_${blocks.length}`
          todoBlock.type = 'todo'
          todoBlock.role = msg.role
          todoBlock.content = ''
          todoBlock.todos = part.todos
          blocks.push(todoBlock)
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

    // Listen for question requests
    this.eventClient.on('question.asked', (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const requestID = (event.properties['requestID'] as string) || event.id
        const optionsRaw = (event.properties['options'] as Array<Record<string, string>>) || []
        const optIDs: string[] = []
        for (const o of optionsRaw) {
          if (o['id'] && o['id'].length > 0) {
            optIDs.push(o['id'])
          }
        }
        this.addLog(`question.asked ${requestID}`, 'info', 'question')

        const block = new TranscriptBlock()
        block.id = `q_${requestID}`
        block.type = 'question'
        block.permStatus = 'pending'
        block.permTitle = (event.properties['header'] as string) || 'Question'
        block.permDescription = (event.properties['question'] as string) || ''
        block.permType = 'question'
        block.permRiskLevel = (event.properties['multiSelect'] === true || event.properties['multiSelect'] === 'true') ? 'high' : 'low'
        // Stash requestID + options in toolInput (reuses stringly-typed field for portability)
        block.toolInput = JSON.stringify({
          requestID: requestID,
          multiSelect: event.properties['multiSelect'] === true,
          options: optionsRaw
        })

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

      if (this.activeSessionId.length === 0) {
        const session = await client.createSession(formatLocalSessionTitle(text))
        this.activeSessionId = session.id
        this.sessionTitle = session.title.length > 0 ? formatServerTitle(session.title) : 'New session'
        await this.loadSessions()
        this.addLog(`session.created ${session.id}`, 'info', 'session')
      }

      const settings = await storageService.loadSettings()
      let modelRef = settings.defaultModel
      if (modelRef.length === 0 && this.modelName.length > 0) {
        modelRef = this.modelName
      }

      if (modelRef.length > 0) {
        const resolvedModel = await modelSelectionService.resolveServerModelRef(modelRef, this.activeRunner)
        const patch: Record<string, Object> = {}
        patch['model'] = resolvedModel
        await client.updateConfig(patch)
        this.modelName = resolvedModel
        this.addLog(`model.active ${resolvedModel}`, 'info', 'model')
      } else {
        this.addLog('model.empty: no default model configured', 'warn', 'model')
      }

      const before = await client.getMessagesRaw(this.activeSessionId)
      const beforeCount = before.length
      this.addLog(`message.beforeCount=${beforeCount}`, 'debug', 'message')

      const sent = await client.sendMessageAsync(this.activeSessionId, text)
      this.addLog(`prompt_async.sent=${sent} beforeCount=${beforeCount}`, 'info', 'message')

      if (this.eventClient) {
        this.eventClient.markActiveRun()
      }

      await this.loadMessages()

      const poll = await agentResponsePoller.waitForExecution(
        client,
        this.activeSessionId,
        beforeCount,
        120,
        1000
      )

      await this.loadMessages()
      await this.loadDiffs()
      await this.loadSessions()

      this.addLog(
        `poll.result ok=${poll.ok} assistant=${poll.hasAssistant} tool=${poll.hasTool} permission=${poll.hasPermission} error=${poll.hasError} count=${poll.messageCount}`,
        poll.ok ? 'info' : (poll.timedOut ? 'warn' : 'error'),
        'message'
      )

      // M14: auto-focus the right panel on the artifact the user needs to see.
      // - tool ran      → tools tab + diff tab (if diffs are present)
      // - permission    → tools tab (permission card lives in chat, but logs
      //                   are also useful); keep panel visible
      // - error         → logs tab (full diagnostic chain)
      // - assistant text → tools tab (if there are tool entries) or diff tab
      if (poll.ok) {
        if (poll.hasError) {
          this.rightPanelTab = 'logs'
          this.showRightPanel = true
        } else if (poll.hasPermission) {
          this.rightPanelTab = 'logs'
          this.showRightPanel = true
        } else if (poll.hasTool) {
          this.rightPanelTab = this.diffs.length > 0 ? 'diff' : 'tools'
          this.showRightPanel = true
        } else if (poll.hasAssistant) {
          this.rightPanelTab = this.diffs.length > 0 ? 'diff' : 'tools'
        }
      } else if (poll.hasError || poll.timedOut) {
        // failures should land the user in the diagnostic log
        this.rightPanelTab = 'logs'
        this.showRightPanel = true
      }

      if (!poll.ok) {
        ToastManager.show(poll.message, poll.timedOut ? 'warning' : 'error')
      } else if (poll.hasError && poll.snapshot.errorText.length > 0) {
        const errBlock = new TranscriptBlock()
        errBlock.id = `err_${Date.now()}`
        errBlock.type = 'error'
        errBlock.content = poll.snapshot.errorText
        const errList: TranscriptBlock[] = []
        for (const b of this.transcriptBlocks) {
          errList.push(b)
        }
        errList.push(errBlock)
        this.transcriptBlocks = errList
      }
    } catch (e) {
      const msg = `send.failed: ${String(e)}`
      this.addLog(msg, 'error', 'message')
      ToastManager.show(msg, 'error')
    } finally {
      this.isSending = false
      this.isStreaming = false
    }
  }

  async createNewSession(): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      // Pass a local-time title so the sidebar shows Beijing time instead of
      // the server's auto-generated "New session - 2026-06-09T02:30:58.985Z"
      // (which is UTC and confused the user).
      const localTitle = formatLocalSessionTitle('新会话')
      const session = await client.createSession(localTitle)
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
      // M14: prefer the session-scoped endpoint; OpenCodeClient falls back
      // to the global /permission/:id/reply if the server doesn't implement
      // the session route.
      await client.replySessionPermission(this.activeSessionId, permId, 'once')
      this.addLog(`permission.reply.once ${permId}`, 'info', 'permission')
      this.updatePermissionStatus(permId, 'approved')
    } catch (e) {
      this.addLog(`permission.reply.failed: ${String(e)}`, 'error', 'permission')
    }
  }

  async answerQuestion(blockId: string, optionIds: string[]): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    let requestID = ''
    for (const b of this.transcriptBlocks) {
      if (b.id === blockId && b.type === 'question') {
        try {
          const payload = JSON.parse(b.toolInput) as Record<string, Object>
          requestID = (payload['requestID'] as string) || blockId
        } catch (e) {
          requestID = blockId
        }
        break
      }
    }
    if (requestID.length === 0) {
      this.addLog(`question.answer.failed: requestID not found for ${blockId}`, 'error', 'question')
      return
    }
    try {
      await client.replyQuestion(requestID, optionIds)
      this.addLog(`question.answered ${requestID} options=${optionIds.length}`, 'info', 'question')
      this.updatePermissionStatus(blockId, 'answered')
    } catch (e) {
      this.addLog(`question.answer.failed: ${String(e)}`, 'error', 'question')
    }
  }

  async rejectPermission(permId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      // M14: see approvePermission
      await client.replySessionPermission(this.activeSessionId, permId, 'deny')
      this.addLog(`permission.reply.deny ${permId}`, 'info', 'permission')
      this.updatePermissionStatus(permId, 'rejected')
    } catch (e) {
      this.addLog(`permission.reply.failed: ${String(e)}`, 'error', 'permission')
    }
  }

  updatePermissionStatus(permId: string, status: string): void {
    const blocks: TranscriptBlock[] = []
    for (const b of this.transcriptBlocks) {
      if (b.id === permId && (b.type === 'permission' || b.type === 'question')) {
        const updated = new TranscriptBlock()
        updated.id = b.id
        updated.type = b.type
        updated.permType = b.permType
        updated.permTitle = b.permTitle
        updated.permDescription = b.permDescription
        updated.permRiskLevel = b.permRiskLevel
        updated.permStatus = status
        updated.toolInput = b.toolInput
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

  /**
   * Switch agent build/plan mode.
   * Calls PATCH /config { agent: <mode> } on the opencode server so the next
   * prompt will be routed through the chosen agent.
   */
  async setAgentMode(mode: string): Promise<void> {
    const normalized = mode.toLowerCase()
    if (normalized !== 'build' && normalized !== 'plan') {
      this.addLog(`agent.mode.invalid: ${mode}`, 'warn', 'agent')
      ToastManager.show(`agent mode: use build or plan (got ${mode})`, 'warning')
      return
    }
    const client = this.getClient()
    if (client !== null) {
      try {
        const patch: Record<string, Object> = {}
        patch['agent'] = normalized
        await client.updateConfig(patch)
      } catch (e) {
        this.addLog(`agent.mode.update.failed: ${String(e)}`, 'warn', 'agent')
      }
    }
    this.agentMode = normalized
    this.addLog(`agent.mode = ${normalized}`, 'info', 'agent')
    ToastManager.show(`agent: ${normalized}`, 'info')
  }

  /**
   * Create a fresh session with a specific title, switch into it.
   */
  async createNewSessionWithTitle(title: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      const session = await client.createSession(title)
      this.activeSessionId = session.id
      this.sessionTitle = formatServerTitle(session.title)
      this.transcriptBlocks = []
      await this.loadSessions()
      if (this.eventClient) {
        this.eventClient.setSessionId(session.id)
      } else {
        this.connectEventStream()
      }
      this.addLog(`session.created ${session.id} (${title.length > 0 ? title : 'untitled'})`, 'info', 'session')
    } catch (e) {
      this.addLog(`session.create.failed: ${String(e)}`, 'error', 'session')
    }
  }

  /**
   * Abort the currently running agent run.
   * Sprint 1 / B.11 alias used by /abort slash command.
   */
  async abortRun(): Promise<void> {
    await this.abortSession()
    this.addLog('agent.aborted', 'info', 'agent')
    ToastManager.show('aborted', 'info')
  }

  // ══════════ Input Dispatch (Sprint 1) ══════════

  /**
   * Central input dispatcher. Called by ComposerBar's onSend callback.
   * - Intercepts /-prefixed commands via SlashCommandService
   * - Otherwise forwards to sendMessage() to talk to the agent
   */
  async dispatchInput(): Promise<void> {
    const text = this.inputText.trim()
    if (text.length === 0) return

    const parsed = parseSlashCommand(text)
    if (parsed === null) {
      // Not a slash command → send to agent as a normal prompt
      await this.sendMessage()
      return
    }

    // Slash command — handle locally without consuming LLM tokens
    this.inputText = ''
    this.addLog(`slash.${parsed.command.name} ${parsed.args}`, 'info', 'slash')
    await this.handleSlash(parsed.command, parsed.args)
  }

  /**
   * Execute a parsed slash command. Each branch maps to a method on Index
   * that talks to OpenCodeClient (or runs locally for /clear, /help, etc.).
   */
  async handleSlash(cmd: SlashCommand, args: string): Promise<void> {
    switch (cmd.name) {
      case 'help':
        ToastManager.show(buildHelpText(args), 'info')
        return
      case 'clear':
        this.inputText = ''
        return
      case 'new':
        await this.createNewSessionWithTitle(args)
        ToastManager.show(`new session: ${args.length > 0 ? args : 'untitled'}`, 'success')
        return
      case 'model':
        if (args.length > 0) {
          this.modelName = args
          ToastManager.show(`model: ${args}`, 'info')
        } else {
          ToastManager.show(`current model: ${this.modelName.length > 0 ? this.modelName : '(unset)'}`, 'info')
        }
        return
      case 'mode':
        await this.setAgentMode(args.length > 0 ? args : 'build')
        return
      case 'sessions':
        await this.loadSessions()
        ToastManager.show(`sessions: ${this.sessions.length}`, 'info')
        return
      case 'rename':
        await this.renameCurrentSession(args)
        return
      case 'fork':
        await this.forkCurrentSession()
        return
      case 'compact':
        await this.requestCompact()
        return
      case 'tokens':
        ToastManager.show(`tokens used: ${this.tokensUsed}`, 'info')
        return
      case 'abort':
        await this.abortRun()
        return
      case 'theme':
        ToastManager.show(`theme: ${args.length > 0 ? args : '(unchanged)'}`, 'info')
        return
      default:
        ToastManager.show(`unknown slash command: /${cmd.name}`, 'warning')
        return
    }
  }

  /**
   * Request context compaction. v1 server does not expose /compact; we
   * optimistically POST and surface the error if it fails.
   */
  async requestCompact(): Promise<void> {
    if (this.activeSessionId.length === 0) {
      ToastManager.show('no active session to compact', 'warning')
      return
    }
    const client = this.getClient()
    if (client === null) return
    try {
      const ok = await client.requestCompact(this.activeSessionId)
      if (!ok) {
        this.addLog('compact: server does not implement /compact (v1)', 'warn', 'session')
        ToastManager.show('compact: 不支持当前 server 版本', 'warning')
        return
      }
      this.addLog('session.compact.requested', 'info', 'session')
      ToastManager.show('compact requested', 'success')
    } catch (e) {
      this.addLog(`session.compact.failed: ${String(e)}`, 'error', 'session')
    }
  }

  async handleSessionAction(sessionId: string, action: string): Promise<void> {
    this.addLog(`session.action.${action} ${sessionId}`, 'info', 'session')
    if (action === 'fork') {
      await this.forkSession(sessionId)
    } else if (action === 'share') {
      await this.shareSession(sessionId)
    } else if (action === 'rename') {
      // Quick inline rename — in a richer UI, prompt for a title.
      // Sprint 1-B.12 wires the real API: see renameCurrentSession().
      const client = this.getClient()
      if (client === null) return
      let current = ''
      for (const s of this.sessions) {
        if (s.id === sessionId) {
          current = s.title
          break
        }
      }
      const next = `renamed-${sessionId.substring(0, 4)}-${Date.now() % 1000}`
      try {
        const updated = await client.renameSession(sessionId, next)
        this.addLog(`session.renamed ${sessionId} → ${updated.title}`, 'info', 'session')
        ToastManager.show(`renamed → ${updated.title}`, 'success')
        await this.loadSessions()
        if (this.activeSessionId === sessionId) {
          this.sessionTitle = formatServerTitle(updated.title)
        }
      } catch (e) {
        this.addLog(`session.rename.failed: ${String(e)}`, 'error', 'session')
      }
    } else if (action === 'delete') {
      await this.deleteSession(sessionId)
    }
  }

  async forkSession(sessionId: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    try {
      // v1 server may not implement /fork — OpenCodeClient falls back to a
      // plain createSession with a "(copy)" title.
      const session = await client.forkSession(sessionId)
      this.addLog(`session.forked ${session.id} from ${sessionId}`, 'info', 'session')
      ToastManager.show('session forked', 'success')
      await this.loadSessions()
      await this.selectSession(session.id)
    } catch (e) {
      this.addLog(`session.fork.failed: ${String(e)}`, 'error', 'session')
    }
  }

  /**
   * Rename the currently active session (used by /rename slash command).
   */
  async renameCurrentSession(newTitle: string): Promise<void> {
    const client = this.getClient()
    if (client === null) return
    if (this.activeSessionId.length === 0) {
      ToastManager.show('no active session to rename', 'warning')
      return
    }
    try {
      const updated = await client.renameSession(this.activeSessionId, newTitle)
      this.addLog(`session.renamed ${this.activeSessionId} → ${updated.title}`, 'info', 'session')
      ToastManager.show(`renamed → ${updated.title}`, 'success')
      this.sessionTitle = formatServerTitle(updated.title)
      await this.loadSessions()
    } catch (e) {
      this.addLog(`session.rename.failed: ${String(e)}`, 'error', 'session')
    }
  }

  /**
   * Fork the currently active session and switch to the new one.
   */
  async forkCurrentSession(): Promise<void> {
    if (this.activeSessionId.length === 0) {
      ToastManager.show('no active session to fork', 'warning')
      return
    }
    await this.forkSession(this.activeSessionId)
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
      // M14: see approvePermission
      await client.replySessionPermission(this.activeSessionId, permId, 'always')
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
        // M14: parent-controlled right panel
        rightPanelTab: $rightPanelTab,
        showRightPanel: $showRightPanel,

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
          this.dispatchInput()
        },
        onAbort: () => {
          this.abortSession()
        },
        onRefreshMcp: () => {
          this.loadMcpServers()
        },
        onRefreshLsp: () => {
          this.loadLspServers()
        },
        onRefreshFormatters: () => {
          this.loadFormatters()
        },
        mcpServers: this.mcpServers,
        lspServers: this.lspServers,
        formatterList: this.formatterList,
        onApprovePermission: (id: string) => {
          this.approvePermission(id)
        },
        onRejectPermission: (id: string) => {
          this.rejectPermission(id)
        },
        onAnswerQuestion: (blockId: string, optionIds: string[]) => {
          this.answerQuestion(blockId, optionIds)
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
