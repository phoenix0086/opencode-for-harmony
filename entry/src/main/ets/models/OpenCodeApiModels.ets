/**
 * OpenCodeApiSchema.ets — Unified types and normalize functions
 * All API responses are normalized to these types before reaching UI.
 */

// ══════════ Unified Session ══════════

export class UnifiedSession {
  id: string = ''
  title: string = ''
  agent: string = ''
  model: string = ''
  providerID: string = ''
  directory: string = ''
  createdAt: number = 0
  updatedAt: number = 0
  messageCount: number = 0
  tokens: UnifiedTokens = new UnifiedTokens()
}

export class UnifiedTokens {
  input: number = 0
  output: number = 0
  reasoning: number = 0
}

// ══════════ Unified Message ══════════

export class UnifiedMessage {
  id: string = ''
  sessionID: string = ''
  role: string = '' // 'user' | 'assistant' | 'system'
  agent: string = ''
  model: string = ''
  parts: UnifiedPart[] = []
  createdAt: number = 0
}

export class UnifiedPart {
  type: string = '' // 'text' | 'tool' | 'reasoning' | 'step-start' | 'step-finish' | 'todo' | 'error' | 'permission'
  id: string = ''
  text: string = ''
  toolName: string = ''
  toolCallID: string = ''
  toolState: string = ''
  toolInput: string = ''
  toolOutput: string = []
  todos: UnifiedTodo[] = []
}

export class UnifiedTodo {
  id: string = ''
  content: string = ''
  status: string = '' // 'pending' | 'in_progress' | 'completed' | 'cancelled'
  priority: string = ''
}

// ══════════ Unified Provider ══════════

export class UnifiedProvider {
  id: string = ''
  name: string = ''
  connected: boolean = false
  models: UnifiedModel[] = []
}

export class UnifiedModel {
  id: string = ''
  name: string = ''
  providerID: string = ''
  context: number = 0
  output: number = 0
  inputCost: number = 0
  outputCost: number = 0
  toolcall: boolean = false
  reasoning: boolean = false
  attachment: boolean = false
  status: string = '' // 'active' | 'deprecated' | 'unknown'
}

// ══════════ Unified Permission ══════════

export class UnifiedPermissionRequest {
  id: string = ''
  sessionID: string = ''
  type: string = ''
  title: string = ''
  description: string = ''
  riskLevel: string = ''
  status: string = ''
}

// ══════════ Unified Question ══════════

export class UnifiedQuestion {
  id: string = ''
  sessionID: string = ''
  header: string = ''
  question: string = ''
  options: UnifiedQuestionOption[] = []
  multiSelect: boolean = false
  status: string = ''
}

export class UnifiedQuestionOption {
  id: string = ''
  label: string = ''
  description: string = ''
}

// ══════════ Run State ══════════

export enum SessionRunState {
  Idle = 'idle',
  Admitting = 'admitting',
  Running = 'running',
  WaitingPermission = 'waiting_permission',
  WaitingQuestion = 'waiting_question',
  Completed = 'completed',
  Aborted = 'aborted',
  Error = 'error'
}

// ══════════ Normalize Functions ══════════

export function normalizeSession(raw: Record<string, Object>): UnifiedSession {
  const s = new UnifiedSession()
  s.id = (raw['id'] as string) || ''
  s.title = (raw['title'] as string) || ''
  s.agent = (raw['agent'] as string) || ''
  s.directory = (raw['directory'] as string) || ''

  const model = raw['model'] as Record<string, Object> | undefined
  if (model) {
    s.model = (model['id'] as string) || ''
    s.providerID = (model['providerID'] as string) || (model['provider_id'] as string) || ''
  }

  const time = raw['time'] as Record<string, Object> | undefined
  if (time) {
    s.createdAt = (time['created'] as number) || 0
    s.updatedAt = (time['updated'] as number) || 0
  }

  const tokens = raw['tokens'] as Record<string, Object> | undefined
  if (tokens) {
    s.tokens.input = (tokens['input'] as number) || 0
    s.tokens.output = (tokens['output'] as number) || 0
    s.tokens.reasoning = (tokens['reasoning'] as number) || 0
  }

  s.messageCount = (raw['messageCount'] as number) || 0

  return s
}

