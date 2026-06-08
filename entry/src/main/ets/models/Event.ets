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
export const EventTypes = {
  // Server
  SERVER_CONNECTED: 'server.connected',
  SERVER_HEARTBEAT: 'server.heartbeat',
  SERVER_INSTANCE_DISPOSED: 'server.instance.disposed',

  // Session
  SESSION_CREATED: 'session.created',
  SESSION_UPDATED: 'session.updated',
  SESSION_DELETED: 'session.deleted',
  SESSION_MESSAGE_UPDATED: 'session.message.updated',
  SESSION_PART_UPDATED: 'session.part.updated',
  SESSION_PROMPTED: 'session.prompted',
  SESSION_RUN_STARTED: 'session.run.started',
  SESSION_RUN_ENDED: 'session.run.ended',
  SESSION_LLM_STARTED: 'session.llm.started',
  SESSION_LLM_ENDED: 'session.llm.ended',
  SESSION_LLM_DELTA: 'session.llm.delta',
  SESSION_TOOL_STARTED: 'session.tool.started',
  SESSION_TOOL_ENDED: 'session.tool.ended',
  SESSION_TOOL_CALLED: 'session.tool.called',
  SESSION_TOOL_SUCCESS: 'session.tool.success',
  SESSION_TOOL_FAILED: 'session.tool.failed',
  SESSION_DIFF: 'session.diff',
  SESSION_ERROR: 'session.error',
  SESSION_IDLE: 'session.idle',
  SESSION_STATUS: 'session.status',

  // Permission
  PERMISSION_ASKED: 'permission.asked',
  PERMISSION_REPLIED: 'permission.replied',

  // Auth
  AUTH_ADDED: 'auth.added',
  AUTH_REMOVED: 'auth.removed',
}
