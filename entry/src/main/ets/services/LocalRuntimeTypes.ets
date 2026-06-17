/**
 * RuntimeMode — unified runtime mode enum
 * Replaces the old LocalServerConfig.mode string.
 */
export type RuntimeMode = 'local-embedded' | 'dev-pc' | 'remote';

/**
 * LocalRuntimeConfig — configuration for the embedded local runtime.
 */
export class LocalRuntimeConfig {
  mode: RuntimeMode = 'local-embedded';
  workspace: string = '';
  defaultProviderID: string = '';
  defaultModelID: string = '';
}

/**
 * RuntimeHealth — health check result.
 */
export class RuntimeHealth {
  ok: boolean = false;
  mode: RuntimeMode = 'local-embedded';
  version: string = '0.1.0-local';
  message: string = '';
  uptime: number = 0;
}

/**
 * LocalProviderConfig — provider configuration for local runtime.
 */
export class LocalProviderConfig {
  id: string = '';
  name: string = '';
  enabled: boolean = true;
  protocol: string = 'openai-compatible'; // 'openai-compatible' | 'anthropic' | 'custom'
  baseURL: string = '';
  apiKey: string = '';
  apiKeyEnv: string = '';
  headers: Record<string, string> = {};
  models: LocalModelConfig[] = [];
}

/**
 * LocalModelConfig — model configuration for local runtime.
 */
export class LocalModelConfig {
  id: string = '';
  name: string = '';
  contextLength: number = 128000;
  maxOutputTokens: number = 8192;
  supportsTools: boolean = false;
  supportsReasoning: boolean = false;
  supportsVision: boolean = false;
}

/**
 * LocalSession — session stored locally.
 */
export class LocalSession {
  id: string = '';
  title: string = '';
  workspace: string = '';
  providerID: string = '';
  modelID: string = '';
  agent: string = 'build';
  createdAt: number = 0;
  updatedAt: number = 0;
  messageCount: number = 0;
}

/**
 * LocalMessage — message stored locally.
 */
export class LocalMessage {
  id: string = '';
  sessionID: string = '';
  role: string = 'user'; // 'user' | 'assistant' | 'system' | 'tool' | 'error'
  content: string = '';
  status: string = 'completed'; // 'pending' | 'streaming' | 'completed' | 'error' | 'aborted'
  createdAt: number = 0;
  updatedAt: number = 0;
  error: string = '';
  providerID: string = '';
  modelID: string = '';
  agent: string = ''; // agent name (e.g. 'build', 'plan'); empty for user/system messages
}

/**
 * PromptInput — input for sending a prompt.
 */
export class LocalPromptInput {
  text: string = '';
  model: LocalModelRef = new LocalModelRef();
  agent: string = 'build';
}

/**
 * LocalModelRef — reference to a specific model.
 */
export class LocalModelRef {
  providerID: string = '';
  id: string = '';
  variant: string = '';
}

/**
 * PromptResult — result of sending a prompt.
 */
export class LocalPromptResult {
  ok: boolean = false;
  messageID: string = '';
  error: string = '';
}

/**
 * ProviderList — list of providers with connected status.
 */
export class LocalProviderList {
  all: LocalProviderConfig[] = [];
  connected: string[] = [];
  defaults: Record<string, string> = {};
}

/**
 * RuntimeEvent — events emitted by the local runtime.
 */
export class RuntimeEvent {
  type: string = ''; // 'session.created' | 'message.created' | 'message.updated' | 'message.completed' | 'message.error' | 'provider.updated' | 'runtime.error'
  sessionID: string = '';
  messageID: string = '';
  error: string = '';
  data: Record<string, Object> = {};
}

/**
 * Permission request for tool execution.
 */
export class LocalPermissionRequest {
  id: string = '';
  sessionID: string = '';
  toolName: string = '';
  summary: string = '';
  payload: Record<string, Object> = {};
  status: string = 'pending'; // 'pending' | 'approved' | 'denied' | 'expired'
  createdAt: number = 0;
}
