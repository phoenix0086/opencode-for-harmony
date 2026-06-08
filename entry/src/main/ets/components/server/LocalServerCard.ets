import { Theme } from '../Theme'
import { LocalServerStatus } from '../../services/LocalOpenCodeServerManager'

@Component
export struct LocalServerCard {
  @Prop status: LocalServerStatus = new LocalServerStatus()
  @Prop isActive: boolean = false
  onPrepareStart: () => void = () => {}
  onCheck: () => void = () => {}
  onConnect: () => void = () => {}

  private statusColor(): string {
    if (this.status.status === 'running') return Theme.SUCCESS
    if (this.status.status === 'manual_required') return Theme.WARNING
    if (this.status.status === 'error' || this.status.status === 'not_running') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  build() {
    Column() {
      Row() {
        Circle()
          .width(10)
          .height(10)
          .fill(this.statusColor())
          .margin({ right: Theme.sp.lg })

        Column() {
          Text('本地 OpenCode Server')
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

        Text(this.isActive ? 'active' : this.status.status)
          .fontSize(Theme.fs.xs)
          .fontColor(this.statusColor())
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.ACTIVE_BG)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
      }
      .width('100%')

      Text(this.status.message.length > 0 ? this.status.message : '尚未检测。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ top: Theme.sp.lg })
        .width('100%')

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
        Text('显示启动命令')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .backgroundColor(Theme.PANEL)
          .borderRadius(Theme.rd.md)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
          .onClick(() => this.onPrepareStart())

        Text('检测服务')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.ACCENT)
          .backgroundColor(Theme.ACCENT_DIM)
          .borderRadius(Theme.rd.md)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
          .margin({ left: Theme.sp.md })
          .onClick(() => this.onCheck())

        Text('保存并连接')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_INVERSE)
          .backgroundColor(Theme.ACCENT)
          .borderRadius(Theme.rd.md)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
          .margin({ left: Theme.sp.md })
          .onClick(() => this.onConnect())
      }
      .width('100%')
      .margin({ top: Theme.sp.lg })
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
  }
}
