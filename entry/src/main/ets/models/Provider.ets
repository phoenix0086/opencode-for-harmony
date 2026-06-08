/**
 * CN Provider 数据模型
 * 国内大模型供应商注册表和配置模型
 */

/** 单个模型定义 */
export class CNModel {
  id: string = ''
  name: string = ''
  coding: boolean = false
  contextWindow: number = 0
  maxOutput: number = 0
  recommended: boolean = false
}

/** 供应商定义 */
export class CNProvider {
  id: string = ''
  name: string = ''
  npm: string = '@ai-sdk/openai-compatible'
  baseURL: string = ''
  authEnv: string = ''
  models: CNModel[] = []
  enabled: boolean = false
  authStatus: string = 'missing' // 'missing' | 'configured' | 'invalid'
  apiKeyRef: string = '' // 引用环境变量名，不存储实际 key
}

/** Provider 配置状态 */
export class ProviderConfigState {
  providerId: string = ''
  hasApiKey: boolean = false
  selectedModel: string = ''
  selectedSmallModel: string = ''
  customBaseURL: string = ''
}

/** 生成 opencode.json provider 片段的输入 */
export class ProviderGenerateInput {
  providerId: string = ''
  baseURL: string = ''
  models: string[] = []
  defaultModel: string = ''
  smallModel: string = ''
  authEnvVar: string = ''
}

/** opencode.json 完整配置结构 */
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
  providers: string = '{}' // JSON string of provider map
}

/** 创建默认 CN Provider 列表 */
export function createDefaultProviders(): CNProvider[] {
  const providers: CNProvider[] = []

  // DeepSeek
  const deepseek = new CNProvider()
  deepseek.id = 'deepseek-cn'
  deepseek.name = 'DeepSeek'
  deepseek.baseURL = 'https://api.deepseek.com'
  deepseek.authEnv = 'DEEPSEEK_API_KEY'
  deepseek.apiKeyRef = 'DEEPSEEK_API_KEY'
  const dsChat = new CNModel()
  dsChat.id = 'deepseek-chat'
  dsChat.name = 'DeepSeek Chat'
  dsChat.coding = true
  dsChat.recommended = true
  const dsReasoner = new CNModel()
  dsReasoner.id = 'deepseek-reasoner'
  dsReasoner.name = 'DeepSeek Reasoner'
  dsReasoner.coding = true
  deepseek.models = [dsChat, dsReasoner]
  providers.push(deepseek)

  // Qwen / 阿里百炼
  const qwen = new CNProvider()
  qwen.id = 'qwen-cn'
  qwen.name = '通义千问 / 阿里百炼'
  qwen.baseURL = 'https://dashscope.aliyuncs.com/compatible-mode/v1'
  qwen.authEnv = 'DASHSCOPE_API_KEY'
  qwen.apiKeyRef = 'DASHSCOPE_API_KEY'
  const qwCoder = new CNModel()
  qwCoder.id = 'qwen3-coder-plus'
  qwCoder.name = 'Qwen3 Coder Plus'
  qwCoder.coding = true
  qwCoder.recommended = true
  const qwPlus = new CNModel()
  qwPlus.id = 'qwen-plus'
  qwPlus.name = 'Qwen Plus'
  qwPlus.coding = false
  const qwMax = new CNModel()
  qwMax.id = 'qwen-max'
  qwMax.name = 'Qwen Max'
  qwMax.coding = false
  qwen.models = [qwCoder, qwPlus, qwMax]
  providers.push(qwen)

  // GLM / 智谱
  const glm = new CNProvider()
  glm.id = 'glm-cn'
  glm.name = '智谱 GLM / BigModel'
  glm.baseURL = 'https://open.bigmodel.cn/api/paas/v4'
  glm.authEnv = 'BIGMODEL_API_KEY'
  glm.apiKeyRef = 'BIGMODEL_API_KEY'
  const glmMain = new CNModel()
  glmMain.id = 'glm-4.5'
  glmMain.name = 'GLM-4.5'
  glmMain.coding = true
  glmMain.recommended = true
  const glmAir = new CNModel()
  glmAir.id = 'glm-4.5-air'
  glmAir.name = 'GLM-4.5 Air'
  glmAir.coding = true
  glm.models = [glmMain, glmAir]
  providers.push(glm)

  // Kimi / Moonshot
  const kimi = new CNProvider()
  kimi.id = 'kimi-cn'
  kimi.name = 'Kimi / Moonshot'
  kimi.baseURL = 'https://api.moonshot.cn/v1'
  kimi.authEnv = 'MOONSHOT_API_KEY'
  kimi.apiKeyRef = 'MOONSHOT_API_KEY'
  const kimiK2 = new CNModel()
  kimiK2.id = 'kimi-k2'
  kimiK2.name = 'Kimi K2'
  kimiK2.coding = true
  kimiK2.recommended = true
  kimi.models = [kimiK2]
  providers.push(kimi)

  // MiniMax
  const minimax = new CNProvider()
  minimax.id = 'minimax-cn'
  minimax.name = 'MiniMax'
  minimax.baseURL = 'https://api.minimax.chat/v1'
  minimax.authEnv = 'MINIMAX_API_KEY'
  minimax.apiKeyRef = 'MINIMAX_API_KEY'
  const mmM2 = new CNModel()
  mmM2.id = 'MiniMax-M2'
  mmM2.name = 'MiniMax M2'
  mmM2.coding = true
  mmM2.recommended = true
  minimax.models = [mmM2]
  providers.push(minimax)

  // 火山方舟
  const volc = new CNProvider()
  volc.id = 'volcengine-cn'
  volc.name = '火山方舟 / Volcengine Ark'
  volc.baseURL = 'https://ark.cn-beijing.volces.com/api/v3'
  volc.authEnv = 'VOLCENGINE_API_KEY'
  volc.apiKeyRef = 'VOLCENGINE_API_KEY'
  volc.models = []
  providers.push(volc)

  // 百度千帆
  const baidu = new CNProvider()
  baidu.id = 'baidu-qianfan-cn'
  baidu.name = '百度千帆'
  baidu.baseURL = 'https://qianfan.baidubce.com/v2'
  baidu.authEnv = 'QIANFAN_API_KEY'
  baidu.apiKeyRef = 'QIANFAN_API_KEY'
  baidu.models = []
  providers.push(baidu)

  // SiliconFlow
  const sf = new CNProvider()
  sf.id = 'siliconflow-cn'
  sf.name = 'SiliconFlow'
  sf.baseURL = 'https://api.siliconflow.cn/v1'
  sf.authEnv = 'SILICONFLOW_API_KEY'
  sf.apiKeyRef = 'SILICONFLOW_API_KEY'
  const sfQwen = new CNModel()
  sfQwen.id = 'Qwen/Qwen3-Coder-480B-A35B-Instruct'
  sfQwen.name = 'Qwen3 Coder 480B'
  sfQwen.coding = true
  sfQwen.recommended = true
  const sfDS = new CNModel()
  sfDS.id = 'deepseek-ai/DeepSeek-V3'
  sfDS.name = 'DeepSeek V3'
  sfDS.coding = true
  sf.models = [sfQwen, sfDS]
  providers.push(sf)

  // 自定义 OpenAI Compatible
  const custom = new CNProvider()
  custom.id = 'custom-openai-compatible'
  custom.name = '自定义 OpenAI Compatible'
  custom.baseURL = ''
  custom.authEnv = 'CUSTOM_API_KEY'
  custom.apiKeyRef = 'CUSTOM_API_KEY'
  custom.models = []
  providers.push(custom)

  return providers
}
