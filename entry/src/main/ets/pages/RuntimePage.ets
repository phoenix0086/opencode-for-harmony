import { Theme } from '../components/Theme'
import { Runner } from '../models/Runner'
import { RuntimeConfig, RuntimeState, localOpenCodeRuntimeService } from '../services/LocalOpenCodeRuntimeService'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { RuntimeStatusCard } from '../components/runtime/RuntimeStatusCard'
import { RuntimeLogPanel } from '../components/runtime/RuntimeLogPanel'

@Component
export struct RuntimePage {
  @Prop activeRunner: Runner | null = null
  @Prop isConnected: boolean = false
  @Prop serverUrl: string = ''
  onRunnerActivated: (runner: Runner) => void = () => {}
  onReconnect: () => void = () => {}

  @State config: RuntimeConfig = new RuntimeConfig()
  @State state: RuntimeState = new RuntimeState()
  @State logs: string[] = []

  // MCP / LSP / Formatter status (only loaded when connected)
  @State mcpCount: number = 0
  @State lspCount: number = 0
  @State formatterCount: number = 0
  @State statusLoading: boolean = false

  aboutToAppear(): void {
    this.config = localOpenCodeRuntimeService.defaultConfig()

    // Sync with actual connected server URL if available
    if (this.serverUrl.length > 0) {
      const match = this.serverUrl.match(/^(https?):\/\/([^:]+):(\d+)/)
      if (match) {
        this.config.protocol = match[1] as 'http' | 'https'
        this.config.host = match[2]
        this.config.port = Number(match[3])
      }
    }

    this.state.command = localOpenCodeRuntimeService.command(this.config)
    this.state.baseUrl = `${this.config.protocol}://${this.config.host}:${this.config.port}`
    this.logs = ['[info] Runtime page ready.']
    if (this.isConnected) {
      this.loadExtensionStatus()
    }
  }

  private async loadExtensionStatus(): Promise<void> {
    if (this.activeRunner === null) return
    this.statusLoading = true
    try {
      const client = new OpenCodeClient(this.activeRunner)
      const extResults = await Promise.all([
        client.listMcpServers(),
        client.listLspStatus(),
        client.listFormatters()
      ])
      const mcp = extResults[0]
      const lsp = extResults[1]
      const fmt = extResults[2]
      this.mcpCount = mcp.length
      this.lspCount = lsp.length
      this.formatterCount = fmt.length
      this.logs.push(`[ok] extensions: mcp=${mcp.length} lsp=${lsp.length} formatter=${fmt.length}`)
    } catch (e) {
      this.logs.push(`[warn] extension status: ${String(e)}`)
    }
    this.statusLoading = false
  }

