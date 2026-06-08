export class FullRunner {
  id: string = ''
  name: string = ''
  host: string = '127.0.0.1'
  port: number = 4096
  protocol: string = 'http'
  token: string = ''
  status: string = 'disconnected'
  version: string = ''
}

export function runnerBaseUrl(r: FullRunner): string {
  return `${r.protocol}://${r.host}:${r.port}`
}

export class FullHealth {
  ok: boolean = false
  version: string = ''
  error: string = ''
}

export class FullRuntimeConfig {
  mode: string = 'local'
  host: string = '127.0.0.1'
  port: number = 4096
  protocol: string = 'http'
  token: string = ''
  workspace: string = ''
}

export class FullRuntimeState {
  status: string = 'unknown'
  baseUrl: string = 'http://127.0.0.1:4096'
  version: string = ''
  message: string = ''
  command: string = ''
}

export class FullProviderInput {
  providerId: string = ''
  displayName: string = ''
  baseURL: string = ''
  apiKey: string = ''
  models: FullModelInput[] = []
}

export class FullModelInput {
  id: string = ''
  name: string = ''
}

export class FullModelOption {
  providerId: string = ''
  providerName: string = ''
  modelId: string = ''
  modelName: string = ''
  modelRef: string = ''
}

export class FullSession {
  id: string = ''
  title: string = ''
  createdAt: string = ''
}

export class FullMessage {
  id: string = ''
  role: string = ''
  sessionID: string = ''
  parts: FullMessagePart[] = []
}

export class FullMessagePart {
  type: string = ''
  text: string = ''
  tool: string = ''
  callID: string = ''
}

export class FullFileItem {
  path: string = ''
  type: string = ''
}

export class FullFileContent {
  content: string = ''
}

export class FullDiff {
  file: string = ''
  status: string = ''
  additions: number = 0
  deletions: number = 0
  patch: string = ''
}

export class FullPermission {
  id: string = ''
  title: string = ''
}

export class FullLog {
  category: string = ''
  level: string = ''
  message: string = ''
  time: number = Date.now()
}

export class FullAppState {
  activePage: string = 'home'
  runner: FullRunner | null = null
  isConnected: boolean = false
  runtimeConfig: FullRuntimeConfig = new FullRuntimeConfig()
  runtimeState: FullRuntimeState = new FullRuntimeState()
  providers: FullProviderInput[] = []
  models: FullModelOption[] = []
  defaultModel: string = ''
  sessions: FullSession[] = []
  activeSessionId: string = ''
  messages: FullMessage[] = []
  inputText: string = ''
  isSending: boolean = false
  projectName: string = ''
  branchName: string = ''
  files: FullFileItem[] = []
  fileContent: string = ''
  diffs: FullDiff[] = []
  permissions: FullPermission[] = []
  logs: FullLog[] = []
}
