/**
 * V2 Type Definitions
 *
 * v1 已经在 OpenCodeClient.ets 中实现。v2 引入了：
 *  - /snapshot (file history / undo)
 *  - /pty       (in-app terminal)
 *  - /plugin    (plugin manager)
 *  - /session/:id/init
 *  - /session/:id/compact (与 v1 行为不同)
 *  - 增强的 /config /provider
 *
 * 这份文件只放 v2 的类型，不持有任何 HTTP / 副作用逻辑。
 * HTTP 包装在 V2Client.ets。
 */

// ══════════ Snapshot (file history) ══════════

@Observed
export class SnapshotInfo {
  id: string = ''
  messageID: string = ''
  sessionID: string = ''
  createdAt: number = 0       // unix ms
  description: string = ''
  fileCount: number = 0
  files: string[] = []        // 受影响的文件列表
}

@Observed
export class SnapshotDiff {
  file: string = ''
  before: string = ''         // diff before
  after: string = ''          // diff after
  additions: number = 0
  deletions: number = 0
}

// ══════════ PTY (terminal) ══════════

@Observed
export class PtySessionInfo {
  id: string = ''
  title: string = ''
  command: string = ''
  cwd: string = ''
  cols: number = 80
  rows: number = 24
  status: string = 'running'  // 'running' | 'exited'
  exitCode: number = 0
  createdAt: number = 0
}

@Observed
export class PtyChunk {
  sessionID: string = ''
  seq: number = 0
  data: string = ''           // chunk text
  isExit: boolean = false
  exitCode: number = 0
}

// ══════════ Plugin Manager ══════════

@Observed
export class PluginInfo {
  id: string = ''
  name: string = ''
  version: string = ''
  description: string = ''
  author: string = ''
  enabled: boolean = false
  path: string = ''
  scope: string = ''          // 'project' | 'user' | 'global'
  error: string = ''
}

// ══════════ Compaction (v2) ══════════

@Observed
export class CompactResult {
  ok: boolean = false
  compacted: number = 0       // compacted message count
  removedTokens: number = 0
  error: string = ''
}

// ══════════ Agent Info (v2 增强) ══════════

@Observed
export class AgentDetail {
  name: string = ''
  description: string = ''
  mode: string = ''           // 'primary' | 'subagent' | 'all'
  model: string = ''          // 推荐 model id
  prompt: string = ''         // system prompt 摘要
  enabled: boolean = true
  tools: string[] = []        // 工具名列表
  builtIn: boolean = false
}

// ══════════ V2 通用响应包装 ══════════

@Observed
export class V2Response {
  ok: boolean = true
  status: number = 200
  data: Object = new Object()
  raw: string = ''
  error: string = ''
}

/**
 * 服务端不支持 v2 端点时抛出。UI 层捕获后显示 "server not supported" 消息。
 *
 * 修复 S4: 加 readonly kind 字段,作为 instanceof 跨模块导入的可靠替代。
 * ArkTS 的 instanceof 在跨 module 边界时不可靠,用 `e.kind === 'UnsupportedV2Endpoint'`
 * 更稳。保留 extends Error 兼容既有 try/catch。
 */
export class UnsupportedV2Endpoint extends Error {
  readonly kind: string = 'UnsupportedV2Endpoint'
  endpoint: string
  statusCode: number
  constructor(endpoint: string, statusCode: number = 404) {
    super(`v2 endpoint unsupported: ${endpoint} (HTTP ${statusCode})`)
    this.endpoint = endpoint
    this.statusCode = statusCode
    this.name = 'UnsupportedV2Endpoint'
  }
}

/**
 * 类型守卫: e 是否为 UnsupportedV2Endpoint,优先用 kind 字段检测,
 * instanceof 作 fallback (兼容旧调用方)
 */
export function isUnsupportedV2(e: Object): boolean {
  if (e === null || e === undefined) return false
  const obj: Record<string, Object> = e as Record<string, Object>
  if (obj['kind'] === 'UnsupportedV2Endpoint') return true
  if (e instanceof UnsupportedV2Endpoint) return true
  return false
}
