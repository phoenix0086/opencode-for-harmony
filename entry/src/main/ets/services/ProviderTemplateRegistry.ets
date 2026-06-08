import { CNModel, CNProvider } from '../models/Provider'

export class ProviderModelTemplate {
  id: string = ''
  name: string = ''
  coding: boolean = true
  recommended: boolean = false
}

export class ProviderTemplate {
  id: string = ''
  name: string = ''
  description: string = ''
  baseURL: string = ''
  authEnv: string = ''
  models: ProviderModelTemplate[] = []
}

function model(id: string, name: string, coding: boolean = true, recommended: boolean = false): ProviderModelTemplate {
  const m = new ProviderModelTemplate()
  m.id = id
  m.name = name
  m.coding = coding
  m.recommended = recommended
  return m
}

function template(id: string, name: string, description: string, baseURL: string, authEnv: string, models: ProviderModelTemplate[]): ProviderTemplate {
  const t = new ProviderTemplate()
  t.id = id
  t.name = name
  t.description = description
  t.baseURL = baseURL
  t.authEnv = authEnv
  t.models = models
  return t
}

export class ProviderTemplateRegistry {
  listTemplates(): ProviderTemplate[] {
    const list: ProviderTemplate[] = []

    list.push(template('deepseek-cn', 'DeepSeek', 'DeepSeek OpenAI-compatible API provider.', 'https://api.deepseek.com', 'DEEPSEEK_API_KEY', [
      model('deepseek-chat', 'DeepSeek Chat', true, true),
      model('deepseek-reasoner', 'DeepSeek Reasoner', true, false)
    ]))

    list.push(template('qwen-cn', '通义千问 / 阿里百炼', 'DashScope OpenAI-compatible endpoint.', 'https://dashscope.aliyuncs.com/compatible-mode/v1', 'DASHSCOPE_API_KEY', [
      model('qwen3-coder-plus', 'Qwen3 Coder Plus', true, true),
      model('qwen-plus', 'Qwen Plus', true, false),
      model('qwen-max', 'Qwen Max', false, false)
    ]))

    list.push(template('glm-cn', '智谱 GLM', 'BigModel OpenAI-compatible endpoint.', 'https://open.bigmodel.cn/api/paas/v4', 'BIGMODEL_API_KEY', [
      model('glm-4.5', 'GLM-4.5', true, true),
      model('glm-4.5-air', 'GLM-4.5 Air', true, false)
    ]))

    list.push(template('kimi-cn', 'Kimi / Moonshot', 'Moonshot OpenAI-compatible endpoint.', 'https://api.moonshot.cn/v1', 'MOONSHOT_API_KEY', [
      model('kimi-k2', 'Kimi K2', true, true)
    ]))

    list.push(template('minimax-cn', 'MiniMax', 'MiniMax OpenAI-compatible endpoint.', 'https://api.minimax.chat/v1', 'MINIMAX_API_KEY', [
      model('MiniMax-M2', 'MiniMax M2', true, true)
    ]))

    list.push(template('siliconflow-cn', 'SiliconFlow', 'SiliconFlow OpenAI-compatible aggregation endpoint.', 'https://api.siliconflow.cn/v1', 'SILICONFLOW_API_KEY', [
      model('Qwen/Qwen3-Coder-480B-A35B-Instruct', 'Qwen3 Coder 480B', true, true),
      model('deepseek-ai/DeepSeek-V3', 'DeepSeek V3', true, false)
    ]))

    list.push(template('custom-openai-compatible', '自定义提供商', '通过基础 URL 添加与 OpenAI 兼容的提供商。', '', 'CUSTOM_API_KEY', []))

    return list
  }

  getTemplate(id: string): ProviderTemplate | null {
    const list = this.listTemplates()
    for (const item of list) {
      if (item.id === id) return item
    }
    return null
  }

  toProvider(t: ProviderTemplate): CNProvider {
    const p = new CNProvider()
    p.id = t.id
    p.name = t.name
    p.baseURL = t.baseURL
    p.authEnv = t.authEnv
    p.apiKeyRef = t.authEnv
    p.npm = '@ai-sdk/openai-compatible'
    p.enabled = true
    p.builtIn = t.id !== 'custom-openai-compatible'
    p.authStatus = 'missing'

    for (const tm of t.models) {
      const m = new CNModel()
      m.id = tm.id
      m.name = tm.name
      m.coding = tm.coding
      m.recommended = tm.recommended
      m.enabled = true
      p.models.push(m)
    }

    return p
  }
}

export const providerTemplateRegistry = new ProviderTemplateRegistry()