export function normalizeMessage(raw: Record<string, Object>): UnifiedMessage {
  const m = new UnifiedMessage()
  const info = raw['info'] as Record<string, Object> | undefined
  if (info) {
    m.id = (info['id'] as string) || ''
    m.role = (info['role'] as string) || ''
    m.sessionID = (info['sessionID'] as string) || ''
    m.agent = (info['agent'] as string) || ''
    const modelInfo = info['model'] as Record<string, Object> | undefined
    if (modelInfo) m.model = (modelInfo['id'] as string) || ''
    const time = info['time'] as Record<string, Object> | undefined
    if (time) m.createdAt = (time['created'] as number) || 0
  }
  // Fallback: item-level role
  if (m.role.length === 0) m.role = (raw['role'] as string) || ''

  const parts = raw['parts'] as Object[] | undefined
  if (parts) {
    for (const p of parts) {
      m.parts.push(normalizePart(p as Record<string, Object>))
    }
  }

  return m
}

function normalizePart(raw: Record<string, Object>): UnifiedPart {
  const p = new UnifiedPart()
  p.type = (raw['type'] as string) || ''
  p.id = (raw['id'] as string) || ''
  p.text = extractPartText(raw)

  if (p.type === 'tool' || p.type === 'tool-invocation' || p.type === 'tool-call') {
    p.toolName = (raw['tool'] as string) || (raw['name'] as string) || ''
    p.toolCallID = (raw['callID'] as string) || (raw['id'] as string) || ''
    const state = raw['state'] as Record<string, Object> | undefined
    if (state) {
      p.toolState = (state['status'] as string) || ''
      p.toolInput = JSON.stringify(state['input'] ?? '')
      const output = state['output']
      if (typeof output === 'string') p.toolOutput = output
    }
  }

  if (p.type === 'todo') {
    const todos = (raw['state'] as Record<string, Object>)?.['todos']
    if (Array.isArray(todos)) {
      for (const t of todos) {
        const todo = t as Record<string, Object>
        p.todos.push({
          id: (todo['id'] as string) || '',
          content: (todo['content'] as string) || (todo['text'] as string) || '',
          status: ((todo['status'] as string) || 'pending').toLowerCase(),
          priority: ((todo['priority'] as string) || '').toLowerCase()
        })
      }
    }
  }

  return p
}

function extractPartText(part: Record<string, Object>): string {
  const keys = ['text', 'content', 'message', 'error', 'output', 'result']
  for (const key of keys) {
    const value = part[key]
    if (typeof value === 'string' && value.length > 0) return value
  }
  const state = part['state'] as Record<string, Object> | undefined
  if (state) {
    for (const key of keys) {
      const value = state[key]
      if (typeof value === 'string' && value.length > 0) return value
    }
  }
  return ''
}

export function normalizeProvider(raw: Record<string, Object>, connectedIds: string[]): UnifiedProvider {
  const p = new UnifiedProvider()
  p.id = (raw['id'] as string) || ''
  p.name = (raw['name'] as string) || p.id
  p.connected = connectedIds.includes(p.id)

  const models = raw['models']
  if (Array.isArray(models)) {
    for (const m of models) {
      if (typeof m === 'string') {
        const model = new UnifiedModel()
        model.id = m
        model.providerID = p.id
        p.models.push(model)
      } else if (m && typeof m === 'object') {
        p.models.push(normalizeModel(m as Record<string, Object>, p.id))
      }
    }
  } else if (models && typeof models === 'object') {
    const map = models as Record<string, Object>
    for (const id of Object.keys(map)) {
      p.models.push(normalizeModel(map[id] as Record<string, Object>, p.id))
    }
  }

  return p
}

function normalizeModel(raw: Record<string, Object>, providerID: string): UnifiedModel {
  const m = new UnifiedModel()
  m.id = (raw['id'] as string) || ''
  m.name = (raw['name'] as string) || m.id
  m.providerID = providerID
  m.status = (raw['status'] as string) || 'active'

  const caps = raw['capabilities'] as Record<string, Object> | undefined
  if (caps) {
    m.toolcall = caps['toolcall'] === true
    m.reasoning = caps['reasoning'] === true
    m.attachment = caps['attachment'] === true
  }

  const limit = raw['limit'] as Record<string, Object> | undefined
  if (limit) {
    m.context = (limit['context'] as number) || 0
    m.output = (limit['output'] as number) || 0
  }

  const cost = raw['cost'] as Record<string, Object> | undefined
  if (cost) {
    m.inputCost = (cost['input'] as number) || 0
    m.outputCost = (cost['output'] as number) || 0
  }

  return m
}
