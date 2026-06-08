import { Theme } from '../Theme'
import { RuntimeState } from '../../services/LocalOpenCodeRuntimeService'

@Component
export struct RuntimeStatusCard {
  @Prop state: RuntimeState = new RuntimeState()
  @Prop active: boolean = false
  onPrepareStart: () => void = () => {}
  onHealth: () => void = () => {}
  onActivate: () => void = () => {}

  private color(): string {
    if (this.state.status === 'running') return Theme.SUCCESS
    if (this.state.status === 'manual_required' || this.state.status === 'starting') return Theme.WARNING
    if (this.state.status === 'error' || this.state.status === 'stopped') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  build() {
    Column() {
      Row() {
        Circle().width(10).height(10).fill(this.color()).margin({ right: Theme.sp.lg })

        Column() {
          Text('本地 OpenCode Runtime')
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          Text(this.state.baseUrl)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text(this.active ? 'active' : this.state.status)
          .fontSize(Theme.fs.xs)
          .fontColor(this.color())
          .fontFamily(Theme.FONT_MONO)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
          .backgroundColor(Theme.ACTIVE_BG)
          .borderRadius(Theme.rd.sm)
      }
      .width('100%')

      Text(this.state.message.length > 0 ? this.state.message : '尚未检测 Runtime。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: Theme.sp.lg })
        .width('100%')

      Text(this.state.command)
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
        this.ActionButton('启动命令', Theme.TEXT_PRIMARY, Theme.PANEL, () => this.onPrepareStart())
        this.ActionButton('检测', Theme.ACCENT, Theme.ACCENT_DIM, () => this.onHealth())
        this.ActionButton('保存并连接', Theme.TEXT_INVERSE, Theme.ACCENT, () => this.onActivate())
      }
      .width('100%')
      .margin({ top: Theme.sp.lg })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .backgroundColor(Theme.SIDEBAR)
    .borderRadius(Theme.rd.lg)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
  }

  @Builder
  ActionButton(label: string, color: string, bg: string, action: () => void) {
    Text(label)
      .fontSize(Theme.fs.sm)
      .fontColor(color)
      .backgroundColor(bg)
      .borderRadius(Theme.rd.md)
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
      .margin({ right: Theme.sp.md })
      .onClick(() => action())
  }
}
