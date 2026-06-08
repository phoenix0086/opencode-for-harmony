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
