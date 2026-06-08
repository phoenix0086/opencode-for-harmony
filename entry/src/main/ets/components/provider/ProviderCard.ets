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
        .fontSize(26)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .width(48)
        .textAlign(TextAlign.Center)

      Column() {
        Row() {
          Text(this.title)
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.TEXT_PRIMARY)

          if (this.badge.length > 0) {
            Text(this.badge)
              .fontSize(Theme.fs.xs)
              .fontWeight(FontWeight.Medium)
              .fontColor(Theme.TEXT_SECONDARY)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(4)
              .backgroundColor(Theme.ACTIVE_BG)
              .margin({ left: 10 })
          }
        }
        .alignItems(VerticalAlign.Center)

        Text(this.subtitle)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 4 })
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })

      Row() {
        if (!this.connected) {
          Text('+')
            .fontSize(22)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ right: 10 })
        }

        Text(this.connected ? '管理' : this.buttonText)
          .fontSize(Theme.fs.md)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      .height(48)
      .padding({ left: 18, right: 18 })
      .borderRadius(10)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .backgroundColor(Theme.BG)
      .onClick(() => this.onAction())
    }
    .width('100%')
    .height(104)
    .padding({ left: 26, right: 28 })
    .borderRadius(12)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 18 })
  }
}
