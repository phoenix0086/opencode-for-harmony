import { http } from '@kit.NetworkKit'
import { ServerEvent, GlobalEvent, EventTypes } from '../models/Event'

/**
 * SSE 事件流客户端
 * 连接 OpenCode Server 的 /event 端点，实时接收事件
 */
export class EventStreamClient {
  private url: string = ''
  private headers: Record<string, string> = {}
  private request: http.HttpRequest | null = null
  private connected: boolean = false
  private reconnectTimer: number = -1
  private reconnectDelay: number = 3000
  private maxReconnectDelay: number = 30000
  private listeners: Map<string, EventCallback[]> = new Map()
  private buffer: string = ''

  constructor(url: string, headers: Record<string, string>) {
    this.url = url
    this.headers = headers
  }

  /**
   * 连接到 SSE 事件流
   */
  connect(): void {
    if (this.connected) return
    this.doConnect()
  }

  private doConnect(): void {
    try {
      this.request = http.createHttp()
      const req = this.request

      req.on('headerReceive', (header: Object) => {
        // 连接建立
        this.connected = true
        this.reconnectDelay = 3000
        this.emit('connected', new ServerEvent())
      })

      req.on('dataEnd', () => {
        // 流结束，尝试重连
        this.connected = false
        this.emit('disconnected', new ServerEvent())
        this.scheduleReconnect()
      })

      req.on('error', (err: Object) => {
        this.connected = false
        const errEvent = new ServerEvent()
        errEvent.type = 'error'
        errEvent.properties = { message: String(err) }
        this.emit('error', errEvent)
        this.scheduleReconnect()
      })

      // 使用 requestInStream 接收 SSE 数据
      req.requestInStream(this.url, {
        method: http.RequestMethod.GET,
        header: this.headers,
        connectTimeout: 10000,
        readTimeout: 0, // SSE 不设读超时
        expectDataType: http.HttpDataType.STRING,
      }, (err: Error, data: string) => {
        if (err) {
          this.connected = false
          const errEvent = new ServerEvent()
          errEvent.type = 'error'
          errEvent.properties = { message: err.message }
          this.emit('error', errEvent)
          return
        }
        this.processData(data)
      })
    } catch (e) {
      this.connected = false
      const errEvent = new ServerEvent()
      errEvent.type = 'error'
      errEvent.properties = { message: String(e) }
      this.emit('error', errEvent)
      this.scheduleReconnect()
    }
  }

  /**
   * 处理接收到的 SSE 数据
   */
  private processData(data: string): void {
    this.buffer += data
    // SSE 格式：以双换行分隔事件
    const parts = this.buffer.split('\n\n')
    // 最后一个可能不完整，保留在 buffer
    this.buffer = parts[parts.length - 1]

    for (let i = 0; i < parts.length - 1; i++) {
      const part = parts[i].trim()
      if (!part) continue

      let eventType = 'message'
      let eventData = ''

      const lines = part.split('\n')
      for (const line of lines) {
        if (line.startsWith('event: ')) {
          eventType = line.substring(7).trim()
        } else if (line.startsWith('data: ')) {
          eventData += line.substring(6)
        }
      }

      if (eventData) {
        try {
          const event = JSON.parse(eventData) as ServerEvent
          this.handleEvent(event)
        } catch (e) {
          // 忽略解析错误
        }
      }
    }
  }

  /**
   * 处理解析后的事件
   */
  private handleEvent(event: ServerEvent): void {
    // 忽略心跳
    if (event.type === EventTypes.SERVER_HEARTBEAT) {
      return
    }

    // 按类型分发
    this.emit(event.type, event)

    // 同时分发到通配符
    this.emit('*', event)

    // 按大类分发
    if (event.type.startsWith('session.')) {
      this.emit('session.*', event)
    } else if (event.type.startsWith('permission.')) {
      this.emit('permission.*', event)
    } else if (event.type.startsWith('session.tool.')) {
      this.emit('session.tool.*', event)
    } else if (event.type.startsWith('session.llm.')) {
      this.emit('session.llm.*', event)
    }

    // 实例销毁时断开
    if (event.type === EventTypes.SERVER_INSTANCE_DISPOSED) {
      this.close()
    }
  }

  /**
   * 注册事件监听
   */
  on(eventType: string, callback: EventCallback): void {
    if (!this.listeners.has(eventType)) {
      this.listeners.set(eventType, [])
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
  }

  /**
   * 关闭连接
   */
  close(): void {
    this.connected = false
    this.clearReconnect()
    if (this.request) {
      try {
        this.request.destroy()
      } catch (e) {
        // ignore
      }
      this.request = null
    }
    this.emit('closed', new ServerEvent())
  }

  /**
   * 手动重连
   */
  reconnect(): void {
    this.close()
    this.buffer = ''
    this.doConnect()
  }

  private scheduleReconnect(): void {
    this.clearReconnect()
    this.reconnectTimer = setTimeout(() => {
      this.buffer = ''
      this.doConnect()
    }, this.reconnectDelay)
    // 指数退避
    this.reconnectDelay = Math.min(this.reconnectDelay * 1.5, this.maxReconnectDelay)
  }

  private clearReconnect(): void {
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
  }

  isConnected(): boolean {
    return this.connected
  }
}

/** 事件回调类型 */
export type EventCallback = (event: ServerEvent) => void
