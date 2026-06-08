import { Theme } from '../components/Theme'
import { Runner } from '../models/Runner'
import { CNProvider } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { providerConnectionService, ProviderConnectInput, ProviderModelInput, ProviderConnectResult } from '../services/ProviderConnectionService'
import { ProviderCard } from '../components/provider/ProviderCard'
import { ProviderConnectDialog } from '../components/provider/ProviderConnectDialog'

@Component
export struct ProviderSettingsPage {
  @Prop @Watch('onRunnerChanged') activeRunner: Runner | null = null
  onOpenModels: () => void = () => {}

  @State providers: CNProvider[] = []
  @State showDialog: boolean = false
  @State statusMsg: string = ''
  @State connecting: boolean = false
  @State mimoSynced: boolean = false  // 防止重复推送

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    // 自动预置小米 MiMo 供应商（不存在时才创建）
    await this.ensureXiaomiMimo()
    this.providers = providerRegistry.getAll()
  }

  private async ensureXiaomiMimo(): Promise<void> {
    // 已存在则跳过（避免重复创建）
    if (providerRegistry.getById('xiaomi-mimo')) {
      // 存在但可能未同步到 Server，尝试推送
      await this.syncXiaomiMimoToServer()
      return
    }

    // 1. 先在本地创建供应商
    const created = await providerRegistry.createCustomProvider(
      'xiaomi-mimo',
      'Xiaomi MiMo',
      'https://token-plan-cn.xiaomimimo.com/anthropic',
      'tp-ctgx27ynv0rkbt1jod87kkt779afid0eqrcmu68kst5zr13o',
      ''
    )
    if (!created) return

    // 2. 设置 Anthropic npm 包 + 模型
    await providerRegistry.setProviderConfig('xiaomi-mimo', 'Xiaomi MiMo',
      'https://token-plan-cn.xiaomimimo.com/anthropic',
      '@ai-sdk/anthropic', 'XIAOMI_MIMO_API_KEY')
    await providerRegistry.addOrUpdateModel('xiaomi-mimo', 'mimo-v2.5-pro', 'MiMo v2.5 Pro', true)
    await providerRegistry.addOrUpdateModel('xiaomi-mimo', 'mimo-v2.5', 'MiMo v2.5', true)

    // 3. 推送到 OpenCode Server（如果有活跃 Runner）
    await this.syncXiaomiMimoToServer()
  }

  /** 将小米 MiMo 配置推送到 OpenCode Server */
  private async syncXiaomiMimoToServer(): Promise<void> {
    if (this.mimoSynced) return
    if (this.activeRunner === null) return

    const p = providerRegistry.getById('xiaomi-mimo')
    if (!p) return

    this.mimoSynced = true

    const input = new ProviderConnectInput()
    input.providerId = p.id
    input.displayName = p.name
    input.apiType = 'anthropic'
    input.baseURL = p.baseURL
    input.apiKey = p.apiKey || 'tp-ctgx27ynv0rkbt1jod87kkt779afid0eqrcmu68kst5zr13o'
    input.models = []
    for (const m of p.models) {
      const mi = new ProviderModelInput()
      mi.id = m.id
      mi.name = m.name
      input.models.push(mi)
    }
    input.headers = []

    const result: ProviderConnectResult = await providerConnectionService.connectProvider(input, this.activeRunner)
    if (result.ok) {
      this.statusMsg = `MiMo: ${result.message}`
    } else {
      this.statusMsg = `MiMo 同步失败: ${result.error}`
    }
  }

  private async reload(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          Text('提供商')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ bottom: 34 })

          // ── 已连接的提供商 ──
          Text('已连接的提供商')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ bottom: 14 })

          if (this.connectedProviders().length === 0) {
            Row() {
              Text('没有已连接的提供商')
                .fontSize(Theme.fs.md)
                .fontColor(Theme.TEXT_MUTED)
            }
            .width('100%')
            .height(104)
            .padding({ left: 28, right: 28 })
            .borderRadius(12)
            .backgroundColor(Theme.SIDEBAR)
            .borderWidth(1)
            .borderColor(Theme.BORDER)
            .margin({ bottom: 40 })
          } else {
            ForEach(this.connectedProviders(), (p: CNProvider) => {
              ProviderCard({
                title: p.name,
                subtitle: `${p.id} · ${p.baseURL}`,
                badge: `${p.models.length} models`,
                buttonText: '管理',
                connected: true,
                onAction: () => {
                  this.onOpenModels()
                }
              })
            }, (p: CNProvider) => p.id)
          }

          // ── 热门提供商（只有一张自定义卡片）──
          Text('热门提供商')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ top: 24, bottom: 14 })

          ProviderCard({
            title: '自定义提供商',
            subtitle: '通过基础 URL 添加与 OpenAI 兼容的提供商。',
            badge: '自定义',
            buttonText: '连接',
            connected: false,
            onAction: () => this.openCustomDialog()
          })

          // 查看更多提供商
          Text('查看更多提供商')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.ACCENT)
            .margin({ top: 16, bottom: 8 })
            .onClick(() => {
              // 预留扩展：未来可展示更多预设供应商模板
            })

          if (this.statusMsg.length > 0) {
            Text(this.statusMsg)
              .fontSize(Theme.fs.sm)
              .fontColor(this.statusMsg.includes('失败') || this.statusMsg.includes('failed') ? Theme.DANGER : Theme.SUCCESS)
              .margin({ top: 8, bottom: 60 })
          }
        }
        .width('100%')
        .padding({ left: 78, right: 78, top: 56, bottom: 60 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)

      if (this.showDialog) {
        ProviderConnectDialog({
          visible: this.showDialog,
          onCancel: () => {
            this.showDialog = false
          },
          onSubmit: (input: ProviderConnectInput) => {
            this.submitProvider(input)
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private connectedProviders(): CNProvider[] {
    const list: CNProvider[] = []
    for (const p of this.providers) {
      if (p.enabled && p.authStatus !== 'missing') list.push(p)
    }
    return list
  }

  private openCustomDialog(): void {
    this.showDialog = true
  }

  /** Runner 变更时自动同步 MiMo 到 Server */
  onRunnerChanged(): void {
    if (this.activeRunner !== null) {
      // 异步同步，不阻塞 UI
      this.syncXiaomiMimoToServer()
    }
  }

  private async submitProvider(input: ProviderConnectInput): Promise<void> {
    if (this.connecting) return
    this.connecting = true
    this.statusMsg = '正在连接提供商...'

    const result: ProviderConnectResult = await providerConnectionService.connectProvider(input, this.activeRunner)
    this.connecting = false

    if (result.ok) {
      this.statusMsg = result.message
      this.showDialog = false
      await this.reload()
      if (result.connected) {
        this.onOpenModels()
      }
    } else {
      this.statusMsg = result.error.length > 0 ? result.error : '连接失败'
    }
  }
}
