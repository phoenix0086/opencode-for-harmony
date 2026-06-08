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
  const providers: CNProvider[] = []

  providers.push(provider('deepseek-cn', 'DeepSeek', 'https://api.deepseek.com', 'DEEPSEEK_API_KEY', [
    model('deepseek-chat', 'DeepSeek Chat', true, true),
    model('deepseek-reasoner', 'DeepSeek Reasoner', true),
  ]))

  providers.push(provider('qwen-cn', '通义千问 / 阿里百炼', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'DASHSCOPE_API_KEY', [
    model('qwen3-coder-plus', 'Qwen3 Coder Plus', true, true),
    model('qwen-plus', 'Qwen Plus', false),
    model('qwen-max', 'Qwen Max', false),
  ]))

  providers.push(provider('glm-cn', '智谱 GLM / BigModel', 'https://open.bigmodel.cn/api/paas/v4', 'BIGMODEL_API_KEY', [
    model('glm-4.5', 'GLM-4.5', true, true),
    model('glm-4.5-air', 'GLM-4.5 Air', true),
  ]))

  providers.push(provider('kimi-cn', 'Kimi / Moonshot', 'https://api.moonshot.cn/v1', 'MOONSHOT_API_KEY', [
    model('kimi-k2', 'Kimi K2', true, true),
  ]))

  providers.push(provider('minimax-cn', 'MiniMax', 'https://api.minimax.chat/v1', 'MINIMAX_API_KEY', [
    model('MiniMax-M2', 'MiniMax M2', true, true),
  ]))

  providers.push(provider('volcengine-cn', '火山方舟 / Volcengine Ark', 'https://ark.cn-beijing.volces.com/api/v3', 'VOLCENGINE_API_KEY', [
    model('doubao-seed-1-6', 'Doubao Seed 1.6', true, true),
  ]))

  providers.push(provider('baidu-qianfan-cn', '百度千帆', 'https://qianfan.baidubce.com/v2', 'QIANFAN_API_KEY', [
    model('ernie-4.5-turbo-128k', 'ERNIE 4.5 Turbo 128K', true, true),
  ]))

  providers.push(provider('siliconflow-cn', 'SiliconFlow', 'https://api.siliconflow.cn/v1', 'SILICONFLOW_API_KEY', [
    model('Qwen/Qwen3-Coder-480B-A35B-Instruct', 'Qwen3 Coder 480B', true, true),
    model('deepseek-ai/DeepSeek-V3', 'DeepSeek V3', true),
  ]))

  const custom = provider('custom-openai-compatible', '自定义 OpenAI Compatible', '', 'CUSTOM_API_KEY', [])
  custom.builtIn = false
  custom.enabled = false
  providers.push(custom)

  return providers
}
