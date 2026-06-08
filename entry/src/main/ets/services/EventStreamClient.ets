import { ServerEvent, EventTypes, NormalizedMessage, NormalizedPart } from '../models/Event'
import { OpenCodeClient } from './OpenCodeClient'

/**
 * Polling-based event client for ArkTS.
 *
 * Why polling:
 * - ArkTS HTTP/SSE support can vary across devices.
 * - This client provides a stable compatibility path before native SSE is implemented.
 *
 * Important behavior:
 * - Tracks both message IDs and message fingerprints.
 * - Emits SESSION_MESSAGE_UPDATED when a new message appears OR an existing message changes.
 * - Handles OpenCode's in-place message updates, especially tool result/state changes.
 */
export class EventStreamClient {
  private client: OpenCodeClient
  private sessionId: string = ''

  private polling: boolean = false
  private pollingTimer: number = -1
  private pollingInterval: number = 2000

  private seenMessageIds: string[] = []
  private messageFingerprints: Map<string, string> = new Map()
  private seenPermissionIds: string[] = []

  private listeners: Map<string, EventCallback[]> = new Map()

  private initialized: boolean = false
  private pollingMode: string = 'cold_start'
  private consecutiveErrors: number = 0
  private lastActivityTime: number = 0
  private runTimeout: number = 30000
  private llmStartedEmitted: boolean = false

  constructor(client: OpenCodeClient, sessionId: string) {
    this.client = client
    this.sessionId = sessionId
  }

  setSessionId(id: string): void {
    this.sessionId = id
    this.resetSessionTracking()
  }

  private resetSessionTracking(): void {
    this.seenMessageIds = []
    this.messageFingerprints = new Map()
    this.seenPermissionIds = []
    this.initialized = false
    this.pollingMode = 'cold_start'
    this.consecutiveErrors = 0
    this.llmStartedEmitted = false
    this.lastActivityTime = 0
  }

  markActiveRun(): void {
    this.pollingMode = 'active_run'
    this.lastActivityTime = Date.now()
    this.llmStartedEmitted = false
  }

  markIdle(): void {
    this.pollingMode = 'idle'
  }

  setPollingInterval(ms: number): void {
    if (ms < 500) {
      this.pollingInterval = 500
      return
    }
    this.pollingInterval = ms
  }

  getStatus(): string {
    return this.pollingMode
  }

  connect(): void {
    if (this.polling) return
    this.polling = true
    if (this.pollingMode.length === 0) {
      this.pollingMode = 'cold_start'
    }
    this.doPoll()
  }

  close(): void {
    this.polling = false
    if (this.pollingTimer !== -1) {
      clearTimeout(this.pollingTimer)
      this.pollingTimer = -1
    }
    this.emit('closed', new ServerEvent())
  }

  reconnect(): void {
    this.close()
    this.resetSessionTracking()
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

      this.consecutiveErrors = 0

      if (!this.initialized) {
        this.initialized = true
        const connectedEvent = new ServerEvent()
        connectedEvent.type = EventTypes.SERVER_CONNECTED
        this.emit(EventTypes.SERVER_CONNECTED, connectedEvent)
        this.emit('connected', connectedEvent)
      }

      if (this.pollingMode === 'cold_start') {
        this.pollingMode = 'idle'
      }

      const heartbeat = new ServerEvent()
      heartbeat.type = EventTypes.SERVER_HEARTBEAT
      heartbeat.properties['mode'] = this.pollingMode
      this.emit(EventTypes.SERVER_HEARTBEAT, heartbeat)
    } catch (e) {
      this.consecutiveErrors++

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

    if (this.polling) {
      this.pollingTimer = setTimeout((): void => {
        this.doPoll()
      }, this.pollingInterval)
    }
  }

  private async pollMessages(): Promise<void> {
    if (this.sessionId.length === 0) return

    const messages = await this.client.getMessages(this.sessionId)

    if (this.pollingMode === 'cold_start') {
      for (const msg of messages) {
        if (!this.containsString(this.seenMessageIds, msg.id)) {
          this.seenMessageIds.push(msg.id)
        }
        this.messageFingerprints.set(msg.id, this.fingerprintMessage(msg))
      }
      return
    }

    let changedCount: number = 0

    for (const msg of messages) {
      const fp = this.fingerprintMessage(msg)
      const existingFp = this.messageFingerprints.get(msg.id)
      const isNew = !this.containsString(this.seenMessageIds, msg.id)
      const isChanged = existingFp !== undefined && existingFp !== fp

      if (isNew) {
        this.seenMessageIds.push(msg.id)
      }

      if (isNew || isChanged) {
        changedCount++
        this.messageFingerprints.set(msg.id, fp)
        this.emitMessageUpdated(msg, isNew, isChanged)
        this.inferAssistantEvents(msg)
        this.inferToolEvents(msg)
      }
    }

    if (this.pollingMode === 'active_run') {
      if (changedCount > 0) {
        this.lastActivityTime = Date.now()
      } else {
        const elapsed = Date.now() - this.lastActivityTime
        if (elapsed > this.runTimeout) {
          this.emitRunEnded('timeout')
          this.markIdle()
        }
      }
    }
  }

