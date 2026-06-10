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

/** Create default providers — only Xiaomi MiMo. */
export function createDefaultProviders(): CNProvider[] {
  const mimo = new CNProvider()
  mimo.id = 'xiaomi-mimo'
  mimo.name = 'Xiaomi MiMo'
  // 小米 MiMo 实测只支持 OpenAI 兼容端点 (curl 验证 /v1/models → 401 端点存在,
  // /v1/messages → 404 不支持 Anthropic 协议)
  mimo.npm = '@ai-sdk/openai-compatible'
  mimo.baseURL = 'https://token-plan-cn.xiaomimimo.com/v1'
  mimo.apiKey = ''
  mimo.apiKeyMode = 'direct'
  mimo.authEnv = 'OPENAI_API_KEY'
  mimo.apiKeyRef = 'OPENAI_API_KEY'
  mimo.enabled = true
  mimo.builtIn = false
  mimo.authStatus = 'missing'
  mimo.models = [
    model('mimo-v2.5-pro', 'MiMo v2.5 Pro', true, true, 1000000, 16384),
    model('mimo-v2.5', 'MiMo v2.5', true, false, 1000000, 16384),
    model('mimo-v2.5-pro[1M]', 'MiMo v2.5 Pro [1M]', true, false, 1000000, 16384),
  ]

  return [mimo]
}
