import { ServerEvent, EventTypes, NormalizedMessage } from '../models/Event'
import { OpenCodeClient } from './OpenCodeClient'

/**
 * 轮询式事件客户端
 * 定期从 OpenCode Server 获取新消息和权限请求
 * 替代 SSE 方案，兼容 ArkTS HTTP 模块限制
 *
 * 轮询状态机模式:
 *   cold_start  — 首次轮询，静默记录已有消息 ID
 *   active_run  — 活跃运行中，有新消息时触发事件
 *   idle        — 空闲状态，等待新消息
 *   error       — 连续错误过多，进入错误状态
 */
export class EventStreamClient {
  private client: OpenCodeClient
  private sessionId: string = ''
  private polling: boolean = false
  private pollingTimer: number = -1
  private pollingInterval: number = 2000
  private seenMessageIds: string[] = []
  private seenPermissionIds: string[] = []
  private listeners: Map<string, EventCallback[]> = new Map()
  private initialized: boolean = false
  private pollingMode: string = 'cold_start'
  private consecutiveErrors: number = 0
  private lastActivityTime: number = 0
  private runTimeout: number = 30000  // 30 seconds
  private llmStartedEmitted: boolean = false

  constructor(client: OpenCodeClient, sessionId: string) {
    this.client = client
    this.sessionId = sessionId
  }

  /**
   * 设置监听的会话 ID
   */
  setSessionId(id: string): void {
    this.sessionId = id
    this.seenMessageIds = []
    this.seenPermissionIds = []
    this.initialized = false
  }

  /**
   * 将轮询模式切换为 active_run
   */
  markActiveRun(): void {
    this.pollingMode = 'active_run'
    this.lastActivityTime = Date.now()
    this.llmStartedEmitted = false
  }

  /**
   * 将轮询模式切换为 idle
   */
  markIdle(): void {
    this.pollingMode = 'idle'
  }

  /**
   * 更新轮询间隔
   */
  setPollingInterval(ms: number): void {
    this.pollingInterval = ms
  }

  /**
   * 获取当前轮询模式
   */
  getStatus(): string {
    return this.pollingMode
  }

  /**
   * 开始轮询
   */
  connect(): void {
    if (this.polling) return
    this.pollingMode = 'cold_start'
    this.polling = true
    this.doPoll()
  }

  /**
   * 停止轮询
   */
  close(): void {
    this.polling = false
    if (this.pollingTimer !== -1) {
      clearTimeout(this.pollingTimer)
      this.pollingTimer = -1
    }
    this.emit('closed', new ServerEvent())
  }

  /**
   * 手动触发一次轮询
   */
  reconnect(): void {
    this.close()
    this.seenMessageIds = []
    this.seenPermissionIds = []
    this.initialized = false
    this.pollingMode = 'cold_start'
    this.connect()
  }

  isConnected(): boolean {
    return this.polling
  }

  private async doPoll(): Promise<void> {
    if (!this.polling) return

    try {
      await this.pollMessages()
      await this.pollPermissions()

      // 成功轮询：重置连续错误计数
      this.consecutiveErrors = 0

      // 首次轮询完成后发送 connected 事件
      if (!this.initialized) {
        this.initialized = true
        const connectedEvent = new ServerEvent()
        connectedEvent.type = EventTypes.SERVER_CONNECTED
        this.emit(EventTypes.SERVER_CONNECTED, connectedEvent)
        this.emit('connected', connectedEvent)
      }

      // cold_start 模式下，首次成功轮询后过渡到 idle
      if (this.pollingMode === 'cold_start') {
        this.pollingMode = 'idle'
      }

      // 发送心跳事件保持连接状态
      const heartbeat = new ServerEvent()
      heartbeat.type = EventTypes.SERVER_HEARTBEAT
      this.emit(EventTypes.SERVER_HEARTBEAT, heartbeat)
    } catch (e) {
      // 失败轮询：递增连续错误计数
      this.consecutiveErrors++

      // 连续错误达到阈值，进入 error 模式并发出警告事件
      if (this.consecutiveErrors >= 3) {
        this.pollingMode = 'error'
        const warningEvent = new ServerEvent()
        warningEvent.type = 'poll.warning'
        warningEvent.properties['message'] = 'Consecutive poll errors reached ' + String(this.consecutiveErrors)
        this.emit('poll.warning', warningEvent)
      }

      const errEvent = new ServerEvent()
      errEvent.type = 'error'
      errEvent.properties['message'] = String(e)
      this.emit('error', errEvent)
    }

    // 安排下一次轮询
    if (this.polling) {
      this.pollingTimer = setTimeout((): void => {
        this.doPoll()
      }, this.pollingInterval)
    }
  }

