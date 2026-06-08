import { Theme } from '../Theme'

@Component
export struct ProviderCard {
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop badge: string = ''
  @Prop buttonText: string = '连接'
  @Prop connected: boolean = false
  onAction: () => void = () => {}

  build() {
    Row() {
      Text(this.connected ? '✓' : '✦')
        .fontSize(22)
        .fontColor(this.connected ? Theme.SUCCESS : Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .width(36)

      Column() {
        Row() {
          Text(this.title)
            .fontSize(Theme.fs.md)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)
          if (this.badge.length > 0) {
            Text(this.badge)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_SECONDARY)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(4)
              .backgroundColor(Theme.ACTIVE_BG)
              .margin({ left: 8 })
          }
        }

        Text(this.subtitle)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 4 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(this.connected ? '管理' : this.buttonText)
        .fontSize(Theme.fs.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_PRIMARY)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(8)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .backgroundColor(Theme.PANEL)
        .onClick(() => this.onAction())
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .borderRadius(12)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 12 })
  }
}
