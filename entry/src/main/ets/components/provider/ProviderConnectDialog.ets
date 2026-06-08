import { Theme } from '../Theme'
import { ProviderTemplate } from '../../services/ProviderTemplateRegistry'
import { ProviderConnectInput, ProviderModelInput, ProviderHeaderInput } from '../../services/ProviderConnectionService'

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

  @State modelId: string = ''
  @State modelName: string = ''
  @State headerName: string = ''
  @State headerValue: string = ''

  @State models: ProviderModelInput[] = []
  @State headers: ProviderHeaderInput[] = []

  @State initializedFromTemplate: boolean = false
  @State errorText: string = ''

  aboutToAppear(): void {
    this.applyTemplateIfNeeded()
  }

  private applyTemplateIfNeeded(): void {
    if (this.initializedFromTemplate) return
    this.initializedFromTemplate = true

    if (this.template === null) return

    // The custom provider template should open as an empty form.
    if (this.template.id === 'custom-openai-compatible') {
      this.providerId = ''
      this.displayName = ''
      this.baseURL = ''
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
              this.ProviderBlock()
              this.ModelBlock()
              this.HeaderBlock()

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

          Text('配置与 OpenAI 兼容的 API。填入服务商地址、API 密钥和模型 ID。')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .margin({ bottom: 24 })
  }

  @Builder
  ProviderBlock() {
    Column() {
      this.SectionTitle('1. 提供商信息')

      this.FormLabel('提供商 ID')
      TextInput({ text: this.providerId, placeholder: 'deepseek-cn' })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.providerId = v)
      this.Hint('只能使用小写字母、数字、连字符或下划线，例如 deepseek-cn、qwen-cn。')

      this.FormLabel('显示名称')
      TextInput({ text: this.displayName, placeholder: 'DeepSeek' })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.displayName = v)

      this.FormLabel('基础 URL')
      TextInput({ text: this.baseURL, placeholder: 'https://api.deepseek.com' })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.baseURL = v)
      this.Hint('填写 OpenAI Compatible API 的 Base URL，不是官网或控制台地址。')

      this.FormLabel('API 密钥')
      TextInput({ text: this.apiKey, placeholder: 'sk-xxxxxxxx' })
        .height(46)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .type(InputType.Password)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(10)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => this.apiKey = v)
      this.Hint('API Key 不会写入日志，也不会在界面中明文展示。')
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
        Text('还没有添加模型。至少添加一个模型后才能提交。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: 12 })
      } else {
        ForEach(this.models, (m: ProviderModelInput, index: number) => {
          this.ModelRow(m, index)
        }, (m: ProviderModelInput) => m.id)
      }

      Row() {
        TextInput({ text: this.modelId, placeholder: 'deepseek-chat' })
          .layoutWeight(1)
          .height(42)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => this.modelId = v)

        TextInput({ text: this.modelName, placeholder: 'DeepSeek Chat' })
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
        Text('普通 OpenAI Compatible API 通常不需要额外请求头。')
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
  Footer() {
    Row() {
      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.DANGER)
          .layoutWeight(1)
      } else {
        Text('提交后会保存本地配置，并在已连接 Server 时写入 OpenCode 配置和 Auth。')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .layoutWeight(1)
      }

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

  private submit(): void {
    const input = new ProviderConnectInput()
    input.providerId = this.providerId.trim()
    input.displayName = this.displayName.trim()
    input.baseURL = this.baseURL.trim()
    input.apiKey = this.apiKey
    input.models = this.models
    input.headers = this.headers

    if (input.providerId.length === 0) {
      this.errorText = 'Provider ID 不能为空'
      return
    }
    if (!this.isValidProviderId(input.providerId)) {
      this.errorText = 'Provider ID 只能包含小写字母、数字、连字符或下划线'
      return
    }
    if (input.displayName.length === 0) {
      this.errorText = '显示名称不能为空'
      return
    }
    if (input.baseURL.length === 0) {
      this.errorText = '基础 URL 不能为空'
      return
    }
    if (!input.baseURL.startsWith('http://') && !input.baseURL.startsWith('https://')) {
      this.errorText = '基础 URL 必须以 http:// 或 https:// 开头'
      return
    }
    if (input.models.length === 0) {
      this.errorText = '至少需要添加一个模型'
      return
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
