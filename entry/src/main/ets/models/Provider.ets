/**
 * OpenCode Provider / Model data model for Harmony Native.
 *
 * This file replaces the old shallow CN provider model with a model that can
 * store OpenAI-compatible Base URL, API Key mode, request headers, custom
 * models, model enablement, and default model selection.
 */

export class CNModel {
  id: string = ''
  name: string = ''
  coding: boolean = false
  contextWindow: number = 0
  maxOutput: number = 0
  recommended: boolean = false
  enabled: boolean = true
}

export class ProviderHeader {
  name: string = ''
  value: string = ''
}

export class CNProvider {
  id: string = ''
  name: string = ''
  npm: string = '@ai-sdk/openai-compatible'
  baseURL: string = ''
  authEnv: string = ''
  authMode: string = 'apiKey'      // 'apiKey' | 'header' | 'none'
  apiKeyMode: string = 'direct'    // 'direct' | 'env'
  apiKey: string = ''
  apiKeyRef: string = ''
  headers: ProviderHeader[] = []
  models: CNModel[] = []
  enabled: boolean = false
  builtIn: boolean = true
  authStatus: string = 'missing' // 'missing' | 'configured' | 'invalid'
  notes: string = ''
}

export class ProviderConfigState {
  providerId: string = ''
  hasApiKey: boolean = false
  selectedModel: string = ''
  selectedSmallModel: string = ''
  customBaseURL: string = ''
}

export class ProviderEditDraft {
  id: string = ''
  name: string = ''
  npm: string = '@ai-sdk/openai-compatible'
  baseURL: string = ''
  authEnv: string = ''
  authMode: string = 'apiKey'
  apiKeyMode: string = 'direct'
  apiKey: string = ''
  headerName: string = ''
  headerValue: string = ''
  modelId: string = ''
  modelName: string = ''
}

export class ProviderGenerateInput {
  providerId: string = ''
  baseURL: string = ''
  models: string[] = []
  defaultModel: string = ''
  smallModel: string = ''
  authEnvVar: string = ''
}

export class OpenCodeConfig {
  server_port: number = 4096
  server_hostname: string = '127.0.0.1'
  permission_bash: string = 'ask'
  permission_edit: string = 'ask'
  permission_write: string = 'ask'
  permission_webfetch: string = 'allow'
  model: string = ''
  small_model: string = ''
  autoupdate: boolean = false
  snapshot: boolean = true
  providers: string = '{}'
}

function model(id: string, name: string, coding: boolean, recommended: boolean = false, contextWindow: number = 0, maxOutput: number = 0): CNModel {
  const m = new CNModel()
  m.id = id
  m.name = name
  m.coding = coding
  m.recommended = recommended
  m.contextWindow = contextWindow
  m.maxOutput = maxOutput
  return m
}

function provider(id: string, name: string, baseURL: string, authEnv: string, models: CNModel[]): CNProvider {
  const p = new CNProvider()
  p.id = id
  p.name = name
  p.baseURL = baseURL
  p.authEnv = authEnv
  p.apiKeyRef = authEnv
  p.models = models
  return p
}

/** Create default OpenAI-compatible Provider Pack. */
export function createDefaultProviders(): CNProvider[] {
  const mimo = new CNProvider()
  mimo.id = 'xiaomi-mimo'
  mimo.name = 'Xiaomi MiMo'
  mimo.baseURL = 'https://token-plan-cn.xiaomimimo.com/anthropic'
  mimo.apiKey = 'tp-ctyx27ynv0rkbtljod87kkt779afid0eqrcmu68kst5zr13o'
  mimo.apiKeyMode = 'direct'
  mimo.authEnv = 'XIAOMI_MIMO_API_KEY'
  mimo.apiKeyRef = 'XIAOMI_MIMO_API_KEY'
  mimo.enabled = true
  mimo.builtIn = false
  mimo.authStatus = 'configured'
  return [mimo]
}
