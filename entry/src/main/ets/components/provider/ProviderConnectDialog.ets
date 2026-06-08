import { Theme } from '../Theme'
import { ProviderTemplate } from '../../services/ProviderTemplateRegistry'
import { ProviderConnectInput, ProviderModelInput, ProviderHeaderInput, providerConnectionService, TestConnectionResult } from '../../services/ProviderConnectionService'

@Component
export struct ProviderConnectDialog {
  @Prop visible: boolean = false
  @Prop template: ProviderTemplate | null = null
  onCancel: () => void = () => {}
  onSubmit: (input: ProviderConnectInput) => void = () => {}

  @State providerId: string = ''
  @State displayName: string = ''
  @State baseURL: string = ''
  @State apiKey: string = ''
  @State apiType: string = 'openai_compatible' // 'openai_compatible' | 'anthropic' | 'openai_responses' | 'bedrock_converse'

  @State modelId: string = ''
  @State modelName: string = ''
  @State headerName: string = ''
  @State headerValue: string = ''

  @State models: ProviderModelInput[] = []
  @State headers: ProviderHeaderInput[] = []

  @State initializedFromTemplate: boolean = false
  @State errorText: string = ''

  // Test connection state
  @State testing: boolean = false
  @State testResult: TestConnectionResult | null = null

  aboutToAppear(): void {
    this.applyTemplateIfNeeded()
  }

  private applyTemplateIfNeeded(): void {
    if (this.initializedFromTemplate) return
    this.initializedFromTemplate = true

    if (this.template === null) return

    this.apiType = this.template.apiType

    if (this.template.id.startsWith('custom-')) {
      this.providerId = ''
      this.displayName = ''
      this.baseURL = this.template.baseURL
      this.models = []
      this.headers = []
      return
    }

    this.providerId = this.template.id
    this.displayName = this.template.name
    this.baseURL = this.template.baseURL

    const list: ProviderModelInput[] = []
    for (const tm of this.template.models) {
      const m = new ProviderModelInput()
      m.id = tm.id
      m.name = tm.name
      list.push(m)
    }
    this.models = list
  }

  private providerIdPlaceholder(): string {
    switch (this.apiType) {
      case 'anthropic': return 'my-anthropic'
      case 'openai_responses': return 'my-openai'
      case 'bedrock_converse': return 'my-bedrock'
      default: return 'deepseek-cn'
    }
  }

  private displayNamePlaceholder(): string {
    switch (this.apiType) {
      case 'anthropic': return 'My Anthropic'
      case 'openai_responses': return 'My OpenAI'
      case 'bedrock_converse': return 'My Bedrock'
      default: return 'DeepSeek'
    }
  }

  private baseURLHint(): string {
    switch (this.apiType) {
      case 'anthropic': return 'Anthropic API 端点。留空则使用官方 https://api.anthropic.com。'
      case 'bedrock_converse': return 'Bedrock Runtime 区域端点，如 https://bedrock-runtime.us-east-1.amazonaws.com。'
      case 'openai_responses': return 'OpenAI API 端点。留空则使用官方 https://api.openai.com。'
      default: return '填写 API 的 Base URL，不是官网或控制台地址。'
    }
  }

  private apiKeyHint(): string {
    switch (this.apiType) {
      case 'bedrock_converse': return '填写 AccessKeyID|SecretAccessKey（用竖线分隔）。不会写入日志。'
      default: return 'API Key 不会写入日志，也不会在界面中明文展示。'
    }
  }

