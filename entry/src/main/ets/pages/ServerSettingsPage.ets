import { Theme } from '../components/Theme'
import { Runner } from '../models/Runner'
import { LocalServerConfig, LocalServerStatus, localOpenCodeServerManager } from '../services/LocalOpenCodeServerManager'
import { LocalServerCard } from '../components/server/LocalServerCard'
import { ServerLogPanel } from '../components/server/ServerLogPanel'

@Component
export struct ServerSettingsPage {
  @Prop activeRunner: Runner | null = null
  @Prop isConnected: boolean = false
  onRunnerActivated: (runner: Runner) => void = () => {}
  onReconnect: () => void = () => {}

  @State config: LocalServerConfig = new LocalServerConfig()
  @State status: LocalServerStatus = new LocalServerStatus()
  @State statusMsg: string = ''
  @State logs: string[] = []
  @State mode: string = 'local'

  aboutToAppear(): void {
    this.config = localOpenCodeServerManager.createDefaultConfig()
    this.status = new LocalServerStatus()
    this.logs = [
      '[info] V1 supports local/remote health check and runner activation.',
      '[info] One-click process start is reserved for native bridge / packaged binary integration.'
    ]
  }

  build() {
    Scroll() {
      Column() {
        Text('服务器')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: Theme.sp.xl })

        this.ModeSwitcher()
        this.ConnectionForm()

        LocalServerCard({
          status: this.status,
          isActive: this.isConnected,
          onPrepareStart: () => this.prepareStart(),
          onCheck: () => this.checkHealth(),
          onConnect: () => this.connectLocal()
        })
        .margin({ bottom: Theme.sp.xxl })

        this.HelpBlock()
        ServerLogPanel({ logs: this.logs })
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
      this.ModePill('local', '本机模式')
      this.ModePill('dev-pc', '开发电脑 / 局域网')
      this.ModePill('remote', '远程服务')
    }
    .margin({ bottom: Theme.sp.xl })
  }

  @Builder
  ModePill(id: string, label: string) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(this.mode === id ? Theme.TEXT_INVERSE : Theme.TEXT_SECONDARY)
      .backgroundColor(this.mode === id ? Theme.ACCENT : Theme.PANEL)
      .borderRadius(Theme.rd.md)
      .borderWidth(1)
      .borderColor(this.mode === id ? Theme.ACCENT : Theme.BORDER)
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
      .margin({ right: Theme.sp.md })
      .onClick(() => {
        this.mode = id
        this.config.mode = id
        if (id === 'local') {
          this.config.host = '127.0.0.1'
        } else if (id === 'dev-pc') {
          this.config.host = '192.168.1.xxx'
        }
        this.status.startCommand = localOpenCodeServerManager.getCommandForConfig(this.config)
        this.status.baseUrl = `${this.config.protocol}://${this.config.host}:${this.config.port}`
      })
  }

  @Builder
  ConnectionForm() {
    Column() {
      Text('连接设置')
        .fontSize(Theme.fs.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ bottom: Theme.sp.lg })

      this.Field('Host', this.config.host, '127.0.0.1 或开发电脑 IP', (v: string) => {
        this.config.host = v
        this.refreshStatusPreview()
      })

      this.Field('Port', `${this.config.port}`, '4096', (v: string) => {
        const parsed = Number(v)
        if (!Number.isNaN(parsed) && parsed > 0) {
          this.config.port = parsed
          this.refreshStatusPreview()
        }
      })

      this.Field('Token / Password（可选）', this.config.token, 'OPENCODE_SERVER_PASSWORD', (v: string) => {
        this.config.token = v
      })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
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
  HelpBlock() {
    Column() {
      Text('使用说明')
        .fontSize(Theme.fs.lg)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .margin({ bottom: Theme.sp.lg })

      Text('本机模式：App 和 opencode serve 在同一台鸿蒙 PC 上运行，Host 用 127.0.0.1。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: Theme.sp.md })

      Text('开发电脑 / 局域网：App 在模拟器或真机上跑，opencode serve 在开发电脑上跑，Host 填开发电脑局域网 IP，命令使用 --hostname 0.0.0.0。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: Theme.sp.md })

      Text('V1 先完成检测和连接。真正一键启动外部进程，需要后续接 Native Bridge 或随包内置 opencode 二进制。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.WARNING)
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.xxl })
    .alignItems(HorizontalAlign.Start)
  }

  private refreshStatusPreview(): void {
    this.status.host = this.config.host
    this.status.port = this.config.port
    this.status.protocol = this.config.protocol
    this.status.baseUrl = `${this.config.protocol}://${this.config.host}:${this.config.port}`
    this.status.startCommand = localOpenCodeServerManager.getCommandForConfig(this.config)
  }

  private async prepareStart(): Promise<void> {
    this.status = await localOpenCodeServerManager.prepareStart(this.config)
    this.logs = this.status.logs
  }

  private async checkHealth(): Promise<void> {
    this.status = await localOpenCodeServerManager.checkHealth(this.config)
    this.logs = this.status.logs
  }

  private async connectLocal(): Promise<void> {
    this.status = await localOpenCodeServerManager.checkAndActivate(this.config)
    this.logs = this.status.logs
    if (this.status.status === 'running') {
      const runner = localOpenCodeServerManager.createRunnerFromConfig(this.config)
      runner.status = 'connected'
      runner.version = this.status.version
      this.onRunnerActivated(runner)
      this.onReconnect()
    }
  }
}
