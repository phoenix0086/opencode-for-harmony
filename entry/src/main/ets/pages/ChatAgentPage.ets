import { Runner } from '../models/Runner'
import { MessageInfo, MessagePart, ServerEvent, EventTypes, PermissionRequest } from '../models/Event'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { EventStreamClient, EventCallback } from '../services/EventStreamClient'

/**
 * Chat 消息展示项
 */
class ChatDisplayMsg {
  id: string = ''
  role: string = '' // 'user' | 'assistant' | 'tool' | 'permission'
  content: string = ''
  toolName: string = ''
  toolStatus: string = ''
  isStreaming: boolean = false
}

/**
 * AI 编程会话页面
 * 核心页面：消息交互、工具调用展示、权限审批
 */
@Component
export struct ChatAgentPage {
  @Prop activeRunner: Runner | null = null
  @Prop sessionId: string = ''
  @State messages: ChatDisplayMsg[] = []
  @State inputText: string = ''
  @State isSending: boolean = false
  @State sessionTitle: string = ''
  @State errorMsg: string = ''
  private eventClient: EventStreamClient | null = null
  private streamingContent: string = ''

  async aboutToAppear(): Promise<void> {
    if (this.activeRunner !== null && this.sessionId !== '') {
      await this.loadMessages()
      this.connectEventStream()
    }
  }

  aboutToDisappear(): void {
    if (this.eventClient) {
      this.eventClient.close()
      this.eventClient = null
    }
  }

