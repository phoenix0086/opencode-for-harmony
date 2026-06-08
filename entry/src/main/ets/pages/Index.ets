import { Runner, createRunner, RunnerConfig } from '../models/Runner'
import {
  SessionInfo, NormalizedMessage, NormalizedPart, FileDiff,
  PermissionRequest, EventTypes, ServerEvent
} from '../models/Event'
import { OpenCodeClient, HealthResult, normalizeFileDiffs } from '../services/OpenCodeClient'
import { EventStreamClient, EventCallback } from '../services/EventStreamClient'
import { storageService } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'
import { AppShell } from '../components/AppShell'
import { TranscriptBlock } from '../components/AgentTranscript'
import { ToolTimelineEntry } from '../components/ToolTimelinePanel'

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
  @State logEntries: string[] = []

  // ══════════ Composer State ══════════
  @State inputText: string = ''
  @State isSending: boolean = false

  // ══════════ Info State ══════════
  @State projectName: string = ''
  @State branchName: string = ''
  @State modelName: string = ''
  @State tokenCost: string = '0 tokens'

  // ══════════ Init State ══════════
  @State isInitialized: boolean = false

  // ══════════ Services ══════════
  private eventClient: EventStreamClient | null = null

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
      await storageService.init(getContext(this) as Context)
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
      // Silent fail on init
    }
    this.isInitialized = true
  }

  async testConnection(): Promise<void> {
    if (this.activeRunner === null) return
    try {
      this.addLog(`Connecting to ${this.activeRunner.host}:${this.activeRunner.port}...`)
      const client = new OpenCodeClient(this.activeRunner)
      const result = await client.health()
      this.isConnected = result.ok
      this.serverVersion = result.version
      this.serverUrl = `${this.activeRunner.host}:${this.activeRunner.port}`
      this.addLog(result.ok ? `Connected (v${result.version})` : `Health check failed: ${result.error}`)

      if (result.ok) {
        // Load project info
        try {
          const project = await client.getCurrentProject()
          this.projectName = project.name
        } catch (e) {
          // ignore
        }
        // Load VCS info (branch from GET /vcs)
        try {
          const vcs = await client.getVcsInfo()
          this.branchName = vcs.branch
        } catch (e) {
          // ignore
        }
      }
    } catch (e) {
      this.isConnected = false
    }
  }

  async loadSessions(): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      this.sessions = await client.listSessions()
    } catch (e) {
      // ignore
    }
  }

  // ══════════ Session Management ══════════

  async selectSession(sessionId: string): Promise<void> {
    if (this.activeRunner === null) return
    this.activeSessionId = sessionId

    // Find session title
    for (const s of this.sessions) {
      if (s.id === sessionId) {
        this.sessionTitle = s.title.length > 0 ? s.title : 'untitled'
        break
      }
    }

    await this.loadMessages()
    await this.loadDiffs()
    this.connectEventStream()
  }

  async loadMessages(): Promise<void> {
    if (this.activeRunner === null || this.activeSessionId.length === 0) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      const messages = await client.getMessages(this.activeSessionId)
      const blocks: TranscriptBlock[] = []
      const toolMap: Map<string, ToolTimelineEntry> = new Map()

      for (const msg of messages) {
        const msgBlocks = this.convertMessage(msg)
        for (const b of msgBlocks) {
          blocks.push(b)
          // Collect tool entries from tool-type blocks, dedup by toolId
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

      this.transcriptBlocks = blocks
      const toolList: ToolTimelineEntry[] = []
      toolMap.forEach((entry: ToolTimelineEntry) => {
        toolList.push(entry)
      })
      this.toolEntries = toolList
    } catch (e) {
      // ignore
    }
  }

  async loadDiffs(): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      // Use VCS diff (GET /vcs/diff?mode=git) — no messageID required
      const rawDiffs = await client.getVcsDiff('git')
      this.diffs = normalizeFileDiffs(rawDiffs)
    } catch (e) {
      // ignore
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

  private addLog(msg: string): void {
    const now = new Date()
    const hh = String(now.getHours()).padStart(2, '0')
    const mm = String(now.getMinutes()).padStart(2, '0')
    const ss = String(now.getSeconds()).padStart(2, '0')
    const entry = `${hh}:${mm}:${ss} ${msg}`
    const list: string[] = []
    for (const e of this.logEntries) {
      list.push(e)
    }
    list.push(entry)
    // Keep last 200 entries
    while (list.length > 200) {
      list.shift()
    }
    this.logEntries = list
  }

  connectEventStream(): void {
    if (this.activeRunner === null) return

    // Close existing connection
    if (this.eventClient) {
      this.eventClient.close()
    }

    const client = new OpenCodeClient(this.activeRunner)
    this.eventClient = new EventStreamClient(client, this.activeSessionId)
    this.addLog('Event stream connecting...')

    // Listen for new messages
    this.eventClient.on(EventTypes.SESSION_MESSAGE_UPDATED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.addLog(`message.updated ${event.id}`)
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
        this.addLog('llm.started')
      }
    })

    this.eventClient.on(EventTypes.SESSION_LLM_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isStreaming = false
        this.isSending = false
        this.addLog('llm.ended')
      }
    })

    // Listen for tool calls
    this.eventClient.on(EventTypes.SESSION_TOOL_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.started ${tn}`)
        this.loadMessages()
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_SUCCESS, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.success ${tn}`)
        this.loadMessages()
        this.loadDiffs()
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_FAILED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        const tn = (event.properties['toolName'] as string) || ''
        this.addLog(`tool.failed ${tn}`)
        this.loadMessages()
      }
    })

    // Listen for permission requests
    this.eventClient.on(EventTypes.PERMISSION_ASKED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.addLog(`permission.asked ${(event.properties['permType'] as string) || ''}`)
        const block = new TranscriptBlock()
        block.id = event.id
        block.type = 'permission'
        block.permType = (event.properties['permType'] as string) || 'unknown'
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

    // Listen for session run ended (replaces idle)
    this.eventClient.on(EventTypes.SESSION_RUN_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isSending = false
        this.isStreaming = false
        this.addLog('session.run.ended')
      }
    })

    // Listen for errors
    this.eventClient.on('error', (event: ServerEvent) => {
      const errMsg = (event.properties['message'] as string) || 'unknown error'
      this.addLog(`error: ${errMsg}`)
    })

    this.eventClient.on('connected', (_event: ServerEvent) => {
      this.addLog('Event stream connected')
    })

    this.eventClient.connect()
  }

  // ══════════ Actions ══════════

  async sendMessage(): Promise<void> {
    const text = this.inputText.trim()
    if (text.length === 0 || this.activeRunner === null || this.activeSessionId.length === 0) return

    this.inputText = ''
    this.isSending = true

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
      const client = new OpenCodeClient(this.activeRunner)
      this.addLog(`Sending message: ${text.substring(0, 40)}...`)
      await client.sendMessageAsync(this.activeSessionId, text)
    } catch (e) {
      this.isSending = false
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
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      const session = await client.createSession()
      await this.loadSessions()
      await this.selectSession(session.id)
    } catch (e) {
      // ignore
    }
  }

  async approvePermission(permId: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      await client.replyPermission(permId, 'once')
      this.updatePermissionStatus(permId, 'approved')
    } catch (e) {
      // ignore
    }
  }

  async rejectPermission(permId: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      await client.replyPermission(permId, 'deny')
      this.updatePermissionStatus(permId, 'rejected')
    } catch (e) {
      // ignore
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
    if (this.activeRunner === null || this.activeSessionId.length === 0) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      await client.abortSession(this.activeSessionId)
      this.isSending = false
      this.isStreaming = false
    } catch (e) {
      // ignore
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
        }
      })
    }
  }
}
