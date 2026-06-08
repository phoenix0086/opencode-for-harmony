/**
 * OpenCode Server 数据模型
 * 严格对齐 OpenCode v1.16.2 HTTP API
 */

// ══════════ Server Event ══════════

export class ServerEvent {
  id: string = ''
  type: string = ''
  properties: Record<string, Object> = {}
}

export class GlobalEvent {
  directory: string = ''
  project: string = ''
  workspace: string = ''
  payload: ServerEvent = new ServerEvent()
}

// ══════════ Session ══════════

export class SessionInfo {
  id: string = ''
  slug: string = ''
  title: string = ''
  projectID: string = ''
  workspaceID: string = ''
  directory: string = ''
  agent: string = ''
  version: string = ''
  cost: number = 0
  model: SessionModel = new SessionModel()
  time: SessionTime = new SessionTime()
  metadata: Record<string, Object> = {}
}

export class SessionModel {
  providerID: string = ''
  modelID: string = ''
}

export class SessionTime {
  created: number = 0
  updated: number = 0
}

// ══════════ Message (WithParts) ══════════

/**
 * Raw API response for GET /session/:id/message
 * Each item is a WithParts: { info, parts }
 */
export class WithParts {
  info: MessageInfo = new MessageInfo()
  parts: RawPart[] = []
}

export class MessageInfo {
  id: string = ''
  role: string = ''
  sessionID: string = ''
  agent: string = ''
  time: MessageTime = new MessageTime()
}

export class MessageTime {
  created: number = 0
}

/**
 * Raw Part from API — shape varies by type.
 * text: { type:"text", text:"..." }
 * tool-invocation: { type:"tool-invocation", toolInvocationId:"...", toolName:"...", state:"...", args:{...}, result:"..." }
 */
export class RawPart {
  type: string = ''
  text: string = ''
  toolInvocationId: string = ''
  toolName: string = ''
  state: string = ''
  args: Record<string, Object> = {}
  result: string = ''
  step: number = 0
}

// ══════════ Normalized Message (for UI) ══════════

export class NormalizedMessage {
  id: string = ''
  role: string = ''
  sessionID: string = ''
  parts: NormalizedPart[] = []
}

export class NormalizedPart {
  id: string = ''
  type: string = ''
  content: string = ''
  toolName: string = ''
  toolState: string = ''
  toolArgs: string = ''
  toolResult: string = ''
  step: number = 0
}

// ══════════ Permission ══════════

export class PermissionRequest {
  id: string = ''
  sessionID: string = ''
  type: string = ''
  title: string = ''
  description: string = ''
  riskLevel: string = ''
  status: string = ''
  properties: Record<string, Object> = {}
}

// ══════════ File Diff ══════════

export class FileDiff {
  file: string = ''
  patch: string = ''
  additions: number = 0
  deletions: number = 0
  status: string = ''
}

// ══════════ Provider ══════════

export class ProviderListResult {
  all: ProviderPublicInfo[] = []
  connected: string[] = []
  defaults: Record<string, string> = {}
}

export class ProviderPublicInfo {
  id: string = ''
  name: string = ''
  source: string = ''
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

// ══════════ VCS ══════════

export class VcsInfo {
  branch: string = ''
  defaultBranch: string = ''
}

export class VcsFileStatus {
  file: string = ''
  additions: number = 0
  deletions: number = 0
  status: string = ''
}

// ══════════ Health ══════════

export class HealthInfo {
  healthy: boolean = false
  version: string = ''
}

// ══════════ Config ══════════

export class ConfigInfo {
  model: string = ''
  smallModel: string = ''
  provider: Record<string, Object> = {}
  permission: Record<string, string> = {}
}

// ══════════ Project ══════════

export class ProjectInfo {
  id: string = ''
  name: string = ''
  worktree: string = ''
}

// ══════════ Agent ══════════

export class AgentInfo {
  id: string = ''
  name: string = ''
  description: string = ''
}

// ══════════ File Node ══════════

export class FileNode {
  name: string = ''
  path: string = ''
  absolute: string = ''
  type: string = ''
  ignored: boolean = false
}

// ══════════ Path Info ══════════

export class PathInfo {
  home: string = ''
  state: string = ''
  config: string = ''
  worktree: string = ''
  directory: string = ''
}

// ══════════ Log Entry ══════════

export class LogEntry {
  timestamp: string = ''
  level: string = ''
  source: string = ''
  message: string = ''
}

// ══════════ Event Type Constants ══════════

export class EventTypes {
  // Server
  static readonly SERVER_CONNECTED: string = 'server.connected'
  static readonly SERVER_HEARTBEAT: string = 'server.heartbeat'
  static readonly SERVER_INSTANCE_DISPOSED: string = 'server.instance.disposed'

  // Session lifecycle
  static readonly SESSION_CREATED: string = 'session.created'
  static readonly SESSION_UPDATED: string = 'session.updated'
  static readonly SESSION_DELETED: string = 'session.deleted'

  // Messages
  static readonly SESSION_MESSAGE_UPDATED: string = 'session.message.updated'
  static readonly SESSION_PART_UPDATED: string = 'session.part.updated'
  static readonly SESSION_PROMPTED: string = 'session.prompted'

  // Run (agent execution)
  static readonly SESSION_RUN_STARTED: string = 'session.run.started'
  static readonly SESSION_RUN_ENDED: string = 'session.run.ended'

  // LLM
  static readonly SESSION_LLM_STARTED: string = 'session.llm.started'
  static readonly SESSION_LLM_ENDED: string = 'session.llm.ended'
  static readonly SESSION_LLM_DELTA: string = 'session.llm.delta'

  // Tool
  static readonly SESSION_TOOL_STARTED: string = 'session.tool.started'
  static readonly SESSION_TOOL_ENDED: string = 'session.tool.ended'
  static readonly SESSION_TOOL_SUCCESS: string = 'session.tool.success'
  static readonly SESSION_TOOL_FAILED: string = 'session.tool.failed'

  // Diff
  static readonly SESSION_DIFF: string = 'session.diff'

  // Error / Status
  static readonly SESSION_ERROR: string = 'session.error'
  static readonly SESSION_STATUS: string = 'session.status'

  // Permission
  static readonly PERMISSION_ASKED: string = 'permission.asked'
  static readonly PERMISSION_REPLIED: string = 'permission.replied'

  // Auth
  static readonly AUTH_ADDED: string = 'auth.added'
  static readonly AUTH_REMOVED: string = 'auth.removed'
}
