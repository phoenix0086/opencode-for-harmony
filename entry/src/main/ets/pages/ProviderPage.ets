import { CNProvider, CNModel, ProviderHeader } from '../models/Provider'
import { http } from '@kit.NetworkKit'
import { providerRegistry } from '../services/ProviderRegistry'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { Runner } from '../models/Runner'
import { Theme } from '../components/Theme'
import { TestConnectionResult } from '../services/ProviderConnectionService'

/**
 * OpenCode-style Provider / Model settings page.
 *
 * Clean layout: provider list in main area, click to open edit dialog.
 * No default providers — start with an empty list.
 */
@Component
@Entry
export struct ProviderPage {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop activeRunner: Runner | null = null

  @State providers: CNProvider[] = []
  @State isInitialized: boolean = false
  @State statusMsg: string = ''
  @State configOutput: string = ''

  // Dialog state
  @State showEditDialog: boolean = false
  @State isNewProvider: boolean = false
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

  // Test & fetch state
  @State testing: boolean = false
  @State testResult: TestConnectionResult | null = null
  @State fetchingModels: boolean = false

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
    this.isInitialized = true
  }

  private refreshProviders(): void {
    this.providers = providerRegistry.getAll()
  }

  private getEditingProvider(): CNProvider | undefined {
    for (const p of this.providers) {
      if (p.id === this.editId) return p
    }
    return undefined
  }

  private openNewProviderDialog(): void {
    this.isNewProvider = true
    this.editId = ''
    this.editName = ''
    this.editBaseURL = ''
    this.editNpm = '@ai-sdk/openai-compatible'
    this.editAuthEnv = ''
    this.editApiKey = ''
    this.editApiKeyMode = 'direct'
    this.editHeaderName = ''
    this.editHeaderValue = ''
    this.editModelId = ''
    this.editModelName = ''
    this.testResult = null
    this.testing = false
    this.fetchingModels = false
    this.showEditDialog = true
  }

  private openEditDialog(p: CNProvider): void {
    this.isNewProvider = false
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
    this.testResult = null
    this.testing = false
    this.fetchingModels = false
    this.showEditDialog = true
  }

  build() {
    Stack() {
      Column() {
        this.HeaderBar()

        if (!this.isInitialized) {
          Column() {
            LoadingProgress().width(24).height(24).color(Theme.ACCENT)
          }
          .justifyContent(FlexAlign.Center)
          .layoutWeight(1)
          .width('100%')
        } else {
          this.ProviderList()
        }
      }
      .width('100%')
      .height('100%')

      if (this.showEditDialog) {
        this.EditDialogOverlay()
      }

      if (this.showConfigDialog) {
        this.ConfigDialogOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ══════════════════════════════════════════════════
  //  Header
  // ══════════════════════════════════════════════════

  @Builder
  HeaderBar() {
    Row() {
      Text('提供商管理')
        .fontSize(Theme.fs.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)

      Blank()

      Text('配置预览')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_SECONDARY)
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.ACTIVE_BG)
        .onClick(() => this.generateConfig())

      Text('+ 添加提供商')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_INVERSE)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(8)
        .backgroundColor(Theme.ACCENT)
        .margin({ left: 12 })
        .onClick(() => this.openNewProviderDialog())
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 12 })
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }

  // ══════════════════════════════════════════════════
  //  Provider List (main content)
  // ══════════════════════════════════════════════════

  @Builder
  ProviderList() {
    if (this.providers.length === 0) {
      // Empty state
      Column() {
        Text('还没有配置任何提供商')
          .fontSize(Theme.fs.lg)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: 8 })

        Text('点击右上角 "+ 添加提供商" 开始配置')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List() {
        ForEach(this.providers, (p: CNProvider) => {
          ListItem() {
            this.ProviderCard(p)
          }
        }, (p: CNProvider) => p.id)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 24, right: 24, top: 16 })
      .divider({ strokeWidth: 0 })
    }

    if (this.statusMsg.length > 0) {
      Text(this.statusMsg)
        .fontSize(Theme.fs.xs)
        .fontColor(this.statusMsg.includes('失败') || this.statusMsg.includes('failed') ? Theme.DANGER : Theme.SUCCESS)
        .padding({ left: 24, right: 24, bottom: 12 })
    }
  }

  @Builder
  ProviderCard(p: CNProvider) {
    Row() {
      Column() {
        Text(p.name.length > 0 ? p.name : p.id)
          .fontSize(Theme.fs.md)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (p.baseURL.length > 0) {
          Text(p.baseURL)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 4 })
        }

        if (p.models.length > 0) {
          Text(`${p.models.length} 个模型`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // Auth status badge
      Text(p.authStatus === 'configured' ? '已配置' : '未配置')
        .fontSize(Theme.fs.xs)
        .fontColor(p.authStatus === 'configured' ? Theme.SUCCESS : Theme.TEXT_MUTED)
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .borderRadius(4)
        .backgroundColor(p.authStatus === 'configured' ? Theme.SUCCESS_DIM : Theme.ACTIVE_BG)
    }
    .width('100%')
    .padding(16)
    .borderRadius(10)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 10 })
    .onClick(() => this.openEditDialog(p))
  }

  // ══════════════════════════════════════════════════
  //  Edit Dialog
  // ══════════════════════════════════════════════════

  @Builder
  EditDialogOverlay() {
    Stack() {
      // Backdrop
      Rect()
        .fill('rgba(0,0,0,0.5)')
        .width('100%')
        .height('100%')
        .onClick(() => { this.showEditDialog = false })

      // Dialog content
      Column() {
        // Dialog header
        Row() {
          Text(this.isNewProvider ? '添加提供商' : '编辑提供商')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
          Blank()
          Text('✕')
            .fontSize(Theme.fs.lg)
            .fontColor(Theme.TEXT_MUTED)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .onClick(() => { this.showEditDialog = false })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 12 })

        Scroll() {
          Column() {
            // Provider ID
            this.FormLabel('提供商 ID')
            TextInput({ text: this.editId, placeholder: 'my-provider' })
              .enabled(this.isNewProvider)
              .height(44)
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_PRIMARY)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(8)
              .borderWidth(1)
              .borderColor(Theme.BORDER)
              .onChange((v: string) => { this.editId = v })
            this.Hint('小写字母、数字、连字符，例如 deepseek / my-provider')

            // Display Name
            this.FormLabel('显示名称')
            TextInput({ text: this.editName, placeholder: '我的 AI 提供商' })
              .height(44)
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_PRIMARY)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(8)
              .borderWidth(1)
              .borderColor(Theme.BORDER)
              .onChange((v: string) => { this.editName = v })

            // Base URL
            this.FormLabel('基础 URL')
            TextInput({ text: this.editBaseURL, placeholder: 'https://api.example.com/v1' })
              .height(44)
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_PRIMARY)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(8)
              .borderWidth(1)
              .borderColor(Theme.BORDER)
              .onChange((v: string) => { this.editBaseURL = v })
            this.Hint('OpenAI 兼容端点，一般以 /v1 结尾')

            // API Key
            this.FormLabel('API 密钥')
            TextInput({ text: this.editApiKey, placeholder: 'sk-...' })
              .height(44)
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_PRIMARY)
              .type(InputType.Password)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(8)
              .borderWidth(1)
              .borderColor(Theme.BORDER)
              .onChange((v: string) => { this.editApiKey = v })

            // Action buttons
            Row() {
              Text(this.testing ? '测试中...' : '测试连接')
                .fontSize(Theme.fs.sm)
                .fontColor(this.testing ? Theme.TEXT_MUTED : Theme.TEXT_PRIMARY)
                .fontWeight(FontWeight.Medium)
                .padding({ left: 18, right: 18, top: 10, bottom: 10 })
                .borderRadius(8)
                .backgroundColor(this.testing ? Theme.PANEL : Theme.SIDEBAR)
                .borderWidth(1)
                .borderColor(Theme.BORDER)
                .onClick(() => this.testProvider())

              Blank()

              Text('保存')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_INVERSE)
                .fontWeight(FontWeight.Bold)
                .padding({ left: 24, right: 24, top: 10, bottom: 10 })
                .borderRadius(8)
                .backgroundColor(Theme.ACCENT)
                .onClick(() => this.saveProvider())

              if (!this.isNewProvider) {
                Text('删除')
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.DANGER)
                  .padding({ left: 18, right: 18, top: 10, bottom: 10 })
                  .borderRadius(8)
                  .backgroundColor(Theme.DANGER_DIM)
                  .margin({ left: 8 })
                  .onClick(() => this.deleteProvider())
              }
            }
            .width('100%')
            .margin({ top: 20, bottom: 12 })

            // Test result
            if (this.testResult !== null) {
              this.TestResultBlock()
            }

            // ── Models section ──
            Divider().color(Theme.BORDER).margin({ top: 16, bottom: 16 })

            Row() {
              Text('模型')
                .fontSize(Theme.fs.md)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.TEXT_PRIMARY)
              Blank()
              Text(this.fetchingModels ? '获取中...' : '获取模型列表')
                .fontSize(Theme.fs.xs)
                .fontColor(this.fetchingModels ? Theme.TEXT_MUTED : Theme.ACCENT)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(6)
                .backgroundColor(Theme.ACTIVE_BG)
                .onClick(() => this.fetchModels())
            }
            .width('100%')

            // Model list
            if (!this.isNewProvider) {
              ForEach(this.getDialogModels(), (m: CNModel) => {
                this.ModelRow(m)
              }, (m: CNModel) => m.id)
            }

            // Add model row
            Row() {
              TextInput({ text: this.editModelId, placeholder: 'model-id' })
                .layoutWeight(1)
                .height(38)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG)
                .borderRadius(8)
                .borderWidth(1)
                .borderColor(Theme.BORDER)
                .onChange((v: string) => { this.editModelId = v })
              TextInput({ text: this.editModelName, placeholder: '显示名称（可选）' })
                .layoutWeight(1)
                .height(38)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG)
                .borderRadius(8)
                .borderWidth(1)
                .borderColor(Theme.BORDER)
                .margin({ left: 8 })
                .onChange((v: string) => { this.editModelName = v })
              Text('+')
                .fontSize(Theme.fs.md)
                .fontColor(Theme.ACCENT)
                .width(38)
                .height(38)
                .textAlign(TextAlign.Center)
                .borderRadius(8)
                .backgroundColor(Theme.ACTIVE_BG)
                .margin({ left: 8 })
                .onClick(() => this.addModel())
            }
            .width('100%')
            .margin({ top: 12, bottom: 8 })

            // ── Headers section ──
            Divider().color(Theme.BORDER).margin({ top: 16, bottom: 16 })

            Text('自定义请求头（可选）')
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_SECONDARY)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 8 })

            Row() {
              TextInput({ text: this.editHeaderName, placeholder: 'Header-Name' })
                .layoutWeight(1)
                .height(38)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG)
                .borderRadius(8)
                .borderWidth(1)
                .borderColor(Theme.BORDER)
                .onChange((v: string) => { this.editHeaderName = v })
              TextInput({ text: this.editHeaderValue, placeholder: 'value' })
                .layoutWeight(1)
                .height(38)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .backgroundColor(Theme.INPUT_BG)
                .borderRadius(8)
                .borderWidth(1)
                .borderColor(Theme.BORDER)
                .margin({ left: 8 })
                .onChange((v: string) => { this.editHeaderValue = v })
              Text('+')
                .fontSize(Theme.fs.md)
                .fontColor(Theme.ACCENT)
                .width(38)
                .height(38)
                .textAlign(TextAlign.Center)
                .borderRadius(8)
                .backgroundColor(Theme.ACTIVE_BG)
                .margin({ left: 8 })
                .onClick(() => this.addHeader())
            }
            .width('100%')

            this.HeaderList()

            Blank().height(24)
          }
          .width('100%')
          .padding({ left: 24, right: 24 })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
      }
      .width(560)
      .height('85%')
      .borderRadius(16)
      .backgroundColor(Theme.BG)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TestResultBlock() {
    Column() {
      Row() {
        Text(this.testResult!.ok ? '✓ 连接成功' : '✗ 连接失败')
          .fontSize(Theme.fs.sm)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.testResult!.ok ? Theme.SUCCESS : Theme.DANGER)

        Blank()

        Text(`${this.testResult!.latencyMs}ms`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .width('100%')

      if (this.testResult!.ok && this.testResult!.responsePreview.length > 0) {
        Text(`已自动获取 ${this.testResult!.responsePreview} 个模型`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.SUCCESS)
          .margin({ top: 4 })
      }

      if (!this.testResult!.ok && this.testResult!.error.length > 0) {
        Text(this.testResult!.error)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.testResult!.ok ? Theme.SUCCESS_DIM : Theme.DANGER_DIM)
    .borderWidth(1)
    .borderColor(this.testResult!.ok ? Theme.SUCCESS : Theme.DANGER)
  }

  @Builder
  ModelRow(m: CNModel) {
    Row() {
      Toggle({ type: ToggleType.Switch, isOn: m.enabled !== false })
        .selectedColor(Theme.ACCENT)
        .onChange(async (v: boolean) => {
          await providerRegistry.setModelEnabled(this.editId, m.id, v)
          this.refreshProviders()
        })

      Column() {
        Text(m.name.length > 0 ? m.name : m.id)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
        Text(m.id)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Text(this.defaultModel === `${this.editId}/${m.id}` ? '默认' : '设默认')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.ACCENT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.ACTIVE_BG)
        .onClick(() => {
          this.defaultModel = `${this.editId}/${m.id}`
          if (this.smallModel.length === 0) this.smallModel = this.defaultModel
        })

      Text('删除')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .margin({ left: 6 })
        .onClick(() => this.removeModel(m.id))
    }
    .width('100%')
    .padding(10)
    .borderRadius(8)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ top: 8 })
  }

  @Builder
  HeaderList() {
    ForEach(this.getEditingHeaders(), (h: ProviderHeader) => {
      Row() {
        Text(h.name)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
        Text(providerRegistry.maskApiKey(h.value))
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: 10 })
        Blank()
        Text('删除')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .onClick(() => this.removeHeader(h.name))
      }
      .width('100%')
      .padding(8)
      .backgroundColor(Theme.SIDEBAR)
      .borderRadius(6)
      .margin({ top: 6 })
    }, (h: ProviderHeader) => h.name)
  }

  // ══════════════════════════════════════════════════
  //  Config Preview Dialog
  // ══════════════════════════════════════════════════

  @State showConfigDialog: boolean = false

  @Builder
  ConfigDialogOverlay() {
    Stack() {
      Rect()
        .fill('rgba(0,0,0,0.5)')
        .width('100%')
        .height('100%')
        .onClick(() => { this.showConfigDialog = false })

      Column() {
        Row() {
          Text('配置预览')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
          Blank()
          Text('✕')
            .fontSize(Theme.fs.lg)
            .fontColor(Theme.TEXT_MUTED)
            .width(36)
            .height(36)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .onClick(() => { this.showConfigDialog = false })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 20, bottom: 12 })

        Text('生成的 opencode.json 可以复制到 OpenCode 配置中。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .padding({ left: 24, right: 24 })
          .margin({ bottom: 12 })

        Scroll() {
          Text(this.configOutput)
            .fontSize(Theme.fs.code)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .padding(16)
            .width('100%')
        }
        .layoutWeight(1)
        .padding({ left: 24, right: 24, bottom: 24 })
      }
      .width(600)
      .height('70%')
      .borderRadius(16)
      .backgroundColor(Theme.BG)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
    }
    .width('100%')
    .height('100%')
  }

  // ══════════════════════════════════════════════════
  //  Shared Builders
  // ══════════════════════════════════════════════════

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
      .margin({ top: 4, bottom: 2 })
  }

  // ══════════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════════

  private getDialogModels(): CNModel[] {
    const p = this.getEditingProvider()
    if (!p) return []
    return p.models
  }

  private getEditingHeaders(): ProviderHeader[] {
    const p = this.getEditingProvider()
    if (!p) return []
    return p.headers
  }

  // ══════════════════════════════════════════════════
  //  Actions
  // ══════════════════════════════════════════════════

  private async saveProvider(): Promise<void> {
    if (this.editId.length === 0) {
      this.statusMsg = '提供商 ID 不能为空'
      return
    }

    const existing = providerRegistry.getById(this.editId)
    if (!existing) {
      const ok = await providerRegistry.createCustomProvider(
        this.editId, this.editName, this.editBaseURL, this.editApiKey, this.editModelId
      )
      if (!ok) {
        this.statusMsg = '创建失败：ID 已存在'
        return
      }
      this.statusMsg = '已创建提供商'
    } else {
      const ok = await providerRegistry.setProviderConfig(
        this.editId, this.editName, this.editBaseURL, this.editNpm, this.editAuthEnv
      )
      if (!ok) {
        this.statusMsg = '保存失败'
        return
      }
      // Also save API key if changed
      if (this.editApiKey.length > 0) {
        await providerRegistry.setApiKey(this.editId, this.editApiKey, this.editApiKeyMode)
      }
      this.statusMsg = '已保存提供商'
    }

    this.refreshProviders()
    this.showEditDialog = false
  }

  private async deleteProvider(): Promise<void> {
    if (this.editId.length === 0) return
    await providerRegistry.removeProvider(this.editId)
    this.refreshProviders()
    this.showEditDialog = false
    this.statusMsg = '已删除提供商'
  }

  private async testProvider(): Promise<void> {
    if (this.testing) return
    if (this.editBaseURL.length === 0) {
      this.statusMsg = '请先填写基础 URL'
      return
    }
    if (this.editApiKey.length === 0) {
      this.statusMsg = '请先填写 API 密钥'
      return
    }

    this.testing = true
    this.testResult = null
    this.statusMsg = ''

    let url = this.editBaseURL
    if (url.endsWith('/v1')) {
      url = url + '/models'
    } else if (url.endsWith('/v1/')) {
      url = url + 'models'
    } else {
      if (!url.endsWith('/')) url += '/'
      url = url + 'v1/models'
    }

    const headers: Record<string, string> = {}
    headers['Authorization'] = `Bearer ${this.editApiKey}`
    headers['Content-Type'] = 'application/json'

    const startTime = Date.now()

    try {
      const req = http.createHttp()
      const resp = await req.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        connectTimeout: 8000,
        readTimeout: 15000
      })
      req.destroy()

      const result = new TestConnectionResult()
      result.latencyMs = Date.now() - startTime

      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        result.ok = true
        const raw = resp.result as string
        let modelCount = 0
        try {
          const data = JSON.parse(raw) as Record<string, Object>
          const arr = data['data'] as Array<Record<string, Object>>
          if (arr !== undefined) {
            modelCount = arr.length
            // Auto-save provider first if it's new
            if (this.isNewProvider && this.editId.length > 0) {
              await this.saveProviderSilently()
            }
            // Save models to provider
            for (const item of arr) {
              const modelId = item['id'] as string
              if (modelId !== undefined && modelId.length > 0) {
                await providerRegistry.addOrUpdateModel(this.editId, modelId, modelId, true)
              }
            }
            this.refreshProviders()
          }
        } catch (e) {
          // parse error, still connected
        }
        result.responsePreview = `${modelCount}`
        this.statusMsg = `测试通过，已获取 ${modelCount} 个模型`
      } else {
        result.ok = false
        try {
          const raw = resp.result as string
          const errData = JSON.parse(raw) as Record<string, Object>
          const errObj = errData['error'] as Record<string, string>
          if (errObj !== undefined && errObj['message'] !== undefined) {
            result.error = errObj['message']
          } else {
            result.error = `HTTP ${resp.responseCode}`
          }
        } catch (e) {
          result.error = `HTTP ${resp.responseCode}`
        }
        this.statusMsg = `测试失败: ${result.error}`
      }
      this.testResult = result
    } catch (e) {
      const result = new TestConnectionResult()
      result.ok = false
      result.latencyMs = Date.now() - startTime
      result.error = String(e)
      this.testResult = result
      this.statusMsg = `测试失败: ${String(e)}`
    }

    this.testing = false
  }

  private async fetchModels(): Promise<void> {
    if (this.fetchingModels) return
    if (this.editBaseURL.length === 0) {
      this.statusMsg = '请先填写基础 URL'
      return
    }
    if (this.editApiKey.length === 0) {
      this.statusMsg = '请先填写 API 密钥'
      return
    }

    this.fetchingModels = true
    this.statusMsg = ''

    let url = this.editBaseURL
    if (url.endsWith('/v1')) {
      url = url + '/models'
    } else if (url.endsWith('/v1/')) {
      url = url + 'models'
    } else {
      if (!url.endsWith('/')) url += '/'
      url = url + 'v1/models'
    }

    const headers: Record<string, string> = {}
    headers['Authorization'] = `Bearer ${this.editApiKey}`
    headers['Content-Type'] = 'application/json'

    try {
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
        let count = 0
        try {
          const data = JSON.parse(raw) as Record<string, Object>
          const arr = data['data'] as Array<Record<string, Object>>
          if (arr !== undefined) {
            for (const item of arr) {
              const modelId = item['id'] as string
              if (modelId !== undefined && modelId.length > 0) {
                await providerRegistry.addOrUpdateModel(this.editId, modelId, modelId, true)
                count++
              }
            }
            this.refreshProviders()
          }
        } catch (e) {
          this.statusMsg = '解析模型列表失败'
        }
        this.statusMsg = `已获取 ${count} 个模型`
      } else {
        this.statusMsg = `获取模型失败: HTTP ${resp.responseCode}`
      }
    } catch (e) {
      this.statusMsg = `获取模型失败: ${String(e)}`
    }

    this.fetchingModels = false
  }

  /** Save provider silently without closing dialog (used during test) */
  private async saveProviderSilently(): Promise<void> {
    if (this.editId.length === 0) return
    const existing = providerRegistry.getById(this.editId)
    if (!existing) {
      await providerRegistry.createCustomProvider(
        this.editId, this.editName, this.editBaseURL, this.editApiKey, ''
      )
      this.isNewProvider = false
    } else {
      await providerRegistry.setProviderConfig(
        this.editId, this.editName, this.editBaseURL, this.editNpm, this.editAuthEnv
      )
      if (this.editApiKey.length > 0) {
        await providerRegistry.setApiKey(this.editId, this.editApiKey, this.editApiKeyMode)
      }
    }
    this.refreshProviders()
  }

  private async addModel(): Promise<void> {
    if (this.editModelId.length === 0) {
      this.statusMsg = '模型 ID 不能为空'
      return
    }
    // Auto-save provider if new
    if (this.isNewProvider) {
      await this.saveProviderSilently()
    }
    const ok = await providerRegistry.addOrUpdateModel(this.editId, this.editModelId, this.editModelName, true)
    this.statusMsg = ok ? '模型已添加' : '模型添加失败'
    this.editModelId = ''
    this.editModelName = ''
    this.refreshProviders()
  }

  private async removeModel(modelId: string): Promise<void> {
    await providerRegistry.removeModel(this.editId, modelId)
    this.refreshProviders()
  }

  private async addHeader(): Promise<void> {
    if (this.editHeaderName.length === 0) {
      this.statusMsg = '请求头名称不能为空'
      return
    }
    if (this.isNewProvider) {
      await this.saveProviderSilently()
    }
    const ok = await providerRegistry.addOrUpdateHeader(this.editId, this.editHeaderName, this.editHeaderValue)
    this.statusMsg = ok ? '请求头已保存' : '请求头保存失败'
    this.editHeaderName = ''
    this.editHeaderValue = ''
    this.refreshProviders()
  }

  private async removeHeader(name: string): Promise<void> {
    await providerRegistry.removeHeader(this.editId, name)
    this.refreshProviders()
  }

  private generateConfig(): void {
    this.configOutput = providerRegistry.generatePreviewConfig(this.defaultModel, this.smallModel)
    this.showConfigDialog = true
  }
}