  build() {
    Scroll() {
      Column() {
        Text('本地 Runtime')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: Theme.sp.xl })

        this.ModeSwitcher()
        this.ConfigPanel()

        RuntimeStatusCard({
          state: this.state,
          active: this.isConnected,
          onPrepareStart: () => this.prepareStart(),
          onHealth: () => this.health(),
          onActivate: () => this.activate()
        })
        .margin({ bottom: Theme.sp.xxl })

        this.ExtensionStatusCard()

        this.HelpPanel()
        RuntimeLogPanel({ logs: this.logs })
      }
      .width('100%')
      .padding({ left: 78, right: 78, top: 56, bottom: 60 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  @Builder
  ModeSwitcher() {
    Row() {
      this.ModePill('local', '本机')
      this.ModePill('dev-pc', '开发电脑')
      this.ModePill('remote', '远程')
    }
    .margin({ bottom: Theme.sp.xl })
  }

  @Builder
  ModePill(mode: string, label: string) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(this.config.mode === mode ? Theme.TEXT_INVERSE : Theme.TEXT_SECONDARY)
      .backgroundColor(this.config.mode === mode ? Theme.ACCENT : Theme.PANEL)
      .borderRadius(Theme.rd.md)
      .borderWidth(1)
      .borderColor(this.config.mode === mode ? Theme.ACCENT : Theme.BORDER)
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
      .margin({ right: Theme.sp.md })
      .onClick(() => {
        this.config.mode = mode
        if (mode === 'local') this.config.host = '127.0.0.1'
        if (mode === 'dev-pc') this.config.host = '192.168.1.xxx'
        this.refreshPreview()
      })
  }

  @Builder
  ConfigPanel() {
    Column() {
      Text('连接设置')
        .fontSize(Theme.fs.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ bottom: Theme.sp.lg })

      this.Field('Host', this.config.host, '127.0.0.1', (v: string) => {
        this.config.host = v
        this.refreshPreview()
      })

      this.Field('Port', `${this.config.port}`, '4096', (v: string) => {
        const n = Number(v)
        if (!Number.isNaN(n) && n > 0) this.config.port = n
        this.refreshPreview()
      })

      this.Field('Token（可选）', this.config.token, 'password', (v: string) => {
        this.config.token = v
      })

      this.Field('Workspace（可选）', this.config.workspace, '/path/to/project', (v: string) => {
        this.config.workspace = v
      })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .backgroundColor(Theme.SIDEBAR)
    .borderRadius(Theme.rd.lg)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  Field(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .margin({ bottom: Theme.sp.sm })

      TextInput({ text: value, placeholder: placeholder })
        .width('100%')
        .height(38)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .placeholderColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(Theme.rd.md)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .margin({ bottom: Theme.sp.lg })
  }

  @Builder
  HelpPanel() {
    Column() {
      Text('说明')
        .fontSize(Theme.fs.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ bottom: Theme.sp.lg })

      Text('本机模式是最终产品默认方向。V1 先检测和连接，V2 通过 Native Bridge 真正一键启动 opencode serve。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: Theme.sp.md })

      Text('开发电脑模式用于 DevEco / 模拟器 / 真机调试，Host 要填开发电脑的局域网 IP。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .backgroundColor(Theme.SIDEBAR)
    .borderRadius(Theme.rd.lg)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ExtensionStatusCard() {
    Column() {
      Row() {
        Text('扩展状态')
          .fontSize(Theme.fs.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)

        Blank()

        if (this.isConnected && this.activeRunner !== null) {
          Text('刷新')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
            .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
            .backgroundColor(Theme.ACTIVE_BG)
            .borderRadius(Theme.rd.sm)
            .onClick(() => this.loadExtensionStatus())
        }
      }
      .width('100%')
      .margin({ bottom: Theme.sp.lg })

      if (!this.isConnected) {
        Text('连接 Runtime 后显示 MCP / LSP / Formatter 状态。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      } else {
        Row() {
          this.StatusPill('MCP', this.mcpCount, false)
          this.StatusPill('LSP', this.lspCount, false)
          this.StatusPill('FMT', this.formatterCount, true)
        }
        .width('100%')

        if (this.statusLoading) {
          Text('正在加载...')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
        }
      }
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .backgroundColor(Theme.SIDEBAR)
    .borderRadius(Theme.rd.lg)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  StatusPill(label: string, count: number, isLast: boolean) {
    Column() {
      Text(`${count}`)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(count > 0 ? Theme.ACCENT : Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)

      Text(label)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .margin({ top: Theme.sp.xs })
    }
    .layoutWeight(1)
    .padding(Theme.sp.lg)
    .backgroundColor(Theme.INPUT_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .alignItems(HorizontalAlign.Center)
    .margin({ right: isLast ? 0 : Theme.sp.md })
  }

  private refreshPreview(): void {
    this.state.baseUrl = `${this.config.protocol}://${this.config.host}:${this.config.port}`
    this.state.command = localOpenCodeRuntimeService.command(this.config)
  }

  private async prepareStart(): Promise<void> {
    this.state = await localOpenCodeRuntimeService.prepareStart(this.config)
    this.logs = this.state.logs
  }

  private async health(): Promise<void> {
    this.state = await localOpenCodeRuntimeService.health(this.config)
    this.logs = this.state.logs
  }

  private async activate(): Promise<void> {
    this.state = await localOpenCodeRuntimeService.activate(this.config)
    this.logs = this.state.logs
    if (this.state.status === 'running') {
      const runner = localOpenCodeRuntimeService.createRunner(this.config)
      runner.status = 'connected'
      runner.version = this.state.version
      this.onRunnerActivated(runner)
      this.onReconnect()
    }
  }
}
