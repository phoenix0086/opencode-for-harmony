import { Theme } from '../Theme'
import { http } from '@kit.NetworkKit'
import { ProviderConnectInput, ProviderModelInput, providerConnectionService, TestConnectionResult } from '../../services/ProviderConnectionService'

// API 模式选项定义（ArkUI Select 需要 SelectOption[]）
const API_MODE_OPTIONS: SelectOption[] = [
  { value: 'OpenAI Chat Completions' },
  { value: 'Anthropic Messages' },
  { value: 'OpenAI Responses' },
  { value: 'AWS Bedrock Converse' }
]

@Component
export struct ProviderConnectDialog {
  @Prop visible: boolean = false
  onCancel: () => void = () => {}
  onSubmit: (input: ProviderConnectInput) => void = () => {}

  // ── 表单字段 ──
  @State providerName: string = ''       // 供应商名称
  @State notes: string = ''              // 备注
  @State websiteURL: string = ''         // 官网链接（可选）
  @State apiModeIndex: number = 0        // API 模式下拉选中索引
  @State apiEndpoint: string = ''        // API 端点
  @State apiKey: string = ''             // API Key

  // ── 模型列表 ──
  @State modelId: string = ''
  @State modelName: string = ''
  @State models: ProviderModelInput[] = []

  // ── 状态 ──
  @State errorText: string = ''
  @State testing: boolean = false
  @State testResult: TestConnectionResult | null = null
  @State fetchingModels: boolean = false

  aboutToAppear(): void {
    this.resetForm()
  }

  private resetForm(): void {
    this.providerName = ''
    this.notes = ''
    this.websiteURL = ''
    this.apiModeIndex = 0
    this.apiEndpoint = ''
    this.apiKey = ''
    this.modelId = ''
    this.modelName = ''
    this.models = []
    this.errorText = ''
    this.testing = false
    this.testResult = null
    this.fetchingModels = false
  }

  // ── 当前选中的 apiType 值 ──
  private getApiType(): string {
    switch (this.apiModeIndex) {
      case 1: return 'anthropic'
      case 2: return 'openai_responses'
      case 3: return 'bedrock_converse'
      default: return 'openai_compatible'
    }
  }

  private getApiModeLabel(): ResourceStr {
    return API_MODE_OPTIONS[this.apiModeIndex]?.value || API_MODE_OPTIONS[0].value
  }

  // ── 占位符动态变化 ──
  private namePlaceholder(): string {
    switch (this.getApiType()) {
      case 'anthropic': return '例如：Claude 官方'
      case 'openai_responses': return '例如：OpenAI 官方'
      case 'bedrock_converse': return '例如：AWS Bedrock'
      default: return '例如：Claude 官方'
    }
  }

  private endpointPlaceholder(): string {
    switch (this.getApiType()) {
      case 'anthropic': return 'https://api.anthropic.com'
      case 'openai_responses': return 'https://api.openai.com'
      case 'bedrock_converse': return 'https://bedrock-runtime.us-east-1.amazonaws.com'
      default: return 'https://api.example.com/v1'
    }
  }

  private keyPlaceholder(): string {
    switch (this.getApiType()) {
      case 'bedrock_converse': return 'AKIA...|wJal...'
      case 'anthropic': return 'sk-ant-xxxxxxxx 或 tp-xxxxx'
      case 'openai_responses': return 'sk-proj-xxxxxxxx'
      default: return 'sk-xxxxxxxx'
    }
  }