  private async pollMessages(): Promise<void> {
    if (this.sessionId.length === 0) return

    const messages = await this.client.getMessages(this.sessionId)

    // cold_start 模式：静默记录所有已有消息 ID，不触发事件
    if (this.pollingMode === 'cold_start') {
      for (const msg of messages) {
        if (!this.containsString(this.seenMessageIds, msg.id)) {
          this.seenMessageIds.push(msg.id)
        }
      }
      return
    }

    // active_run 或 idle 模式：为新消息触发事件
    let newMessageCount: number = 0

    for (const msg of messages) {
      if (!this.containsString(this.seenMessageIds, msg.id)) {
        this.seenMessageIds.push(msg.id)
        newMessageCount++

        // Fire message updated event
        const msgEvent = new ServerEvent()
        msgEvent.id = msg.id
        msgEvent.type = EventTypes.SESSION_MESSAGE_UPDATED
        msgEvent.properties['sessionID'] = this.sessionId
        msgEvent.properties['message'] = msg as Object
        this.emit(EventTypes.SESSION_MESSAGE_UPDATED, msgEvent)

        // Infer LLM events from message content
        if (msg.role === 'assistant') {
          this.lastActivityTime = Date.now()
          // Emit LLM started once per run
          if (!this.llmStartedEmitted) {
            this.llmStartedEmitted = true
            const llmStartEvent = new ServerEvent()
            llmStartEvent.type = EventTypes.SESSION_LLM_STARTED
            llmStartEvent.properties['sessionID'] = this.sessionId
            this.emit(EventTypes.SESSION_LLM_STARTED, llmStartEvent)
          }
          const llmEvent = new ServerEvent()
          llmEvent.id = msg.id
          llmEvent.type = EventTypes.SESSION_LLM_DELTA
          llmEvent.properties['sessionID'] = this.sessionId
          llmEvent.properties['messageID'] = msg.id
          let deltaText = ''
          for (const part of msg.parts) {
            if (part.type === 'text') {
              deltaText += part.content
            }
          }
          llmEvent.properties['delta'] = deltaText
          this.emit(EventTypes.SESSION_LLM_DELTA, llmEvent)
        }

        // Check tool invocation parts
        for (const part of msg.parts) {
          if (part.type === 'tool-invocation') {
            const toolEvent = new ServerEvent()
            toolEvent.id = msg.id + '_' + part.id
            toolEvent.type = EventTypes.SESSION_TOOL_SUCCESS
            toolEvent.properties['sessionID'] = this.sessionId
            toolEvent.properties['toolName'] = part.toolName
            toolEvent.properties['input'] = part.toolArgs
            toolEvent.properties['step'] = part.step
            this.emit(EventTypes.SESSION_TOOL_SUCCESS, toolEvent)
          }
        }
      }
    }

    // active_run 模式下无新消息时，检查是否应该过渡到 idle
    if (this.pollingMode === 'active_run' && newMessageCount === 0) {
      const elapsed = Date.now() - this.lastActivityTime
      if (elapsed > this.runTimeout) {
        // Timeout or idle detected — emit run-end events before transitioning
        const runEndEvent = new ServerEvent()
        runEndEvent.type = EventTypes.SESSION_RUN_ENDED
        runEndEvent.properties['sessionID'] = this.sessionId
        runEndEvent.properties['reason'] = elapsed > this.runTimeout ? 'timeout' : 'idle'
        this.emit(EventTypes.SESSION_RUN_ENDED, runEndEvent)

        const llmEndEvent = new ServerEvent()
        llmEndEvent.type = EventTypes.SESSION_LLM_ENDED
        llmEndEvent.properties['sessionID'] = this.sessionId
        this.emit(EventTypes.SESSION_LLM_ENDED, llmEndEvent)

        this.markIdle()
      }
    }
  }

  private async pollPermissions(): Promise<void> {
    const permissions = await this.client.listPermissions()

    for (const perm of permissions) {
      if (!this.containsString(this.seenPermissionIds, perm.id) && perm.status === 'pending') {
        this.seenPermissionIds.push(perm.id)

        const permEvent = new ServerEvent()
        permEvent.id = perm.id
        permEvent.type = EventTypes.PERMISSION_ASKED
        permEvent.properties['sessionID'] = perm.sessionID
        permEvent.properties['permType'] = perm.type
        permEvent.properties['title'] = perm.title
        permEvent.properties['description'] = perm.description
        permEvent.properties['riskLevel'] = perm.riskLevel
        this.emit(EventTypes.PERMISSION_ASKED, permEvent)
      }
    }
  }

  private containsString(arr: string[], value: string): boolean {
    for (const item of arr) {
      if (item === value) return true
    }
    return false
  }

  /**
   * 注册事件监听
   */
  on(eventType: string, callback: EventCallback): void {
    if (!this.listeners.has(eventType)) {
      const emptyArr: EventCallback[] = []
      this.listeners.set(eventType, emptyArr)
    }
    this.listeners.get(eventType)!.push(callback)
  }

  /**
   * 移除事件监听
   */
  off(eventType: string, callback?: EventCallback): void {
    if (!callback) {
      this.listeners.delete(eventType)
      return
    }
    const list = this.listeners.get(eventType)
    if (list) {
      const newList: EventCallback[] = []
      for (const cb of list) {
        if (cb !== callback) {
          newList.push(cb)
        }
      }
      this.listeners.set(eventType, newList)
    }
  }

  private emit(eventType: string, event: ServerEvent): void {
    const list = this.listeners.get(eventType)
    if (list) {
      for (const cb of list) {
        try {
          cb(event)
        } catch (e) {
          // 回调错误不影响其他监听器
        }
      }
    }
    // 通配符监听器
    const wildcardList = this.listeners.get('*')
    if (wildcardList) {
      for (const cb of wildcardList) {
        try {
          cb(event)
        } catch (e) {
          // ignore
        }
      }
    }
  }
}

/** 事件回调类型 */
export type EventCallback = (event: ServerEvent) => void
