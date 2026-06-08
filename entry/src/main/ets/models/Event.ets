/**
 * SSE 事件模型
 * 基于 OpenCode Server 的事件流格式
 */

/** 基础事件结构 */
export class ServerEvent {
  id: string = ''
  type: string = ''
  properties: Record<string, Object> = {}
}

/** 全局事件包装 */
export class GlobalEvent {
  directory: string = ''
  project: string = ''
  workspace: string = ''
  payload: ServerEvent = new ServerEvent()
}

/** 会话信息 */
export class SessionInfo {
  id: string = ''
  title: string = ''
  projectID: string = ''
  status: string = ''
  modelID: string = ''
  providerID: string = ''
  time: SessionTime = new SessionTime()
  metadata: Record<string, string> = {}
}

export class SessionTime {
  created: string = ''
  updated: string = ''
  archived: string = ''
}

/** 消息部分 (Part) - 消息由多个 Part 组成 */
export class MessagePart {
  id: string = ''
  sessionID: string = ''
  messageID: string = ''
  type: string = '' // 'text' | 'tool-invocation' | 'reasoning' | 'file'
  content: string = ''
  metadata: Record<string, Object> = {}
}

/** 消息 */
export class MessageInfo {
  id: string = ''
  sessionID: string = ''
  role: string = '' // 'user' | 'assistant'
  parts: MessagePart[] = []
  metadata: Record<string, Object> = {}
  time: MessageTime = new MessageTime()
}

export class MessageTime {
  created: string = ''
  updated: string = ''
}

/** 工具调用信息 */
export class ToolInvocation {
  toolCallId: string = ''
  toolName: string = ''
  state: string = '' // 'partial-call' | 'call' | 'result'
  args: Record<string, Object> = {}
  result: string = ''
  step: number = 0
}

/** 权限请求 */
export class PermissionRequest {
  id: string = ''
  sessionID: string = ''
  type: string = '' // 'bash' | 'edit' | 'write' | 'delete'
  title: string = ''
  description: string = ''
  riskLevel: string = '' // 'low' | 'medium' | 'high'
  status: string = '' // 'pending' | 'approved' | 'rejected'
  properties: Record<string, Object> = {}
}

/** 文件 Diff */
export class FileDiff {
  path: string = ''
  status: string = '' // 'added' | 'modified' | 'deleted' | 'renamed'
  additions: number = 0
  deletions: number = 0
  patch: string = ''
  oldPath: string = ''
}

/** Provider 信息 */
export class ProviderInfo {
  id: string = ''
  name: string = ''
  source: string = ''
  status: string = '' // 'connected' | 'disconnected' | 'error'
  models: ModelInfo[] = []
}

export class ModelInfo {
  id: string = ''
  name: string = ''
  family: string = ''
  cost: ModelCost = new ModelCost()
  limit: ModelLimit = new ModelLimit()
}

export class ModelCost {
  input: number = 0
  output: number = 0
  cacheRead: number = 0
  cacheWrite: number = 0
}

export class ModelLimit {
  context: number = 0
  output: number = 0
}

/** Config 信息 */
export class ConfigInfo {
  model: string = ''
  small_model: string = ''
  provider: Record<string, Object> = {}
  permission: Record<string, string> = {}
  server: ServerConfig = new ServerConfig()
}

export class ServerConfig {
  port: number = 4096
  hostname: string = '127.0.0.1'
}

/** 项目信息 */
export class ProjectInfo {
  id: string = ''
  name: string = ''
  path: string = ''
  icon: string = ''
  worktree: string = ''
  time: ProjectTime = new ProjectTime()
}

export class ProjectTime {
  created: string = ''
  updated: string = ''
  initialized: string = ''
}

/** VCS 信息 */
export class VcsInfo {
  branch: string = ''
  commit: string = ''
  remote: string = ''
  clean: boolean = true
}

/** 健康检查结果 */
export class HealthInfo {
  healthy: boolean = false
  version: string = ''
}

/** Agent 信息 */
export class AgentInfo {
  id: string = ''
  name: string = ''
  description: string = ''
  model: string = ''
  permission: Record<string, string> = {}
}

/** 事件类型常量 */
export class EventTypes {
  // Server
  static readonly SERVER_CONNECTED: string = 'server.connected'
  static readonly SERVER_HEARTBEAT: string = 'server.heartbeat'
  static readonly SERVER_INSTANCE_DISPOSED: string = 'server.instance.disposed'

  // Session
  static readonly SESSION_CREATED: string = 'session.created'
  static readonly SESSION_UPDATED: string = 'session.updated'
  static readonly SESSION_DELETED: string = 'session.deleted'
  static readonly SESSION_MESSAGE_UPDATED: string = 'session.message.updated'
  static readonly SESSION_PART_UPDATED: string = 'session.part.updated'
  static readonly SESSION_PROMPTED: string = 'session.prompted'
  static readonly SESSION_RUN_STARTED: string = 'session.run.started'
  static readonly SESSION_RUN_ENDED: string = 'session.run.ended'
  static readonly SESSION_LLM_STARTED: string = 'session.llm.started'
  static readonly SESSION_LLM_ENDED: string = 'session.llm.ended'
  static readonly SESSION_LLM_DELTA: string = 'session.llm.delta'
  static readonly SESSION_TOOL_STARTED: string = 'session.tool.started'
  static readonly SESSION_TOOL_ENDED: string = 'session.tool.ended'
  static readonly SESSION_TOOL_CALLED: string = 'session.tool.called'
  static readonly SESSION_TOOL_SUCCESS: string = 'session.tool.success'
  static readonly SESSION_TOOL_FAILED: string = 'session.tool.failed'
  static readonly SESSION_DIFF: string = 'session.diff'
  static readonly SESSION_ERROR: string = 'session.error'
  static readonly SESSION_IDLE: string = 'session.idle'
  static readonly SESSION_STATUS: string = 'session.status'

  // Permission
  static readonly PERMISSION_ASKED: string = 'permission.asked'
  static readonly PERMISSION_REPLIED: string = 'permission.replied'

  // Auth
  static readonly AUTH_ADDED: string = 'auth.added'
  static readonly AUTH_REMOVED: string = 'auth.removed'
}