  private modelIdPlaceholder(): string {
    switch (this.getApiType()) {
      case 'anthropic': return 'claude-sonnet-4-20250514'
      case 'openai_responses': return 'gpt-4o'
      case 'bedrock_converse': return 'anthropic.claude-sonnet-4-20250514-v1:0'
      default: return 'deepseek-chat'
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        Rect()
          .fill('rgba(0,0,0,0.46)')
          .width('100%')
          .height('100%')
          .onClick(() => this.onCancel())

        Column() {
          this.Header()

          Scroll() {
            Column() {
              this.NameRow()
              this.WebsiteRow()
              this.ApiModeRow()
              this.EndpointRow()
              this.ApiKeyRow()
              this.ModelListSection()

              // 测试结果展示
              if (this.testResult !== null) {
                this.TestResultBlock()
              }

              if (this.errorText.length > 0) {
                Text(this.errorText)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.DANGER)
                  .margin({ top: 10 })
              }
              Blank().height(18)
            }
            .width('100%')
            .padding({ left: 34, right: 34, top: 12, bottom: 18 })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)

          this.Footer()
        }
        .width(820)
        .height(720)
        .borderRadius(16)
        .backgroundColor(Theme.BG)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .shadow({ radius: 28, color: '#66000000', offsetX: 0, offsetY: 14 })
      }
      .width('100%')
      .height('100%')
    }
  }

  // ══════════ Header ══════════

  @Builder
  Header() {
    Row() {
      Text('\u2190')  // ←
        .fontSize(24)
        .fontColor(Theme.TEXT_MUTED)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .onClick(() => this.onCancel())

      Text('添加新供应商')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .height(64)
    .padding({ left: 24, right: 24 })
  }

  // ══════════ 供应商名称 + 备注（并排）══════════

  @Builder
  NameRow() {
    Column() {
      Row() {
        Text('供应商名称')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text('备注')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')

      Row() {
        TextInput({ text: this.providerName, placeholder: this.namePlaceholder() })
          .layoutWeight(1)
          .height(46)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => this.providerName = v)

        TextInput({ text: this.notes, placeholder: '例如：公司专用账号' })
          .layoutWeight(1)
          .height(46)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(10)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ left: 14 })
          .onChange((v: string) => this.notes = v)
      }
      .width('100%')
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // ══════════ 官网链接（可选）══════════

  @Builder
  WebsiteRow() {
    Column() {
      Text('官网链接')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)

      TextInput({ text: this.websiteURL, placeholder: 'https://example.com（可选）' })
        .width('100%')
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.websiteURL = v)
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // ══════════ API 模式（下拉框）══════════

  @Builder
  ApiModeRow() {
    Column() {
      Text('API 模式')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)

      Select(API_MODE_OPTIONS)
        .value(this.getApiModeLabel())
        .selected(this.apiModeIndex)
        .width('100%')
        .height(46)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.ACCENT)
        .onSelect((index: number) => {
          if (this.apiModeIndex !== index) {
            this.apiModeIndex = index
            this.errorText = ''
            this.testResult = null
          }
        })

      Text('供应商 API 协议。请根据端点选择正确的协议。')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: 6 })
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // ══════════ API 端点 ══════════

  @Builder
  EndpointRow() {
    Column() {
      Text('API 端点')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)

      TextInput({ text: this.apiEndpoint, placeholder: this.endpointPlaceholder() })
        .width('100%')
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(this.endpointError() ? Theme.DANGER : Theme.BORDER)
        .onChange((v: string) => {
          this.apiEndpoint = v
          if (v.trim().length > 0 && this.errorText.includes('端点')) this.errorText = ''
        })

      if (this.endpointError()) {
        Text('API 端点不能为空')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .margin({ top: 6 })
      } else {
        Text('供应商的 API 端点地址。')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ top: 6 })
      }
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  private endpointError(): boolean {
    return this.errorText.includes('端点') || this.errorText.includes('Base URL')
  }

  // ══════════ API Key ══════════

  @Builder
  ApiKeyRow() {
    Column() {
      Text('API Key')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)

      TextInput({ text: this.apiKey, placeholder: '只需要填这里，下方配置会自动填充' })
        .width('100%')
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .type(InputType.Password)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.apiKey = v)
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  // ══════════ 模型列表 ══════════

  @Builder
  ModelListSection() {
    Column() {
      Row() {
        Text('模型列表')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Blank()

        Text(this.fetchingModels ? '\u23f3 获取中...' : '\u21e9 获取模型列表')  // ↓
          .fontSize(Theme.fs.xs)
          .fontColor(this.fetchingModels ? Theme.ACCENT : Theme.TEXT_SECONDARY)
          .height(32)
          .padding({ left: 12, right: 12 })
          .borderRadius(6)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .backgroundColor(Theme.PANEL)
          .onClick(() => this.fetchModelList())

        Text('+ 添加模型')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_PRIMARY)
          .height(32)
          .padding({ left: 12, right: 12 })
          .borderRadius(6)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .backgroundColor(Theme.PANEL)
          .margin({ left: 8 })
          .onClick(() => this.addModel())
      }
      .width('100%')

      if (this.models.length === 0) {
        Text('暂无模型配置。切换到此供应商时将不会更新默认模型。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 12 })

        Text('切换到此供应商时，第一个模型会写入顶层 model.default。')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 4 })
      } else {
        ForEach(this.models, (m: ProviderModelInput, index: number) => {
          this.ModelItem(m, index)
        }, (m: ProviderModelInput) => m.id)
      }

      // 手动添加模型输入行
      Row() {
        TextInput({ text: this.modelId, placeholder: this.modelIdPlaceholder() })
          .layoutWeight(1)
          .height(40)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => this.modelId = v)

        TextInput({ text: this.modelName, placeholder: '显示名称' })
          .layoutWeight(1)
          .height(40)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ left: 10 })
          .onChange((v: string) => this.modelName = v)
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
  }

  @Builder
  ModelItem(m: ProviderModelInput, index: number) {
    Row() {
      Text(m.id)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)

      Text(m.name.length > 0 ? m.name : m.id)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .layoutWeight(1)

      Text('删除')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .onClick(() => this.removeModel(index))
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(Theme.BG)
    .margin({ bottom: 8 })
  }

  // ══════════ 测试结果展示 ══════════

  @Builder
  TestResultBlock() {
    Column() {
      Row() {
        Text(this.testResult!.ok ? '\u2705 测试通过' : '\u274c 测试失败')  // ✅/❌
          .fontSize(Theme.fs.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.testResult!.ok ? Theme.SUCCESS : Theme.DANGER)

        Blank()

        Text(`${this.testResult!.latencyMs}ms`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .width('100%')

      if (this.testResult!.ok && this.testResult!.modelUsed.length > 0) {
        Text(`模型: ${this.testResult!.modelUsed}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ top: 4 })
      }

      if (this.testResult!.responsePreview.length > 0) {
        Text(`响应预览: ${this.testResult!.responsePreview}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.SUCCESS)
          .margin({ top: 2 })
      }

      if (!this.testResult!.ok && this.testResult!.error.length > 0) {
        Text(`错误: ${this.testResult!.error}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .margin({ top: 2 })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.testResult!.ok ? 'rgba(16,185,129,0.08)' : 'rgba(239,68,68,0.08)')
    .borderWidth(1)
    .borderColor(this.testResult!.ok ? 'rgba(16,185,129,0.25)' : 'rgba(239,68,68,0.25)')
    .margin({ top: 12 })
  }

  // ══════════ Footer（测试 | 取消 | 添加）══════════

  @Builder
  Footer() {
    Row() {
      Blank()

      // 测试连接按钮
      Text(this.testing ? '\u23f3 测试中...' : '测试连接')
        .fontSize(Theme.fs.sm)
        .fontColor(this.testing ? Theme.TEXT_MUTED : Theme.TEXT_PRIMARY)
        .height(42)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .backgroundColor(this.testing ? Theme.PANEL : Theme.SIDEBAR)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onClick(() => this.doTest())

      Text('取消')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .height(42)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .backgroundColor(Theme.PANEL)
        .margin({ left: 10 })
        .onClick(() => this.onCancel())

      Text('+ 添加')
        .fontSize(Theme.fs.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_INVERSE)
        .height(42)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .backgroundColor(Theme.ACCENT)
        .onClick(() => this.submit())
    }
    .width('100%')
    .height(68)
    .padding({ left: 34, right: 34 })
    .borderWidth({ top: 1 })
    .borderColor(Theme.BORDER)
    .backgroundColor(Theme.BG)
  }

  // ══════════ 获取模型列表 ══════════

  async fetchModelList(): Promise<void> {
    const base = this.getEffectiveBaseUrl()
    if (base.length === 0 || this.apiKey.length === 0) {
      this.errorText = '请先填写 API 端点和 API Key'
      return
    }

    this.fetchingModels = true
    this.errorText = ''

    try {
      const apiType = this.getApiType()
      let url = ''
      let headers: Record<string, string> = {}

      if (apiType === 'anthropic') {
        url = base.endsWith('/') ? `${base}v1/models` : `${base}/v1/models`
        headers['Content-Type'] = 'application/json'
        headers['x-api-key'] = this.apiKey
        headers['anthropic-version'] = '2023-06-01'
      } else if (apiType === 'openai_responses') {
        url = base.endsWith('/') ? `${base}v1/models` : `${base}/v1/models`
        headers['Content-Type'] = 'application/json'
        headers['Authorization'] = `Bearer ${this.apiKey}`
      } else if (apiType === 'bedrock_converse') {
        // Bedrock 不支持标准 /models 接口，跳过
        this.errorText = 'AWS Bedrock 不支持自动获取模型列表，请手动输入模型 ID'
        this.fetchingModels = false
        return
      } else {
        // openai_compatible
        url = base.endsWith('/') ? `${base}v1/models` : `${base}/v1/models`
        headers['Content-Type'] = 'application/json'
        headers['Authorization'] = `Bearer ${this.apiKey}`
      }

      const req = http.createHttp()
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 8000,
        readTimeout: 15000
      })
      req.destroy()

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        const raw = resp.result as string
        try {
          const data = JSON.parse(raw) as Record<string, Object>
          const arr = data['data'] as Array<Record<string, Object>>
          if (arr !== undefined && Array.isArray(arr)) {
            const newModels: ProviderModelInput[] = []
            for (const item of arr) {
              const id = item['id'] as string
              if (id !== undefined && id.length > 0) {
                const m = new ProviderModelInput()
                m.id = id
                m.name = id
                newModels.push(m)
              }
            }
            if (newModels.length > 0) {
              // 合并到已有列表（去重）
              for (const nm of newModels) {
                let exists = false
                for (const em of this.models) {
                  if (em.id === nm.id) { exists = true; break; }
                }
                if (!exists) {
                  this.models = [...this.models, nm]
                }
              }
              this.errorText = `已获取 ${newModels.length} 个模型`
            } else {
              this.errorText = '未找到可用模型'
            }
          } else {
            this.errorText = '返回数据格式异常'
          }
        } catch (e) {
          this.errorText = '解析模型列表失败: ' + String(e)
        }
      } else {
        this.errorText = `获取模型失败: HTTP ${resp.responseCode}`
      }
    } catch (e) {
      this.errorText = '获取模型列表出错: ' + String(e)
    }

    this.fetchingModels = false
  }

  // ══════════ 测试连接 ══════════

  async doTest(): Promise<void> {
    if (this.testing) return

    // 自动将待填模型加入列表
    this.autoAddPendingModel()

    // 构建临时 input 用于测试
    const err = this.validateForTest()
    if (err.length > 0) {
      this.errorText = err
      return
    }

    const input = this.buildInput()
    this.testing = true
    this.errorText = ''
    this.testResult = null

    try {
      const result = await providerConnectionService.testConnection(input)
      this.testResult = result
      if (!result.ok) {
        this.errorText = result.error
      }
    } catch (e) {
      this.errorText = '测试请求异常: ' + String(e)
    }

    this.testing = false
  }

  // ══════════ 模型操作 ══════════

  private autoAddPendingModel(): void {
    if (this.modelId.trim().length > 0) {
      let exists = false
      for (const item of this.models) {
        if (item.id === this.modelId.trim()) { exists = true; break; }
      }
      if (!exists) {
        const m = new ProviderModelInput()
        m.id = this.modelId.trim()
        m.name = this.modelName.trim().length > 0 ? this.modelName.trim() : m.id
        this.models = [...this.models, m]
        this.modelId = ''
        this.modelName = ''
      }
    }
  }

  private addModel(): void {
    if (this.modelId.trim().length === 0) {
      this.errorText = 'Model ID 不能为空'
      return
    }
    for (const item of this.models) {
      if (item.id === this.modelId.trim()) {
        this.errorText = 'Model ID 不能重复'
        return
      }
    }
    const m = new ProviderModelInput()
    m.id = this.modelId.trim()
    m.name = this.modelName.trim().length > 0 ? this.modelName.trim() : m.id
    this.models = [...this.models, m]
    this.modelId = ''
    this.modelName = ''
    this.errorText = ''
  }

  private removeModel(index: number): void {
    this.models = this.models.filter((m: ProviderModelInput, i: number) => i !== index)
  }

  // ══════════ 构建 & 校验 & 提交 ══════════

  private getEffectiveBaseUrl(): string {
    const base = this.apiEndpoint.trim()
    if (base.length > 0) return base
    if (this.getApiType() === 'anthropic') return 'https://api.anthropic.com'
    if (this.getApiType() === 'openai_responses') return 'https://api.openai.com'
    return ''
  }

  private buildProviderId(): string {
    let id = this.providerName.trim().toLowerCase()
    id = id.replace(/[^a-z0-9]/g, '-')
    id = id.replace(/-+/g, '-').replace(/^-|-$/g, '')
    if (id.length === 0) id = 'custom-provider'
    return id
  }

  private buildInput(): ProviderConnectInput {
    const input = new ProviderConnectInput()
    input.providerId = this.buildProviderId()
    input.displayName = this.providerName.trim()
    input.apiType = this.getApiType()
    input.baseURL = this.getEffectiveBaseUrl()
    input.apiKey = this.apiKey
    input.models = this.models
    input.headers = []
    return input
  }

  /** 仅测试所需的最小校验 */
  private validateForTest(): string {
    if (this.apiKey.length === 0) return 'API Key 不能为空'
    if (this.models.length === 0) return '至少需要添加一个模型'
    return ''
  }

  /** 提交时的完整校验 */
  private validate(): string {
    if (this.providerName.trim().length === 0) return '供应商名称不能为空'

    // 自动将待填模型加入列表（用户可能忘了点"添加模型"）
    this.autoAddPendingModel()

    const apiType = this.getApiType()
    if (apiType !== 'anthropic' && apiType !== 'openai_responses' && this.apiEndpoint.trim().length === 0) {
      return 'API 端点不能为空'
    }
    if (this.apiEndpoint.trim().length > 0 &&
      !this.apiEndpoint.trim().startsWith('http://') && !this.apiEndpoint.trim().startsWith('https://')) {
      return 'API 端点必须以 http:// 或 https:// 开头'
    }
    if (apiType === 'bedrock_converse' && !this.apiKey.includes('|')) {
      return 'AWS Bedrock 需要填写 AccessKeyID|SecretAccessKey 格式'
    }
    if (this.models.length === 0) return '至少需要添加一个模型'

    const pid = this.buildProviderId()
    for (let i = 0; i < pid.length; i++) {
      const c = pid.charAt(i)
      const ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c === '-' || c === '_'
      if (!ok) return '供应商名称只能生成包含小写字母、数字、连字符的 ID'
    }
    return ''
  }

  private submit(): void {
    const err = this.validate()
    if (err.length > 0) {
      this.errorText = err
      return
    }

    this.errorText = ''
    this.onSubmit(this.buildInput())
  }
}
