import { Theme } from '../Theme'

@Component
export struct ModelCard {
  @Prop providerName: string = ''
  @Prop modelRef: string = ''
  @Prop modelName: string = ''
  @Prop isDefault: boolean = false
  @Prop isSmall: boolean = false
  onSetDefault: () => void = () => {}
  onSetSmall: () => void = () => {}
  onTest: () => void = () => {}

  build() {
    Row() {
      Column() {
        Text(this.modelName.length > 0 ? this.modelName : this.modelRef)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
        Text(this.modelRef)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ top: 4 })
        if (this.providerName.length > 0) {
          Text(this.providerName)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.isDefault) {
        Text('默认')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.SUCCESS)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor(Theme.SUCCESS_DIM)
          .margin({ right: 8 })
      }

      if (this.isSmall) {
        Text('Small')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.ACCENT)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(4)
          .backgroundColor(Theme.ACTIVE_BG)
          .margin({ right: 8 })
      }

      Text('设默认')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.ACCENT)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.ACTIVE_BG)
        .onClick(() => this.onSetDefault())

      Text('设 small')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_SECONDARY)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.PANEL)
        .margin({ left: 8 })
        .onClick(() => this.onSetSmall())

      Text('测试')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_PRIMARY)
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(6)
        .backgroundColor(Theme.PANEL)
        .margin({ left: 8 })
        .onClick(() => this.onTest())
    }
    .width('100%')
    .padding(14)
    .borderRadius(10)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: 8 })
  }
}
