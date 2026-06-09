import { Theme } from '../Theme'
import { LocalServerStatus } from '../../services/LocalOpenCodeServerManager'

@Component
export struct LocalServerCard {
  @Prop status: LocalServerStatus = new LocalServerStatus()
  @Prop isActive: boolean = false
  @Prop isBusy: boolean = false

  onPrepareStart: () => void = () => {}
  onStart: () => void = () => {}
  onStop: () => void = () => {}
  onRestart: () => void = () => {}
  onCheck: () => void = () => {}
  onConnect: () => void = () => {}

  private statusColor(): string {
    if (this.status.status === 'running') return Theme.SUCCESS
    if (this.status.status === 'starting' || this.status.status === 'manual_required') return Theme.WARNING
    if (this.status.status === 'error' || this.status.status === 'not_running') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  private statusLabel(): string {
    if (this.isActive) return 'active'
    return this.status.status.length > 0 ? this.status.status : 'unknown'
  }

  build() {
    Column() {
      Row() {
        Circle().width(10).height(10).fill(this.statusColor()).margin({ right: Theme.sp.lg })

        Column() {
          Text('本地 OpenCode Runtime')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          Text(this.status.baseUrl)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.statusLabel())
          .fontSize(Theme.fs.xs)
          .fontColor(this.statusColor())
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.ACTIVE_BG)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
      }
      .width('100%')

      Text(this.status.message.length > 0 ? this.status.message : '尚未检测本地 Runtime。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: Theme.sp.lg })
        .width('100%')

      if (this.status.processPid > 0) {
        Text(`pid=${this.status.processPid}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ top: Theme.sp.sm })
      }

      Text(this.status.startCommand)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .padding(Theme.sp.lg)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(Theme.rd.md)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .width('100%')
        .margin({ top: Theme.sp.lg })

      Row() {
        this.ActionButton('启动本地 Runtime', Theme.TEXT_INVERSE, Theme.ACCENT, () => this.onStart())
        this.ActionButton('停止', Theme.DANGER, Theme.DANGER_DIM, () => this.onStop())
        this.ActionButton('重启', Theme.TEXT_PRIMARY, Theme.PANEL, () => this.onRestart())
      }
      .width('100%')
      .margin({ top: Theme.sp.lg })

      Row() {
        this.ActionButton('显示启动命令', Theme.TEXT_PRIMARY, Theme.PANEL, () => this.onPrepareStart())
        this.ActionButton('检测', Theme.ACCENT, Theme.ACCENT_DIM, () => this.onCheck())
        this.ActionButton('保存并连接', Theme.TEXT_INVERSE, Theme.SUCCESS, () => this.onConnect())
      }
      .width('100%')
      .margin({ top: Theme.sp.md })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .opacity(this.isBusy ? 0.75 : 1)
  }

  @Builder
  ActionButton(label: string, color: string, bg: string, action: () => void) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(color)
      .backgroundColor(bg)
      .borderRadius(Theme.rd.md)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
      .margin({ right: Theme.sp.md })
      .onClick(() => {
        if (!this.isBusy) action()
      })
  }
}
