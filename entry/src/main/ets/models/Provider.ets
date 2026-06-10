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

/** Create default OpenAI-compatible Provider Pack (9 CN providers). */
export function createDefaultProviders(): CNProvider[] {
  // ── Xiaomi MiMo (Anthropic-compatible) ──
  const mimo = new CNProvider()
  mimo.id = 'xiaomi-mimo'
  mimo.name = 'Xiaomi MiMo'
  mimo.npm = '@ai-sdk/anthropic'
  mimo.baseURL = 'https://token-plan-cn.xiaomimimo.com/anthropic'
  mimo.apiKey = 'tp-ctgx27ynv0rkbt1jod87kkt779afid0eqrcmu68kst5zr13o'
  mimo.apiKeyMode = 'direct'
  mimo.authEnv = 'ANTHROPIC_AUTH_TOKEN'
  mimo.apiKeyRef = 'ANTHROPIC_AUTH_TOKEN'
  mimo.enabled = true
  mimo.builtIn = false
  mimo.authStatus = 'configured'
  mimo.models = [
    model('mimo-v2.5-pro', 'MiMo v2.5 Pro', true, true, 1000000, 16384),
    model('mimo-v2.5', 'MiMo v2.5', true, false, 1000000, 16384),
    model('mimo-v2.5-pro[1M]', 'MiMo v2.5 Pro [1M]', true, false, 1000000, 16384),
  ]

  return [
    mimo,
    provider('deepseek', 'DeepSeek', 'https://api.deepseek.com', 'DEEPSEEK_API_KEY', [
      model('deepseek-chat', 'DeepSeek Chat', true, true, 65536, 8192),
      model('deepseek-coder', 'DeepSeek Coder', true, false, 65536, 8192),
      model('deepseek-reasoner', 'DeepSeek Reasoner', true, false, 65536, 8192),
    ]),
    provider('dashscope', '通义千问 / 阿里百炼', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'DASHSCOPE_API_KEY', [
      model('qwen-coder-plus', 'Qwen Coder Plus', true, true, 131072, 16384),
      model('qwen-plus', 'Qwen Plus', true, false, 131072, 16384),
      model('qwen-turbo', 'Qwen Turbo', true, false, 131072, 8192),
    ]),
    provider('bigmodel', '智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'BIGMODEL_API_KEY', [
      model('glm-4-plus', 'GLM-4 Plus', true, true, 128000, 4096),
      model('glm-4-flash', 'GLM-4 Flash', true, false, 128000, 4096),
      model('codegeex-4', 'CodeGeeX-4', true, false, 128000, 4096),
    ]),
    provider('moonshot', 'Kimi / Moonshot', 'https://api.moonshot.cn/v1', 'MOONSHOT_API_KEY', [
      model('moonshot-v1-128k', 'Moonshot v1 128K', true, true, 131072, 8192),
      model('moonshot-v1-32k', 'Moonshot v1 32K', true, false, 32768, 8192),
    ]),
    provider('minimax', 'MiniMax', 'https://api.minimax.chat/v1', 'MINIMAX_API_KEY', [
      model('MiniMax-Text-01', 'MiniMax Text 01', true, true, 1000000, 8192),
    ]),
    provider('volcengine', '火山方舟', 'https://ark.cn-beijing.volces.com/api/v3', 'VOLCENGINE_API_KEY', [
      model('doubao-pro-256k', '豆包 Pro 256K', true, true, 262144, 4096),
      model('doubao-lite-128k', '豆包 Lite 128K', true, false, 131072, 4096),
    ]),
    provider('qianfan', '百度千帆', 'https://qianfan.baidubce.com/v2', 'QIANFAN_API_KEY', [
      model('ernie-4.0-turbo-8k', 'ERNIE 4.0 Turbo', true, true, 8192, 4096),
      model('ernie-3.5-8k', 'ERNIE 3.5', true, false, 8192, 4096),
    ]),
    provider('siliconflow', 'SiliconFlow', 'https://api.siliconflow.cn/v1', 'SILICONFLOW_API_KEY', [
      model('deepseek-ai/DeepSeek-V3', 'DeepSeek V3 (SF)', true, true, 65536, 8192),
      model('Qwen/Qwen2.5-Coder-32B-Instruct', 'Qwen2.5 Coder 32B', true, false, 32768, 8192),
    ]),
    provider('custom', '自定义 OpenAI Compatible', '', 'CUSTOM_API_KEY', []),
  ]
}
