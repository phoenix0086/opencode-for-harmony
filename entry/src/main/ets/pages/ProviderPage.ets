import { CNProvider, CNModel, ProviderHeader } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { Runner } from '../models/Runner'
import { Theme } from '../components/Theme'

/**
 * OpenCode-style Provider / Model settings page.
 *
 * Goals:
 * - Match OpenCode Desktop provider flow: Provider list -> custom provider -> model list.
 * - Persist Base URL, API Key, optional headers and custom models.
 * - Generate usable opencode.json config, not just a preview with missing values.
 */
@Component
export struct ProviderPage {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop activeRunner: Runner | null = null

  @State providers: CNProvider[] = []
  @State activeTab: string = 'providers' // providers | models | config
  @State selectedProviderId: string = ''
  @State statusMsg: string = ''
  @State configOutput: string = ''
  @State isInitialized: boolean = false

  @State editId: string = ''
  @State editName: string = ''
  @State editBaseURL: string = ''
  @State editNpm: string = '@ai-sdk/openai-compatible'
  @State editAuthEnv: string = ''
  @State editApiKey: string = ''
  @State editApiKeyMode: string = 'direct'
  @State editHeaderName: string = ''
  @State editHeaderValue: string = ''
  @State editModelId: string = ''
  @State editModelName: string = ''
  @State defaultModel: string = ''
  @State smallModel: string = ''
  @State searchText: string = ''

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
    if (this.providers.length > 0) {
      this.selectedProviderId = this.providers[0].id
      this.loadProviderForm(this.providers[0])
    }
    this.isInitialized = true
  }

  private refreshProviders(): void {
    this.providers = providerRegistry.getAll()
  }

  private selectedProvider(): CNProvider | undefined {
    for (const p of this.providers) {
      if (p.id === this.selectedProviderId) return p
    }
    return undefined
  }

  private loadProviderForm(p: CNProvider): void {
    this.editId = p.id
    this.editName = p.name
    this.editBaseURL = p.baseURL
    this.editNpm = p.npm.length > 0 ? p.npm : '@ai-sdk/openai-compatible'
    this.editAuthEnv = p.authEnv
    this.editApiKey = p.apiKey
    this.editApiKeyMode = p.apiKeyMode || 'direct'
    this.editHeaderName = ''
    this.editHeaderValue = ''
    this.editModelId = ''
    this.editModelName = ''
  }

  build() {
    Column() {
      this.HeaderBar()

      if (!this.isInitialized) {
        Column() {
          LoadingProgress().width(24).height(24).color(Theme.ACCENT)
        }.justifyContent(FlexAlign.Center).layoutWeight(1)
      } else {
        Row() {
          this.ProviderSidebar()
          Column() {
            this.TabBar()
            if (this.activeTab === 'providers') {
              this.ProviderEditor()
            } else if (this.activeTab === 'models') {
              this.ModelEditor()
            } else {
              this.ConfigPreview()
            }
          }
          .layoutWeight(1)
          .height('100%')
          .backgroundColor(Theme.BG)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Theme.BG)
  }

  @Builder
  HeaderBar() {
    Row() {
      Column() {
        Text('PROVIDERS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
        Text('OpenCode compatible provider / model settings')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('generate opencode.json')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_INVERSE)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .borderRadius(6)
        .backgroundColor(Theme.ACCENT)
        .onClick(() => this.generateConfig())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 12 })
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }

  @Builder
  ProviderSidebar() {
    Column() {
      Text('已连接的提供商')
        .fontSize(Theme.fs.sm)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ bottom: 10 })

      Scroll() {
        Column() {
          ForEach(this.providers, (p: CNProvider) => {
            this.ProviderRow(p)
          }, (p: CNProvider) => p.id)
        }
      }
      .layoutWeight(1)

      Text('+ 自定义提供商')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.ACCENT)
        .fontFamily(Theme.FONT_MONO)
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .borderRadius(6)
        .backgroundColor(Theme.ACTIVE_BG)
        .width('100%')
        .onClick(() => this.createBlankCustomProvider())

      if (this.statusMsg.length > 0) {
        Text(this.statusMsg)
          .fontSize(Theme.fs.xs)
          .fontColor(this.statusMsg.includes('失败') || this.statusMsg.includes('failed') ? Theme.DANGER : Theme.SUCCESS)
          .margin({ top: 12 })
      }
    }
    .width(260)
    .height('100%')
    .padding(16)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth({ right: 1 })
    .borderColor(Theme.BORDER)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProviderRow(p: CNProvider) {
    Row() {
      Column() {
        Text(p.name)
          .fontSize(Theme.fs.sm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedProviderId === p.id ? Theme.TEXT_PRIMARY : Theme.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(p.baseURL.length > 0 ? p.baseURL : 'base url not set')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(p.authStatus === 'configured' ? '✓' : '·')
        .fontSize(Theme.fs.sm)
        .fontColor(p.authStatus === 'configured' ? Theme.SUCCESS : Theme.TEXT_MUTED)
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 10, bottom: 10 })
    .borderRadius(8)
    .backgroundColor(this.selectedProviderId === p.id ? Theme.ACTIVE_BG : 'transparent')
    .margin({ bottom: 6 })
    .onClick(() => {
      this.selectedProviderId = p.id
      this.loadProviderForm(p)
    })
  }

  @Builder
  TabBar() {
    Row() {
      this.TabButton('providers', '提供商')
      this.TabButton('models', '模型')
      this.TabButton('config', '配置预览')
      Blank()
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14 })
  }

  @Builder
  TabButton(id: string, label: string) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(this.activeTab === id ? Theme.TEXT_PRIMARY : Theme.TEXT_MUTED)
      .fontWeight(this.activeTab === id ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(6)
      .backgroundColor(this.activeTab === id ? Theme.ACTIVE_BG : 'transparent')
      .margin({ right: 8 })
      .onClick(() => { this.activeTab = id })
  }

  @Builder
  ProviderEditor() {
    Scroll() {
      Column() {
        Text('自定义 / 编辑提供商')
          .fontSize(Theme.fs.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: 18 })

        this.FormLabel('提供商 ID')
        TextInput({ text: this.editId, placeholder: 'myprovider' })
          .enabled(this.selectedProvider()?.builtIn !== true)
          .height(44)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .onChange((v: string) => { this.editId = v })
        this.Hint('使用小写字母、数字、连字符或下划线，例如 deepseek-cn / myprovider')

        this.FormLabel('显示名称')
        TextInput({ text: this.editName, placeholder: '我的 AI 提供商' })
          .height(44).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
          .onChange((v: string) => { this.editName = v })

        this.FormLabel('基础 URL')
        TextInput({ text: this.editBaseURL, placeholder: 'https://api.myprovider.com/v1' })
          .height(44).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
          .onChange((v: string) => { this.editBaseURL = v })
        this.Hint('OpenAI compatible endpoint，一般以 /v1 或 compatible-mode/v1 结尾')

        this.FormLabel('API 密钥')
        TextInput({ text: this.editApiKey, placeholder: 'sk-...' })
          .height(44).fontSize(Theme.fs.md).fontColor(Theme.TEXT_PRIMARY)
          .type(InputType.Password)
          .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
          .onChange((v: string) => { this.editApiKey = v })
        this.Hint('本地保存，用于生成可直接使用的 OpenCode provider 配置。生产版建议换成 Harmony KeyStore。')

        Row() {
          Text('保存提供商')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_INVERSE)
            .fontWeight(FontWeight.Bold)
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor(Theme.ACCENT)
            .onClick(() => this.saveProvider())

          Text('Save Key Locally')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.ACCENT)
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor(Theme.ACTIVE_BG)
            .margin({ left: 10 })
            .onClick(() => this.saveApiKeyLocal())

          Text('Write Key to Server')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.SUCCESS)
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
            .borderRadius(8)
            .backgroundColor(Theme.SUCCESS_DIM)
            .margin({ left: 10 })
            .onClick(() => this.saveApiKeyToServer())
        }
        .margin({ top: 18, bottom: 20 })

        this.FormLabel('请求头（可选）')
        Row() {
          TextInput({ text: this.editHeaderName, placeholder: 'Header-Name' })
            .layoutWeight(1).height(40).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
            .onChange((v: string) => { this.editHeaderName = v })
          TextInput({ text: this.editHeaderValue, placeholder: 'value' })
            .layoutWeight(1).height(40).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
            .margin({ left: 8 })
            .onChange((v: string) => { this.editHeaderValue = v })
          Text('+ 添加')
            .fontSize(Theme.fs.sm).fontColor(Theme.ACCENT)
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .borderRadius(8).backgroundColor(Theme.ACTIVE_BG).margin({ left: 8 })
            .onClick(() => this.addHeader())
        }
        this.HeaderList()
      }
      .padding(28)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .layoutWeight(1)
  }

  @Builder
  ModelEditor() {
    Scroll() {
      Column() {
        Text('模型')
          .fontSize(Theme.fs.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: 18 })

        Row() {
          TextInput({ text: this.searchText, placeholder: '搜索模型' })
            .layoutWeight(1).height(40).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
            .onChange((v: string) => { this.searchText = v })
        }
        .margin({ bottom: 16 })

        this.FormLabel('添加模型')
        Row() {
          TextInput({ text: this.editModelId, placeholder: 'model-id' })
            .layoutWeight(1).height(40).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
            .onChange((v: string) => { this.editModelId = v })
          TextInput({ text: this.editModelName, placeholder: '显示名称' })
            .layoutWeight(1).height(40).fontSize(Theme.fs.sm).fontColor(Theme.TEXT_PRIMARY)
            .backgroundColor(Theme.INPUT_BG).borderRadius(8).borderWidth(1).borderColor(Theme.BORDER)
            .margin({ left: 8 })
            .onChange((v: string) => { this.editModelName = v })
          Text('+ 添加模型')
            .fontSize(Theme.fs.sm).fontColor(Theme.ACCENT)
            .padding({ left: 12, right: 12, top: 9, bottom: 9 })
            .borderRadius(8).backgroundColor(Theme.ACTIVE_BG).margin({ left: 8 })
            .onClick(() => this.addModel())
        }
        .margin({ bottom: 18 })

        ForEach(this.getModelsForSelectedProvider(), (m: CNModel) => {
          if (this.searchText.length === 0 || m.id.includes(this.searchText) || m.name.includes(this.searchText)) {
            this.ModelRow(this.selectedProviderId, m)
          }
        }, (m: CNModel) => m.id)
      }
      .padding(28)
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .layoutWeight(1)
  }

  private getModelsForSelectedProvider(): CNModel[] {
    const p = this.selectedProvider()
    if (!p) return []
    return p.models
  }

  @Builder
  ModelRow(providerId: string, m: CNModel) {
    Row() {
      Toggle({ type: ToggleType.Switch, isOn: m.enabled !== false })
        .selectedColor(Theme.ACCENT)
        .onChange(async (v: boolean) => {
          await providerRegistry.setModelEnabled(providerId, m.id, v)
          this.refreshProviders()
        })
      Column() {
        Text(m.name.length > 0 ? m.name : m.id)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
        Text(`${providerId}/${m.id}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)
      Text(this.defaultModel === `${providerId}/${m.id}` ? '默认' : '设默认')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.ACCENT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.ACTIVE_BG)
        .onClick(() => {
          this.defaultModel = `${providerId}/${m.id}`
          if (this.smallModel.length === 0) this.smallModel = this.defaultModel
        })
      Text('删除')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .margin({ left: 6 })
        .onClick(() => this.removeModel(providerId, m.id))
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 8 })
  }

  @Builder
  HeaderList() {
    ForEach(this.getHeadersForSelectedProvider(), (h: ProviderHeader) => {
      Row() {
        Text(h.name).fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
        Text(h.value).fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO).margin({ left: 10 })
        Blank()
        Text('删除').fontSize(Theme.fs.xs).fontColor(Theme.DANGER).onClick(() => this.removeHeader(h.name))
      }
      .width('100%')
      .padding(8)
      .backgroundColor(Theme.SIDEBAR)
      .borderRadius(6)
      .margin({ top: 6 })
    }, (h: ProviderHeader) => h.name)
  }

  private getHeadersForSelectedProvider(): ProviderHeader[] {
    const p = this.selectedProvider()
    if (!p) return []
    return p.headers
  }

  @Builder
  ConfigPreview() {
    Scroll() {
      Column() {
        Text('配置预览')
          .fontSize(Theme.fs.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: 14 })
        Text('生成的 opencode.json 可以复制到 OpenCode 配置中。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: 16 })
        Text(this.configOutput.length > 0 ? this.configOutput : providerRegistry.generatePreviewConfig(this.defaultModel, this.smallModel))
          .fontSize(Theme.fs.code)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.PANEL)
          .padding(16)
          .borderRadius(8)
          .width('100%')
      }
      .padding(28)
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
  }

  @Builder
  FormLabel(label: string) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(Theme.TEXT_SECONDARY)
      .fontWeight(FontWeight.Medium)
      .margin({ top: 14, bottom: 6 })
  }

  @Builder
  Hint(text: string) {
    Text(text)
      .fontSize(Theme.fs.xs)
      .fontColor(Theme.TEXT_MUTED)
      .margin({ top: 5, bottom: 2 })
  }

  private async createBlankCustomProvider(): Promise<void> {
    let index = 1
    let id = `custom-provider-${index}`
    while (providerRegistry.getById(id)) {
      index += 1
      id = `custom-provider-${index}`
    }
    await providerRegistry.createCustomProvider(id, `自定义提供商 ${index}`, '', '', '')
    this.refreshProviders()
    this.selectedProviderId = id
    const p = this.selectedProvider()
    if (p) this.loadProviderForm(p)
    this.activeTab = 'providers'
  }

  private async saveProvider(): Promise<void> {
    if (this.editId.length === 0) {
      this.statusMsg = '提供商 ID 不能为空'
      return
    }
    if (!providerRegistry.getById(this.editId)) {
      const ok = await providerRegistry.createCustomProvider(this.editId, this.editName, this.editBaseURL, this.editApiKey, this.editModelId)
      this.statusMsg = ok ? '已创建提供商' : '创建失败：ID 已存在'
    } else {
      const ok = await providerRegistry.setProviderConfig(this.editId, this.editName, this.editBaseURL, this.editNpm, this.editAuthEnv)
      this.statusMsg = ok ? '已保存提供商' : '保存失败'
    }
    this.refreshProviders()
  }

  private async saveApiKeyLocal(): Promise<void> {
    const ok = await providerRegistry.setApiKey(this.selectedProviderId, this.editApiKey, this.editApiKeyMode)
    this.statusMsg = ok ? 'API Key saved locally' : 'Local save failed'
    this.refreshProviders()
  }

  private async saveApiKeyToServer(): Promise<void> {
    if (this.activeRunner === null) {
      this.statusMsg = 'Connect to OpenCode Server first'
      return
    }

    if (this.selectedProviderId.length === 0) {
      this.statusMsg = 'Select a provider first'
      return
    }

    if (this.editApiKey.length === 0) {
      this.statusMsg = 'API Key is empty'
      return
    }

    try {
      const client = new OpenCodeClient(this.activeRunner)
      const ok = await client.setAuth(this.selectedProviderId, this.editApiKey)

      if (!ok) {
        this.statusMsg = 'Server auth failed'
        return
      }

      const providerList = await client.listProviders()
      let connected = false
      for (const id of providerList.connected) {
        if (id === this.selectedProviderId) {
          connected = true
          break
        }
      }

      await providerRegistry.setApiKey(this.selectedProviderId, this.editApiKey, this.editApiKeyMode)
      this.statusMsg = connected ? 'API Key written to server' : 'Key saved, but provider not reported as connected'
      this.refreshProviders()
    } catch (e) {
      this.statusMsg = `Server auth failed: ${String(e)}`
    }
  }

  private async addHeader(): Promise<void> {
    const ok = await providerRegistry.addOrUpdateHeader(this.selectedProviderId, this.editHeaderName, this.editHeaderValue)
    this.statusMsg = ok ? '请求头已保存' : '请求头保存失败'
    this.editHeaderName = ''
    this.editHeaderValue = ''
    this.refreshProviders()
  }

  private async removeHeader(name: string): Promise<void> {
    await providerRegistry.removeHeader(this.selectedProviderId, name)
    this.refreshProviders()
  }

  private async addModel(): Promise<void> {
    const ok = await providerRegistry.addOrUpdateModel(this.selectedProviderId, this.editModelId, this.editModelName, true)
    this.statusMsg = ok ? '模型已添加' : '模型添加失败'
    this.editModelId = ''
    this.editModelName = ''
    this.refreshProviders()
  }

  private async removeModel(providerId: string, modelId: string): Promise<void> {
    await providerRegistry.removeModel(providerId, modelId)
    this.refreshProviders()
  }

  private generateConfig(): void {
    this.configOutput = providerRegistry.generateConfigWithSecrets(this.defaultModel, this.smallModel)
    this.activeTab = 'config'
    this.statusMsg = '配置已生成（含密钥）'
  }
}