  private fingerprintMessage(msg: NormalizedMessage): string {
    const parts: string[] = []
    for (const part of msg.parts) {
      parts.push(this.fingerprintPart(part))
    }
    return `${msg.id}|${msg.role}|${parts.length}|${parts.join('||')}`
  }

  private fingerprintPart(part: NormalizedPart): string {
    return [
      part.id,
      part.type,
      part.content,
      part.toolName,
      part.toolState,
      part.toolArgs,
      part.toolResult,
      String(part.step)
    ].join('|')
  }

  private emitMessageUpdated(msg: NormalizedMessage, isNew: boolean, isChanged: boolean): void {
    const msgEvent = new ServerEvent()
    msgEvent.id = msg.id
    msgEvent.type = EventTypes.SESSION_MESSAGE_UPDATED
    msgEvent.properties['sessionID'] = this.sessionId
    msgEvent.properties['messageID'] = msg.id
    msgEvent.properties['isNew'] = isNew
    msgEvent.properties['isChanged'] = isChanged
    msgEvent.properties['message'] = msg as Object
    this.emit(EventTypes.SESSION_MESSAGE_UPDATED, msgEvent)
  }

  private inferAssistantEvents(msg: NormalizedMessage): void {
    if (msg.role !== 'assistant') return

    this.lastActivityTime = Date.now()

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

    let text = ''
    for (const part of msg.parts) {
      if (part.type === 'text' || part.type === 'reasoning') {
        text += part.content
      }
    }
    llmEvent.properties['delta'] = text
    this.emit(EventTypes.SESSION_LLM_DELTA, llmEvent)
  }

  private inferToolEvents(msg: NormalizedMessage): void {
    for (const part of msg.parts) {
      if (part.type === 'tool-invocation') {
        const toolEvent = new ServerEvent()
        toolEvent.id = msg.id + '_' + part.id
        toolEvent.type = this.mapToolStateToEventType(part.toolState)
        toolEvent.properties['sessionID'] = this.sessionId
        toolEvent.properties['messageID'] = msg.id
        toolEvent.properties['toolID'] = part.id
        toolEvent.properties['toolName'] = part.toolName
        toolEvent.properties['state'] = part.toolState
        toolEvent.properties['input'] = part.toolArgs
        toolEvent.properties['result'] = part.toolResult
        toolEvent.properties['step'] = part.step
        this.emit(toolEvent.type, toolEvent)
      }
    }
  }

  private mapToolStateToEventType(state: string): string {
    if (state === 'running' || state === 'pending' || state === 'start') {
      return EventTypes.SESSION_TOOL_STARTED
    }
    if (state === 'error' || state === 'failed') {
      return EventTypes.SESSION_TOOL_FAILED
    }
    return EventTypes.SESSION_TOOL_SUCCESS
  }

  private emitRunEnded(reason: string): void {
    const runEndEvent = new ServerEvent()
    runEndEvent.type = EventTypes.SESSION_RUN_ENDED
    runEndEvent.properties['sessionID'] = this.sessionId
    runEndEvent.properties['reason'] = reason
    this.emit(EventTypes.SESSION_RUN_ENDED, runEndEvent)

    const llmEndEvent = new ServerEvent()
    llmEndEvent.type = EventTypes.SESSION_LLM_ENDED
    llmEndEvent.properties['sessionID'] = this.sessionId
    this.emit(EventTypes.SESSION_LLM_ENDED, llmEndEvent)
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

  on(eventType: string, callback: EventCallback): void {
    if (!this.listeners.has(eventType)) {
      const emptyArr: EventCallback[] = []
      this.listeners.set(eventType, emptyArr)
    }
    this.listeners.get(eventType)!.push(callback)
  }

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
        try { cb(event) } catch (e) {}
      }
    }

    const wildcardList = this.listeners.get('*')
    if (wildcardList) {
      for (const cb of wildcardList) {
        try { cb(event) } catch (e) {}
      }
    }
  }
}

export type EventCallback = (event: ServerEvent) => void
