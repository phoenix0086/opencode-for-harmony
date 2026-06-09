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
  @State processPid: number = -1
  @State busy: boolean = false

  aboutToAppear(): void {
    // Load last-used host/port/mode/token so the user doesn't have to retype
    // the LAN IP on every app launch. Fall back to defaults if no saved config.
    localOpenCodeServerManager.loadLastConfig().then((cfg: LocalServerConfig) => {
      this.config = cfg
      this.mode = cfg.mode
      this.status = localOpenCodeServerManager.createPreviewStatus(this.config)
    })
    this.status = localOpenCodeServerManager.createPreviewStatus(this.config)
    this.logs = [
      '[info] 本页用于管理本地 OpenCode Runtime。',
      '[info] 点击"启动本地 Runtime"会通过 Native Bridge 启动 opencode serve。',
      '[info] 启动成功后会自动检测 /global/health 并激活 Runner。'
    ]
  }

  build() {
    Scroll() {
      Column() {
        Text('本地 Runtime')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: Theme.sp.sm })

        Text('默认使用本机 OpenCode Runtime。远程连接只是高级模式。')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ bottom: Theme.sp.xl })

        this.ModeSwitcher()
        this.ConnectionForm()

        LocalServerCard({
          status: this.status,
          isActive: this.isConnected,
          isBusy: this.busy,
          onPrepareStart: () => this.prepareStart(),
          onStart: () => this.startRuntime(),
          onStop: () => this.stopRuntime(),
          onRestart: () => this.restartRuntime(),
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
      this.ModePill('remote', '远程 Runtime')
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
          // Only seed the placeholder IP if the current host looks like a default
          // (127.0.0.1, empty, or the legacy '192.168.1.xxx' placeholder). If the
          // user already has a real LAN IP saved, keep it.
          const cur = this.config.host
          if (cur.length === 0 || cur === '127.0.0.1' || cur === '192.168.1.xxx') {
            this.config.host = '192.168.1.xxx'
          }
        }
        this.refreshStatusPreview()
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

      Text('本机模式：正式产品默认路径。App 通过 Native Bridge 启动本机 opencode serve，并连接 127.0.0.1。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: Theme.sp.md })

      Text('开发电脑 / 局域网：用于 DevEco、模拟器或真机调试。Runtime 在开发电脑上跑，Host 填开发电脑局域网 IP。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: Theme.sp.md })

      Text('远程 Runtime：高级模式，不会启动本地进程，只检测并连接远程地址。')
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
    const preview = localOpenCodeServerManager.createPreviewStatus(this.config)
    preview.processPid = this.processPid
    preview.logs = this.logs
    this.status = preview
  }

  private appendLog(line: string): void {
    const next: string[] = []
    for (const item of this.logs) next.push(item)
    next.push(line)
    this.logs = next
  }

  private appendLogs(lines: string[]): void {
    if (lines.length === 0) return
    const next: string[] = []
    for (const item of this.logs) next.push(item)
    for (const line of lines) next.push(line)
    this.logs = next
  }

  private collectProcessLogs(): void {
    if (this.processPid <= 0) return
    this.appendLogs(localOpenCodeServerManager.collectProcessLogs(this.processPid))
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms)
    })
  }

  private async prepareStart(): Promise<void> {
    this.status = await localOpenCodeServerManager.prepareStart(this.config)
    this.status.processPid = this.processPid
    this.logs = this.status.logs
  }

  private async startRuntime(): Promise<void> {
    if (this.busy) return
    this.busy = true

    this.status = localOpenCodeServerManager.startServerProcess(this.config)
    this.processPid = this.status.processPid
    this.logs = this.status.logs

    if (this.status.status === 'starting') {
      await this.autoConnectAfterStart()
    }

    this.busy = false
  }

  private async stopRuntime(): Promise<void> {
    if (this.busy) return
    this.busy = true

    this.collectProcessLogs()
    const stopped = localOpenCodeServerManager.stopServerProcess(this.processPid)
    this.processPid = -1
    stopped.baseUrl = this.status.baseUrl
    stopped.startCommand = this.status.startCommand
    this.status = stopped
    this.appendLogs(stopped.logs)

    this.busy = false
  }

  private async restartRuntime(): Promise<void> {
    if (this.busy) return
    this.busy = true

    if (this.processPid > 0) {
      this.collectProcessLogs()
      const stopped = localOpenCodeServerManager.stopServerProcess(this.processPid)
      this.appendLogs(stopped.logs)
      this.processPid = -1
      await this.delay(800)
    }

    this.status = localOpenCodeServerManager.startServerProcess(this.config)
    this.processPid = this.status.processPid
    this.appendLogs(this.status.logs)

    if (this.status.status === 'starting') {
      await this.autoConnectAfterStart()
    }

    this.busy = false
  }

  private async checkHealth(): Promise<void> {
    this.collectProcessLogs()
    this.status = await localOpenCodeServerManager.checkHealth(this.config)
    this.status.processPid = this.processPid
    this.appendLogs(this.status.logs)
  }

  private async connectLocal(): Promise<void> {
    this.collectProcessLogs()
    this.status = await localOpenCodeServerManager.checkAndActivate(this.config)
    this.status.processPid = this.processPid
    this.appendLogs(this.status.logs)
    if (this.status.status === 'running') {
      const runner = localOpenCodeServerManager.createRunnerFromConfig(this.config)
      runner.status = 'connected'
      runner.version = this.status.version
      // Persist the working config so the next visit / app launch keeps it.
      localOpenCodeServerManager.saveLastConfig(this.config).catch(() => {})
      this.onRunnerActivated(runner)
      this.onReconnect()
    }
  }

  private async autoConnectAfterStart(): Promise<void> {
    this.appendLog('[info] waiting for Runtime health...')
    for (let i = 0; i < 20; i++) {
      await this.delay(700)
      this.collectProcessLogs()

      const running = localOpenCodeServerManager.isProcessRunning(this.processPid)
      if (!running && i > 1) {
        this.status.status = 'error'
        this.status.message = 'Runtime 进程已退出，请查看日志。'
        this.appendLog('[error] process exited before health became ready')
        return
      }

      const health = await localOpenCodeServerManager.checkHealth(this.config)
      if (health.status === 'running') {
        this.status = health
        this.status.processPid = this.processPid
        this.appendLogs(health.logs)

        await localOpenCodeServerManager.saveAndActivate(this.config)
        this.appendLog('[ok] Runtime started and runner activated')

        const runner = localOpenCodeServerManager.createRunnerFromConfig(this.config)
        runner.status = 'connected'
        runner.version = health.version
        this.onRunnerActivated(runner)
        this.onReconnect()
        return
      }

      this.appendLog(`[wait] health not ready yet (${i + 1}/20)`)
    }

    this.status.status = 'not_running'
    this.status.message = 'Runtime 已启动进程，但 /global/health 超时未就绪。'
    this.appendLog('[warn] health check timeout')
  }
}
