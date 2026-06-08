import { ServerEvent, GlobalEvent, EventTypes, NormalizedMessage, NormalizedPart, PermissionRequest } from '../models/Event'
import { OpenCodeClient } from './OpenCodeClient'

/**
 * 轮询式事件客户端
 * 定期从 OpenCode Server 获取新消息和权限请求
 * 替代 SSE 方案，兼容 ArkTS HTTP 模块限制
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
   * 开始轮询
   */
  connect(): void {
    if (this.polling) return
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

      // 首次轮询完成后发送 connected 事件
      if (!this.initialized) {
        this.initialized = true
        const connectedEvent = new ServerEvent()
        connectedEvent.type = EventTypes.SERVER_CONNECTED
        this.emit(EventTypes.SERVER_CONNECTED, connectedEvent)
        this.emit('connected', connectedEvent)
      }

      // 发送心跳事件保持连接状态
      const heartbeat = new ServerEvent()
      heartbeat.type = EventTypes.SERVER_HEARTBEAT
      this.emit(EventTypes.SERVER_HEARTBEAT, heartbeat)
    } catch (e) {
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

    // First poll: record existing message IDs without firing events
    if (this.seenMessageIds.length === 0 && messages.length > 0) {
      for (const msg of messages) {
        this.seenMessageIds.push(msg.id)
      }
      return
    }

    for (const msg of messages) {
      if (!this.containsString(this.seenMessageIds, msg.id)) {
        this.seenMessageIds.push(msg.id)

        // Fire message updated event
        const msgEvent = new ServerEvent()
        msgEvent.id = msg.id
        msgEvent.type = EventTypes.SESSION_MESSAGE_UPDATED
        msgEvent.properties['sessionID'] = this.sessionId
        msgEvent.properties['message'] = msg as Object
        this.emit(EventTypes.SESSION_MESSAGE_UPDATED, msgEvent)

        // Infer LLM events from message content
        if (msg.role === 'assistant') {
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
            toolEvent.id = `${msg.id}_${part.id}`
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