  async loadMessages(): Promise<void> {
    if (this.activeRunner === null || this.sessionId === '') return
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      const msgs = await client.getMessages(this.sessionId)
      const displayMsgs: ChatDisplayMsg[] = []
      for (const msg of msgs) {
        const displayMsg = this.convertMessage(msg)
        displayMsgs.push(displayMsg)
      }
      this.messages = displayMsgs
    } catch (e) {
      this.errorMsg = `加载消息失败: ${String(e)}`
    }
  }

  convertMessage(msg: MessageInfo): ChatDisplayMsg {
    const d = new ChatDisplayMsg()
    d.id = msg.id
    d.role = msg.role

    // 从 parts 中提取内容
    let textContent = ''
    for (const part of msg.parts) {
      if (part.type === 'text') {
        textContent += part.content
      } else if (part.type === 'tool-invocation') {
        // 工具调用部分单独展示
        const toolMsg = new ChatDisplayMsg()
        toolMsg.id = `${msg.id}_${part.id}`
        toolMsg.role = 'tool'
        toolMsg.content = part.content
        const meta = part.metadata
        if (meta['toolName']) {
          toolMsg.toolName = meta['toolName'] as string
        }
        if (meta['state']) {
          toolMsg.toolStatus = meta['state'] as string
        }
      }
    }
    d.content = textContent || (msg.role === 'user' ? '[用户消息]' : '[AI 回复]')
    return d
  }

  connectEventStream(): void {
    if (this.activeRunner === null) return
    const client = new OpenCodeClient(this.activeRunner!)
    this.eventClient = new EventStreamClient(client, this.sessionId)

    // 监听 LLM 流式输出
    this.eventClient.on(EventTypes.SESSION_LLM_DELTA, (event: ServerEvent) => {
      const props = event.properties
      if (props['sessionID'] === this.sessionId) {
        const delta = props['delta'] as string
        if (delta) {
          this.streamingContent += delta
          this.updateStreamingMessage()
        }
      }
    })

    // 监听 LLM 开始
    this.eventClient.on(EventTypes.SESSION_LLM_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.streamingContent = ''
        this.addStreamingPlaceholder()
      }
    })

    // 监听 LLM 结束
    this.eventClient.on(EventTypes.SESSION_LLM_ENDED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.finalizeStreamingMessage()
      }
    })

    // 监听工具调用
    this.eventClient.on(EventTypes.SESSION_TOOL_STARTED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.addToolCall(event, 'running')
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_SUCCESS, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.updateToolCall(event, 'success')
      }
    })

    this.eventClient.on(EventTypes.SESSION_TOOL_FAILED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.updateToolCall(event, 'error')
      }
    })

    // 监听权限请求
    this.eventClient.on(EventTypes.PERMISSION_ASKED, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.addPermissionRequest(event)
      }
    })

    // 监听会话空闲
    this.eventClient.on(EventTypes.SESSION_IDLE, (event: ServerEvent) => {
      if (event.properties['sessionID'] === this.sessionId) {
        this.isSending = false
      }
    })

    this.eventClient.connect()
  }

  addStreamingPlaceholder(): void {
    const msg = new ChatDisplayMsg()
    msg.id = `streaming_${Date.now()}`
    msg.role = 'assistant'
    msg.content = ''
    msg.isStreaming = true
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) { newList.push(m) }
    newList.push(msg)
    this.messages = newList
  }

  updateStreamingMessage(): void {
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) {
      if (m.isStreaming) {
        const updated = new ChatDisplayMsg()
        updated.id = m.id
        updated.role = m.role
        updated.content = this.streamingContent
        updated.isStreaming = true
        newList.push(updated)
      } else {
        newList.push(m)
      }
    }
    this.messages = newList
  }

  finalizeStreamingMessage(): void {
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) {
      if (m.isStreaming) {
        const updated = new ChatDisplayMsg()
        updated.id = m.id
        updated.role = m.role
        updated.content = this.streamingContent || '[AI 回复完成]'
        updated.isStreaming = false
        newList.push(updated)
      } else {
        newList.push(m)
      }
    }
    this.messages = newList
    this.streamingContent = ''
  }

  addToolCall(event: ServerEvent, status: string): void {
    const msg = new ChatDisplayMsg()
    msg.id = `tool_${event.id}`
    msg.role = 'tool'
    msg.toolName = (event.properties['toolName'] as string) || 'unknown'
    msg.toolStatus = status
    msg.content = (event.properties['input'] as string) || ''
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) { newList.push(m) }
    newList.push(msg)
    this.messages = newList
  }

  updateToolCall(event: ServerEvent, status: string): void {
    const toolId = `tool_${event.id}`
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) {
      if (m.id === toolId || m.id.startsWith('tool_')) {
        const updated = new ChatDisplayMsg()
        updated.id = m.id
        updated.role = m.role
        updated.toolName = m.toolName
        updated.toolStatus = status
        updated.content = m.content
        newList.push(updated)
      } else {
        newList.push(m)
      }
    }
    this.messages = newList
  }

  addPermissionRequest(event: ServerEvent): void {
    const msg = new ChatDisplayMsg()
    msg.id = `perm_${event.id}`
    msg.role = 'permission'
    msg.toolName = (event.properties['type'] as string) || 'unknown'
    msg.content = (event.properties['title'] as string) || (event.properties['description'] as string) || '需要审批'
    msg.toolStatus = 'pending'
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) { newList.push(m) }
    newList.push(msg)
    this.messages = newList
  }

  async sendMessage(): Promise<void> {
    if (this.inputText === '' || this.activeRunner === null || this.sessionId === '' || this.isSending) return
    const text = this.inputText.trim()
    this.inputText = ''
    this.isSending = true

    // 添加用户消息到列表
    const userMsg = new ChatDisplayMsg()
    userMsg.id = `user_${Date.now()}`
    userMsg.role = 'user'
    userMsg.content = text
    const newList: ChatDisplayMsg[] = []
    for (const m of this.messages) { newList.push(m) }
    newList.push(userMsg)
    this.messages = newList

    try {
      const client = new OpenCodeClient(this.activeRunner!)
      // 使用异步发送，通过 SSE 接收响应
      await client.sendMessageAsync(this.sessionId, text)
    } catch (e) {
      const errMsg = new ChatDisplayMsg()
      errMsg.id = `err_${Date.now()}`
      errMsg.role = 'assistant'
      errMsg.content = `发送失败: ${String(e)}`
      const errList: ChatDisplayMsg[] = []
      for (const m of this.messages) { errList.push(m) }
      errList.push(errMsg)
      this.messages = errList
      this.isSending = false
    }
  }

  async abortSession(): Promise<void> {
    if (this.activeRunner === null || this.sessionId === '') return
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      await client.abortSession(this.sessionId)
      this.isSending = false
    } catch (e) {
      this.errorMsg = `停止失败: ${String(e)}`
    }
  }

  async approvePermission(permId: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      await client.replyPermission(permId, 'approve')
    } catch (e) {
      this.errorMsg = `审批失败: ${String(e)}`
    }
  }

  async rejectPermission(permId: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      await client.replyPermission(permId, 'reject')
    } catch (e) {
      this.errorMsg = `拒绝失败: ${String(e)}`
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.sessionTitle || 'AI 编程会话')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.isSending) {
          Button('停止')
            .type(ButtonType.Capsule)
            .backgroundColor('#EF4444')
            .fontColor('#FFFFFF')
            .fontSize(12)
            .onClick(() => this.abortSession())
        }
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 消息列表
      List() {
        ForEach(this.messages, (msg: ChatDisplayMsg) => {
          ListItem() {
            if (msg.role === 'user') {
              this.UserMessage(msg)
            } else if (msg.role === 'tool') {
              this.ToolCallCard(msg)
            } else if (msg.role === 'permission') {
              this.PermissionCard(msg)
            } else {
              this.AssistantMessage(msg)
            }
          }
          .padding({ top: 4, bottom: 4 })
        }, (msg: ChatDisplayMsg) => msg.id)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })
      .scrollBar(BarState.Auto)

      // 错误提示
      if (this.errorMsg !== '') {
        Text(this.errorMsg)
          .fontSize(12)
          .fontColor('#EF4444')
          .margin({ bottom: 8 })
      }

      // 输入区
      Row() {
        TextInput({ text: this.inputText, placeholder: '输入编程需求...' })
          .layoutWeight(1)
          .height(44)
          .fontSize(14)
          .backgroundColor('#F8FAFC')
          .borderRadius(22)
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .onChange((v: string) => { this.inputText = v })
          .onSubmit(() => this.sendMessage())

        Button(this.isSending ? '...' : '发送')
          .type(ButtonType.Capsule)
          .backgroundColor(this.isSending ? '#94A3B8' : '#4F46E5')
          .fontColor('#FFFFFF')
          .height(44)
          .margin({ left: 12 })
          .enabled(!this.isSending)
          .onClick(() => this.sendMessage())
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding(20)
  }

  // ══════════ 消息组件 ══════════

  @Builder
  UserMessage(msg: ChatDisplayMsg) {
    Row() {
      Blank()
      Text(msg.content)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .backgroundColor('#4F46E5')
        .padding(12)
        .borderRadius(16)
        .constraintSize({ maxWidth: '70%' })
    }
    .width('100%')
  }

  @Builder
  AssistantMessage(msg: ChatDisplayMsg) {
    Row() {
      Column() {
        Text(msg.content || (msg.isStreaming ? '正在思考...' : ''))
          .fontSize(14)
          .fontColor('#1E293B')
          .backgroundColor('#F1F5F9')
          .padding(12)
          .borderRadius(16)
          .constraintSize({ maxWidth: '85%' })

        if (msg.isStreaming) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color('#4F46E5')
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
  }

  @Builder
  ToolCallCard(msg: ChatDisplayMsg) {
    Row() {
      Column() {
        Row() {
          Text(this.getToolIcon(msg.toolName))
            .fontSize(14)
          Text(msg.toolName || '工具调用')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#334155')
            .margin({ left: 6 })
          Blank()
          Text(this.getToolStatusLabel(msg.toolStatus))
            .fontSize(11)
            .fontColor(this.getToolStatusColor(msg.toolStatus))
            .backgroundColor(this.getToolStatusBg(msg.toolStatus))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .width('100%')

        if (msg.content) {
          Text(msg.content)
            .fontSize(12)
            .fontColor('#64748B')
            .margin({ top: 6 })
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '85%' })
        }
      }
      .padding(12)
      .borderRadius(12)
      .backgroundColor('#FFF7ED')
      .borderWidth(1)
      .borderColor('#FED7AA')
      .constraintSize({ maxWidth: '85%' })
      Blank()
    }
    .width('100%')
  }

  @Builder
  PermissionCard(msg: ChatDisplayMsg) {
    Column() {
      Row() {
        Text('⚠️')
          .fontSize(14)
        Text('权限审批')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#DC2626')
          .margin({ left: 6 })
        Blank()
        Text(msg.toolName)
          .fontSize(11)
          .fontColor('#DC2626')
          .backgroundColor('#FEE2E2')
          .borderRadius(4)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      }
      .width('100%')

      Text(msg.content)
        .fontSize(13)
        .fontColor('#334155')
        .margin({ top: 8 })

      Row() {
        Button('允许')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(32)
          .backgroundColor('#22C55E')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => this.approvePermission(msg.id))

        Button('拒绝')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(32)
          .backgroundColor('#EF4444')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 8 })
          .onClick(() => this.rejectPermission(msg.id))
      }
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor('#FEF2F2')
    .borderWidth(1)
    .borderColor('#FECACA')
    .alignItems(HorizontalAlign.Start)
  }

  // ══════════ 辅助方法 ══════════

  getToolIcon(toolName: string): string {
    if (toolName.includes('read') || toolName.includes('file')) return '📄'
    if (toolName.includes('write') || toolName.includes('edit')) return '✏️'
    if (toolName.includes('bash') || toolName.includes('shell')) return '⚡'
    if (toolName.includes('grep') || toolName.includes('search')) return '🔍'
    if (toolName.includes('web')) return '🌐'
    if (toolName.includes('diff') || toolName.includes('git')) return '📋'
    return '🔧'
  }

  getToolStatusLabel(status: string): string {
    switch (status) {
      case 'running': return '运行中'
      case 'success': return '成功'
      case 'error': return '失败'
      case 'pending': return '等待'
      case 'cancelled': return '已取消'
      default: return status
    }
  }

  getToolStatusColor(status: string): string {
    switch (status) {
      case 'running': return '#4F46E5'
      case 'success': return '#22C55E'
      case 'error': return '#EF4444'
      default: return '#64748B'
    }
  }

  getToolStatusBg(status: string): string {
    switch (status) {
      case 'running': return '#E0E7FF'
      case 'success': return '#DCFCE7'
      case 'error': return '#FEE2E2'
      default: return '#F1F5F9'
    }
  }
}
