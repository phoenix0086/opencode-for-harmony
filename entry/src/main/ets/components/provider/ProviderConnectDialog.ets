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
    if (this.template !== null) {
      this.providerId = this.template.id === 'custom-openai-compatible' ? '' : this.template.id
      this.displayName = this.template.id === 'custom-openai-compatible' ? '' : this.template.name
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
  }

  build() {
    if (this.visible) {
      Stack() {
        Rect()
          .fill('rgba(0,0,0,0.42)')
          .width('100%')
          .height('100%')
          .onClick(() => this.onCancel())

        Column() {
          Row() {
            Text('←').fontSize(24).fontColor(Theme.TEXT_MUTED).width(42).onClick(() => this.onCancel())
            Blank()
            Text('×').fontSize(28).fontColor(Theme.TEXT_MUTED).width(42).textAlign(TextAlign.Center).onClick(() => this.onCancel())
          }
          .width('100%')
          .height(52)

          Scroll() {
            Column() {
              Row() {
                Text('✦').fontSize(26).fontColor(Theme.TEXT_PRIMARY).width(48)
                Text('自定义提供商').fontSize(26).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_PRIMARY)
              }
              .margin({ bottom: 24 })

              Text('配置与 OpenAI 兼容的提供商。请填写基础 URL、API 密钥和模型列表。')
                .fontSize(Theme.fs.md).fontColor(Theme.TEXT_SECONDARY).margin({ bottom: 28 })

              this.FormLabel('提供商 ID')
              TextInput({ text: this.providerId, placeholder: 'myprovider' })
                .height(48).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG).borderRadius(10).borderWidth(1).borderColor(Theme.BORDER)
                .onChange((v: string) => this.providerId = v)
              this.Hint('使用小写字母、数字、连字符或下划线')

              this.FormLabel('显示名称')
              TextInput({ text: this.displayName, placeholder: '我的 AI 提供商' })
                .height(48).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG).borderRadius(10).borderWidth(1).borderColor(Theme.BORDER)
                .onChange((v: string) => this.displayName = v)

              this.FormLabel('基础 URL')
              TextInput({ text: this.baseURL, placeholder: 'https://api.myprovider.com/v1' })
                .height(48).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG).borderRadius(10).borderWidth(1).borderColor(Theme.BORDER)
                .onChange((v: string) => this.baseURL = v)
              this.Hint('填写 OpenAI Compatible API 的 Base URL，不是官网或控制台地址')

              this.FormLabel('API 密钥')
              TextInput({ text: this.apiKey, placeholder: 'API 密钥' })
                .height(48).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
                .type(InputType.Password)
                .backgroundColor(Theme.INPUT_BG).borderRadius(10).borderWidth(1).borderColor(Theme.BORDER)
                .onChange((v: string) => this.apiKey = v)
              this.Hint('可选。如果通过请求头管理认证，可留空。不会写入日志。')

              this.FormLabel('模型')
              Row() {
                TextInput({ text: this.modelId, placeholder: 'model-id' })
                  .layoutWeight(1).height(44).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
                  .onChange((v: string) => this.modelId = v)
                TextInput({ text: this.modelName, placeholder: '显示名称' })
                  .layoutWeight(1).height(44).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
                  .margin({ left: 10 })
                  .onChange((v: string) => this.modelName = v)
                Text('+').fontSize(22).fontColor(Theme.ACCENT).width(44).height(44).textAlign(TextAlign.Center)
                  .borderRadius(8).backgroundColor(Theme.ACTIVE_BG).margin({ left: 10 }).onClick(() => this.addModel())
              }
              .margin({ bottom: 10 })

              ForEach(this.models, (m: ProviderModelInput, index: number) => {
                this.ModelRow(m, index)
              }, (m: ProviderModelInput) => m.id)

              this.FormLabel('请求头（可选）')
              Row() {
                TextInput({ text: this.headerName, placeholder: 'Header-Name' })
                  .layoutWeight(1).height(44).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
                  .onChange((v: string) => this.headerName = v)
                TextInput({ text: this.headerValue, placeholder: 'value' })
                  .layoutWeight(1).height(44).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
                  .type(InputType.Password)
                  .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
                  .margin({ left: 10 })
                  .onChange((v: string) => this.headerValue = v)
                Text('+').fontSize(22).fontColor(Theme.ACCENT).width(44).height(44).textAlign(TextAlign.Center)
                  .borderRadius(8).backgroundColor(Theme.ACTIVE_BG).margin({ left: 10 }).onClick(() => this.addHeader())
              }
              .margin({ bottom: 10 })

              ForEach(this.headers, (h: ProviderHeaderInput, index: number) => {
                this.HeaderRow(h, index)
              }, (h: ProviderHeaderInput) => h.name)

              if (this.errorText.length > 0) {
                Text(this.errorText).fontSize(Theme.fs.sm).fontColor(Theme.DANGER).margin({ top: 18 })
              }

              Row() {
                Text('提交')
                  .fontSize(Theme.fs.md).fontWeight(FontWeight.Bold).fontColor(Theme.TEXT_INVERSE)
                  .padding({ left: 28, right: 28, top: 12, bottom: 12 })
                  .borderRadius(10).backgroundColor(Theme.ACCENT).onClick(() => this.submit())
              }
              .width('100%').margin({ top: 32, bottom: 24 })
            }
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 38, right: 38, bottom: 30 })
          }
          .layoutWeight(1)
        }
        .width('68%').height('86%').borderRadius(16).backgroundColor(Theme.BG)
        .borderWidth(1).borderColor(Theme.BORDER)
        .shadow({ radius: 24, color: '#66000000', offsetX: 0, offsetY: 12 })
      }
      .width('100%')
      .height('100%')
    }
  }

  @Builder
  FormLabel(text: string) {
    Text(text).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_MUTED).fontWeight(FontWeight.Bold).margin({ top: 16, bottom: 8 })
  }

  @Builder
  Hint(text: string) {
    Text(text).fontSize(Theme.fs.xs).fontColor(Theme.TEXT_SECONDARY).margin({ top: 6, bottom: 6 })
  }

  @Builder
  ModelRow(m: ProviderModelInput, index: number) {
    Row() {
      Text(m.id).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO).layoutWeight(1)
      Text(m.name.length > 0 ? m.name : m.id).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_MUTED).layoutWeight(1)
      Text('删除').fontSize(Theme.fs.xs).fontColor(Theme.DANGER).onClick(() => this.removeModel(index))
    }
    .width('100%').padding(10).borderRadius(8).backgroundColor(Theme.SIDEBAR).margin({ bottom: 6 })
  }

  @Builder
  HeaderRow(h: ProviderHeaderInput, index: number) {
    Row() {
      Text(h.name).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO).layoutWeight(1)
      Text('••••').fontSize(Theme.fs.sm).fontColor(Theme.TEXT_MUTED).layoutWeight(1)
      Text('删除').fontSize(Theme.fs.xs).fontColor(Theme.DANGER).onClick(() => this.removeHeader(index))
    }
    .width('100%').padding(10).borderRadius(8).backgroundColor(Theme.SIDEBAR).margin({ bottom: 6 })
  }

  private addModel(): void {
    if (this.modelId.length === 0) {
      this.errorText = 'Model ID 不能为空'
      return
    }
    for (const item of this.models) {
      if (item.id === this.modelId) {
        this.errorText = 'Model ID 不能重复'
        return
      }
    }
    const m = new ProviderModelInput()
    m.id = this.modelId
    m.name = this.modelName.length > 0 ? this.modelName : this.modelId
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
    if (this.headerName.length === 0) return
    const h = new ProviderHeaderInput()
    h.name = this.headerName
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
    if (input.displayName.length === 0) {
      this.errorText = '显示名称不能为空'
      return
    }
    if (input.baseURL.length === 0) {
      this.errorText = '基础 URL 不能为空'
      return
    }
    if (input.models.length === 0) {
      this.errorText = '至少需要添加一个模型'
      return
    }

    this.errorText = ''
    this.onSubmit(input)
  }
}
