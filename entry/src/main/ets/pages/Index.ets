import { Runner, createRunner, RunnerConfig } from '../models/Runner'
import {
  SessionInfo, MessageInfo, MessagePart, FileDiff,
  PermissionRequest, EventTypes, ServerEvent
} from '../models/Event'
import { OpenCodeClient, HealthResult } from '../services/OpenCodeClient'
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
      const client = new OpenCodeClient(this.activeRunner)
      const result = await client.health()
      this.isConnected = result.ok
      this.serverVersion = result.version
      this.serverUrl = `${this.activeRunner.host}:${this.activeRunner.port}`

      if (result.ok) {
        // Load project info
        try {
          const project = await client.getCurrentProject()
          this.projectName = project.name
        } catch (e) {
          // ignore
        }
        // Load VCS info
        try {
          const vcs = await client.getVcsStatus()
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
      for (const msg of messages) {
        const msgBlocks = this.convertMessage(msg)
        for (const b of msgBlocks) {
          blocks.push(b)
        }
      }
      this.transcriptBlocks = blocks
    } catch (e) {
      // ignore
    }
  }

  async loadDiffs(): Promise<void> {
    if (this.activeRunner === null || this.activeSessionId.length === 0) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      this.diffs = await client.getSessionDiff(this.activeSessionId)
    } catch (e) {
      // ignore
    }
  }

  // ══════════ Message Conversion (bug-fixed) ══════════

  convertMessage(msg: MessageInfo): TranscriptBlock[] {
    const blocks: TranscriptBlock[] = []

    if (msg.role === 'user') {
      // User message: concatenate text parts
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
      // Assistant message: text parts + tool parts as separate blocks
      let textContent = ''
      for (const part of msg.parts) {
        if (part.type === 'text') {
          textContent += part.content
        }
      }

      // Add text block if non-empty
      if (textContent.length > 0) {
        const textBlock = new TranscriptBlock()
        textBlock.id = `${msg.id}_text`
        textBlock.type = 'assistant'
        textBlock.role = 'assistant'
        textBlock.content = textContent
        blocks.push(textBlock)
      }

      // Add tool invocation blocks — FIX: each tool gets its own block
      for (const part of msg.parts) {
        if (part.type === 'tool-invocation') {
          const toolBlock = new TranscriptBlock()
          // Use part.id as stable tool identifier (FIX: not msg.id prefix)
          toolBlock.id = `tool_${part.id}`
          toolBlock.type = 'tool'
          toolBlock.toolId = part.id
          toolBlock.toolName = (part.metadata['toolName'] as string) || 'unknown'
          toolBlock.toolStatus = (part.metadata['state'] as string) || 'success'
          toolBlock.toolInput = part.content
          toolBlock.toolStep = (part.metadata['step'] as number) || 0
          blocks.push(toolBlock)

          // Also add to tool timeline panel
          const entry = new ToolTimelineEntry()
          entry.id = part.id
          entry.toolName = toolBlock.toolName
          entry.status = toolBlock.toolStatus
          entry.input = part.content
          entry.step = toolBlock.toolStep
          const entries: ToolTimelineEntry[] = []
          for (const e of this.toolEntries) {
            entries.push(e)
          }
          entries.push(entry)
          this.toolEntries = entries
        }
      }
    }

    return blocks
  }

  // ══════════ Event Stream ══════════

  connectEventStream(): void {
    if (this.activeRunner === null) return

    // Close existing connection
    if (this.eventClient) {
      this.eventClient.close()
    }

    const client = new OpenCodeClient(this.activeRunner)
    this.eventClient = new EventStreamClient(client, this.activeSessionId)

    // Listen for new messages
    this.eventClient.on(EventTypes.SESSION_MESSAGE_UPDATED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.loadMessages()
      }
    })

    // Listen for LLM streaming
    this.eventClient.on(EventTypes.SESSION_LLM_DELTA, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isStreaming = true
      }
    })

    this.eventClient.on(EventTypes.SESSION_LLM_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isStreaming = false
        this.isSending = false
      }
    })

    // Listen for tool calls
    this.eventClient.on(EventTypes.SESSION_TOOL_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.loadMessages()
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_SUCCESS, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.loadMessages()
        this.loadDiffs()
      }
    })

    // Listen for permission requests
    this.eventClient.on(EventTypes.PERMISSION_ASKED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
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

    // Listen for session idle
    this.eventClient.on(EventTypes.SESSION_IDLE, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.activeSessionId) {
        this.isSending = false
        this.isStreaming = false
      }
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
      await client.replyPermission(permId, 'approve')
      this.updatePermissionStatus(permId, 'approved')
    } catch (e) {
      // ignore
    }
  }

  async rejectPermission(permId: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner)
      await client.replyPermission(permId, 'reject')
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