  private getPlaceholder(field: string): string {
    if (this.apiType === 'anthropic') {
      switch (field) {
        case 'baseURL': return 'https://api.anthropic.com'
        case 'apiKey': return 'sk-ant-xxxxxxxx'
        case 'modelId': return 'claude-sonnet-4-20250514'
        case 'modelName': return 'Claude Sonnet 4'
      }
    }
    if (this.apiType === 'openai_responses') {
      switch (field) {
        case 'baseURL': return 'https://api.openai.com'
        case 'apiKey': return 'sk-proj-xxxxxxxx'
        case 'modelId': return 'gpt-4o'
        case 'modelName': return 'GPT-4o'
      }
    }
    if (this.apiType === 'bedrock_converse') {
      switch (field) {
        case 'baseURL': return 'https://bedrock-runtime.us-east-1.amazonaws.com'
        case 'apiKey': return 'AKIA...|wJal...'
        case 'modelId': return 'anthropic.claude-sonnet-4-20250514-v1:0'
        case 'modelName': return 'Claude Sonnet 4 (Bedrock)'
      }
    }
    switch (field) {
      case 'baseURL': return 'https://api.deepseek.com'
      case 'apiKey': return 'sk-xxxxxxxx'
      case 'modelId': return 'deepseek-chat'
      case 'modelName': return 'DeepSeek Chat'
    }
    return ''
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
              this.IntroBlock()
              this.ApiTypeBlock()
              this.ProviderBlock()
              this.ModelBlock()
              this.HeaderBlock()
              this.TestResultBlock()

              if (this.errorText.length > 0) {
                Text(this.errorText)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.DANGER)
                  .margin({ top: 14 })
              }

              Blank()
                .height(18)
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

  @Builder
  Header() {
    Row() {
      Text('←')
        .fontSize(24)
        .fontColor(Theme.TEXT_MUTED)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .onClick(() => this.onCancel())

      Blank()

      Text('×')
        .fontSize(28)
        .fontColor(Theme.TEXT_MUTED)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(8)
        .onClick(() => this.onCancel())
    }
    .width('100%')
    .height(64)
    .padding({ left: 24, right: 24 })
  }

