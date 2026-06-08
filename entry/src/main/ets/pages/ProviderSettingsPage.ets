import { Theme } from '../components/Theme'
import { Runner } from '../models/Runner'
import { CNProvider } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { providerTemplateRegistry, ProviderTemplate } from '../services/ProviderTemplateRegistry'
import { providerConnectionService, ProviderConnectInput, ProviderConnectResult } from '../services/ProviderConnectionService'
import { ProviderCard } from '../components/provider/ProviderCard'
import { ProviderConnectDialog } from '../components/provider/ProviderConnectDialog'

@Component
export struct ProviderSettingsPage {
  @Prop activeRunner: Runner | null = null
  onOpenModels: () => void = () => {}

  @State providers: CNProvider[] = []
  @State templates: ProviderTemplate[] = []
  @State showDialog: boolean = false
  @State selectedTemplate: ProviderTemplate | null = null
  @State statusMsg: string = ''
  @State connecting: boolean = false

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
    this.templates = providerTemplateRegistry.listTemplates()
  }

  private refresh(): void {
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
            .padding(24)
            .borderRadius(12)
            .backgroundColor(Theme.SIDEBAR)
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

          Text('热门提供商')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ top: 18, bottom: 14 })

          ForEach(this.templates, (t: ProviderTemplate) => {
            ProviderCard({
              title: t.name,
              subtitle: t.description.length > 0 ? t.description : '通过基础 URL 添加与 OpenAI 兼容的提供商。',
              badge: t.id === 'custom-openai-compatible' ? '自定义' : '',
              buttonText: '连接',
              connected: false,
              onAction: () => this.openTemplate(t)
            })
          }, (t: ProviderTemplate) => t.id)

          Text('查看更多提供商')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.ACCENT)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 24, bottom: 60 })

          if (this.statusMsg.length > 0) {
            Text(this.statusMsg)
              .fontSize(Theme.fs.sm)
              .fontColor(this.statusMsg.includes('失败') || this.statusMsg.includes('failed') ? Theme.DANGER : Theme.SUCCESS)
              .margin({ top: 8 })
          }
        }
        .width('100%')
        .padding({ left: 78, right: 78, top: 56, bottom: 60 })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.BG)

      ProviderConnectDialog({
        visible: this.showDialog,
        template: this.selectedTemplate,
        onCancel: () => {
          this.showDialog = false
        },
        onSubmit: (input: ProviderConnectInput) => {
          this.submitProvider(input)
        }
      })
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

  private openTemplate(t: ProviderTemplate): void {
    this.selectedTemplate = t
    this.showDialog = true
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
      await providerRegistry.init()
      this.refresh()
      if (result.connected) {
        this.onOpenModels()
      }
    } else {
      this.statusMsg = result.error.length > 0 ? result.error : '连接失败'
    }
  }
}