  @Builder
  IntroBlock() {
    Column() {
      Row() {
        Text('✦')
          .fontSize(30)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .width(48)

        Column() {
          Text('自定义提供商')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          Text('填入服务商地址、API 密钥和模型 ID，然后测试连接。')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .margin({ bottom: 20 })
  }

  @Builder
  ApiTypeBlock() {
    Column() {
      this.SectionTitle('API 协议')

      // Row 1: OpenAI Compatible + Anthropic
      Row() {
        Text('OpenAI Compatible')
          .fontSize(Theme.fs.sm)
          .fontWeight(this.apiType === 'openai_compatible' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.apiType === 'openai_compatible' ? Theme.BG : Theme.TEXT_PRIMARY)
          .height(38)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(this.apiType === 'openai_compatible' ? Theme.TEXT_PRIMARY : Theme.BG)
          .borderWidth(1)
          .borderColor(this.apiType === 'openai_compatible' ? Theme.TEXT_PRIMARY : Theme.BORDER)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.setApiType('openai_compatible') })

        Text('Anthropic')
          .fontSize(Theme.fs.sm)
          .fontWeight(this.apiType === 'anthropic' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.apiType === 'anthropic' ? Theme.BG : Theme.TEXT_PRIMARY)
          .height(38)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(this.apiType === 'anthropic' ? Theme.TEXT_PRIMARY : Theme.BG)
          .borderWidth(1)
          .borderColor(this.apiType === 'anthropic' ? Theme.TEXT_PRIMARY : Theme.BORDER)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 8 })
          .onClick(() => { this.setApiType('anthropic') })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // Row 2: OpenAI Responses + AWS Bedrock
      Row() {
        Text('OpenAI Responses')
          .fontSize(Theme.fs.sm)
          .fontWeight(this.apiType === 'openai_responses' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.apiType === 'openai_responses' ? Theme.BG : Theme.TEXT_PRIMARY)
          .height(38)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(this.apiType === 'openai_responses' ? Theme.TEXT_PRIMARY : Theme.BG)
          .borderWidth(1)
          .borderColor(this.apiType === 'openai_responses' ? Theme.TEXT_PRIMARY : Theme.BORDER)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.setApiType('openai_responses') })

        Text('AWS Bedrock')
          .fontSize(Theme.fs.sm)
          .fontWeight(this.apiType === 'bedrock_converse' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.apiType === 'bedrock_converse' ? Theme.BG : Theme.TEXT_PRIMARY)
          .height(38)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(this.apiType === 'bedrock_converse' ? Theme.TEXT_PRIMARY : Theme.BG)
          .borderWidth(1)
          .borderColor(this.apiType === 'bedrock_converse' ? Theme.TEXT_PRIMARY : Theme.BORDER)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ left: 8 })
          .onClick(() => { this.setApiType('bedrock_converse') })
      }
      .width('100%')
      .margin({ bottom: 4 })

      Text(this.apiTypeDescription())
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(18)
    .borderRadius(14)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 18 })
    .alignItems(HorizontalAlign.Start)
  }

  private setApiType(t: string): void {
    if (this.apiType !== t) {
      this.apiType = t
      this.testResult = null
      this.errorText = ''
    }
  }

  private apiTypeDescription(): string {
    switch (this.apiType) {
      case 'anthropic':
        return 'Anthropic Messages API（/v1/messages）。Base URL 留空则使用官方端点。'
      case 'openai_responses':
        return 'OpenAI Responses API（/v1/responses），新一代 API 格式。'
      case 'bedrock_converse':
        return 'AWS Bedrock Converse API。API Key 填 AccessKeyID|SecretAccessKey，Base URL 填区域端点。'
      default:
        return '标准 OpenAI Chat Completions API（/v1/chat/completions）。'
    }
  }

  @Builder
  ProviderBlock() {
    Column() {
      this.SectionTitle('1. 提供商信息')

      this.FormLabel('提供商 ID')
      TextInput({ text: this.providerId, placeholder: this.providerIdPlaceholder() })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.providerId = v)
      this.Hint('只能使用小写字母、数字、连字符或下划线。')

      this.FormLabel('显示名称')
      TextInput({ text: this.displayName, placeholder: this.displayNamePlaceholder() })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.displayName = v)

      this.FormLabel('基础 URL')
      TextInput({ text: this.baseURL, placeholder: this.getPlaceholder('baseURL') })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.baseURL = v)
      this.Hint(this.baseURLHint())

      this.FormLabel('API 密钥')
      TextInput({ text: this.apiKey, placeholder: this.getPlaceholder('apiKey') })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .type(InputType.Password)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.apiKey = v)
      this.Hint(this.apiKeyHint())
    }
    .width('100%')
    .padding(18)
    .borderRadius(14)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 18 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ModelBlock() {
    Column() {
      this.SectionTitle('2. 模型')

      if (this.models.length === 0) {
        Text('还没有添加模型。至少添加一个模型后才能提交或测试。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: 12 })
      } else {
        ForEach(this.models, (m: ProviderModelInput, index: number) => {
          this.ModelRow(m, index)
        }, (m: ProviderModelInput) => m.id)
      }

      Row() {
        TextInput({ text: this.modelId, placeholder: this.getPlaceholder('modelId') })
          .layoutWeight(1)
          .height(42)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => this.modelId = v)

        TextInput({ text: this.modelName, placeholder: this.getPlaceholder('modelName') })
          .layoutWeight(1)
          .height(42)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ left: 10 })
          .onChange((v: string) => this.modelName = v)

        Text('添加')
          .fontSize(Theme.fs.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ACCENT)
          .height(42)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(Theme.ACTIVE_BG)
          .margin({ left: 10 })
          .onClick(() => this.addModel())
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(14)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 18 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  HeaderBlock() {
    Column() {
      this.SectionTitle('3. 请求头（可选）')

      if (this.headers.length === 0) {
        Text(this.apiType === 'anthropic'
          ? '通常不需要额外请求头。Anthropic 认证通过 x-api-key 头自动处理。'
          : '普通 API 通常不需要额外请求头。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: 12 })
      } else {
        ForEach(this.headers, (h: ProviderHeaderInput, index: number) => {
          this.HeaderRow(h, index)
        }, (h: ProviderHeaderInput) => h.name)
      }

      Row() {
        TextInput({ text: this.headerName, placeholder: 'Header-Name' })
          .layoutWeight(1)
          .height(42)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => this.headerName = v)

        TextInput({ text: this.headerValue, placeholder: 'value' })
          .layoutWeight(1)
          .height(42)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .type(InputType.Password)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ left: 10 })
          .onChange((v: string) => this.headerValue = v)

        Text('添加')
          .fontSize(Theme.fs.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_SECONDARY)
          .height(42)
          .padding({ left: 16, right: 16 })
          .borderRadius(8)
          .backgroundColor(Theme.PANEL)
          .margin({ left: 10 })
          .onClick(() => this.addHeader())
      }
    }
    .width('100%')
    .padding(18)
    .borderRadius(14)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  TestResultBlock() {
    if (this.testResult !== null) {
      Row() {
        if (this.testResult!.ok) {
          Text('✓')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.SUCCESS)
            .margin({ right: 10 })

          Column() {
            Text(`连接成功 · ${this.testResult!.latencyMs}ms`)
              .fontSize(Theme.fs.sm)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.SUCCESS)

            if (this.testResult!.responsePreview.length > 0) {
              Text(`模型回复: "${this.testResult!.responsePreview}"`)
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
        } else {
          Text('✗')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.DANGER)
            .margin({ right: 10 })

          Text(this.testResult!.error)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .layoutWeight(1)
        }
      }
      .width('100%')
      .padding(14)
      .borderRadius(10)
      .backgroundColor(this.testResult!.ok ? 'rgba(34,197,94,0.08)' : 'rgba(239,68,68,0.08)')
      .borderWidth(1)
      .borderColor(this.testResult!.ok ? 'rgba(34,197,94,0.25)' : 'rgba(239,68,68,0.25)')
      .margin({ top: 14 })
    }
  }

  @Builder
  Footer() {
    Row() {
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.DANGER)
          .layoutWeight(1)
      } else {
        Text(this.testing ? '正在测试连接...' : '提交后会保存本地配置，并在已连接 Server 时写入 OpenCode 配置。')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .layoutWeight(1)
      }

      Text(this.testing ? '测试中...' : '测试连接')
        .fontSize(Theme.fs.sm)
        .fontColor(this.testing ? Theme.TEXT_MUTED : Theme.ACCENT)
        .height(42)
        .padding({ left: 18, right: 18 })
        .borderRadius(8)
        .backgroundColor(this.testing ? Theme.PANEL : Theme.ACTIVE_BG)
        .borderWidth(1)
        .borderColor(this.testing ? Theme.BORDER : Theme.ACCENT)
        .margin({ right: 10 })
        .onClick(() => this.runTest())

      Text('取消')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .height(42)
        .padding({ left: 18, right: 18 })
        .borderRadius(8)
        .backgroundColor(Theme.PANEL)
        .margin({ right: 10 })
        .onClick(() => this.onCancel())

      Text('提交')
        .fontSize(Theme.fs.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.BG)
        .height(42)
        .padding({ left: 22, right: 22 })
        .borderRadius(8)
        .backgroundColor(Theme.TEXT_PRIMARY)
        .onClick(() => this.submit())
    }
    .width('100%')
    .height(68)
    .padding({ left: 34, right: 34 })
    .borderWidth({ top: 1 })
    .borderColor(Theme.BORDER)
    .backgroundColor(Theme.BG)
  }

  @Builder
  SectionTitle(text: string) {
    Text(text)
      .fontSize(Theme.fs.md)
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.TEXT_PRIMARY)
      .margin({ bottom: 14 })
  }

  @Builder
  FormLabel(text: string) {
    Text(text)
      .fontSize(Theme.fs.sm)
      .fontColor(Theme.TEXT_MUTED)
      .fontWeight(FontWeight.Bold)
      .margin({ top: 12, bottom: 8 })
  }

  @Builder
  Hint(text: string) {
    Text(text)
      .fontSize(Theme.fs.xs)
      .fontColor(Theme.TEXT_SECONDARY)
      .margin({ top: 6, bottom: 4 })
  }

  @Builder
  ModelRow(m: ProviderModelInput, index: number) {
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

  @Builder
  HeaderRow(h: ProviderHeaderInput, index: number) {
    Row() {
      Text(h.name)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)

      Text('••••••')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .layoutWeight(1)

      Text('删除')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .onClick(() => this.removeHeader(index))
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(Theme.BG)
    .margin({ bottom: 8 })
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

    const list: ProviderModelInput[] = []
    for (const item of this.models) list.push(item)
    list.push(m)
    this.models = list

    this.modelId = ''
    this.modelName = ''
    this.errorText = ''
  }

  private removeModel(index: number): void {
    const list: ProviderModelInput[] = []
    for (let i = 0; i < this.models.length; i++) {
      if (i !== index) list.push(this.models[i])
    }
    this.models = list
  }

  private addHeader(): void {
    if (this.headerName.trim().length === 0) return

    const h = new ProviderHeaderInput()
    h.name = this.headerName.trim()
    h.value = this.headerValue

    const list: ProviderHeaderInput[] = []
    for (const item of this.headers) list.push(item)
    list.push(h)
    this.headers = list

    this.headerName = ''
    this.headerValue = ''
  }

  private removeHeader(index: number): void {
    const list: ProviderHeaderInput[] = []
    for (let i = 0; i < this.headers.length; i++) {
      if (i !== index) list.push(this.headers[i])
    }
    this.headers = list
  }

  private buildInput(): ProviderConnectInput {
    const input = new ProviderConnectInput()
    input.providerId = this.providerId.trim()
    input.displayName = this.displayName.trim()
    input.apiType = this.apiType
    input.baseURL = this.baseURL.trim()
    input.apiKey = this.apiKey
    input.models = this.models
    input.headers = this.headers
    return input
  }

  private validate(): string {
    if (this.providerId.trim().length === 0) return 'Provider ID 不能为空'
    if (!this.isValidProviderId(this.providerId.trim())) return 'Provider ID 只能包含小写字母、数字、连字符或下划线'
    if (this.displayName.trim().length === 0) return '显示名称不能为空'
    if (this.apiType !== 'anthropic' && this.apiType !== 'openai_responses' && this.baseURL.trim().length === 0) return '基础 URL 不能为空'
    if (this.baseURL.trim().length > 0 && !this.baseURL.trim().startsWith('http://') && !this.baseURL.trim().startsWith('https://')) return '基础 URL 必须以 http:// 或 https:// 开头'
    if (this.apiType === 'bedrock_converse' && !this.apiKey.includes('|')) return 'AWS Bedrock 需要填写 AccessKeyID|SecretAccessKey 格式'
    if (this.models.length === 0) return '至少需要添加一个模型'
    return ''
  }

  private async runTest(): Promise<void> {
    if (this.testing) return

    const err = this.validate()
    if (err.length > 0) {
      this.errorText = err
      return
    }

    this.testing = true
    this.errorText = ''
    this.testResult = null

    const input = this.buildInput()
    // For Anthropic, fill in default baseURL if empty
    if (this.apiType === 'anthropic' && input.baseURL.length === 0) {
      input.baseURL = 'https://api.anthropic.com'
    }

    const result = await providerConnectionService.testConnection(input)
    this.testResult = result
    this.testing = false
  }

  private submit(): void {
    const err = this.validate()
    if (err.length > 0) {
      this.errorText = err
      return
    }

    const input = this.buildInput()
    // For Anthropic, fill in default baseURL if empty
    if (this.apiType === 'anthropic' && input.baseURL.length === 0) {
      input.baseURL = 'https://api.anthropic.com'
    }

    this.errorText = ''
    this.onSubmit(input)
  }

  private isValidProviderId(id: string): boolean {
    for (let i = 0; i < id.length; i++) {
      const c = id.charAt(i)
      const ok = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c === '-' || c === '_'
      if (!ok) return false
    }
    return true
  }
}
