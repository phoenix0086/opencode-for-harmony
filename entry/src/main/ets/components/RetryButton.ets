import { Theme } from './Theme'

@Component
export struct RetryButton {
  @Prop messageId: string = ''
  @Prop failed: boolean = false
  onRetry: (messageId: string) => void = () => {}

  build() {
    if (this.failed) {
      Row() {
        Text('\u21BB')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)

        Text('retry')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })
      }
      .padding({
        left: Theme.sp.lg,
        right: Theme.sp.lg,
        top: Theme.sp.sm,
        bottom: Theme.sp.sm
      })
      .backgroundColor(Theme.DANGER_DIM)
      .border({
        width: 1,
        color: Theme.DANGER,
        style: BorderStyle.Solid
      })
      .borderRadius(Theme.rd.md)
      .onClick(() => {
        this.onRetry(this.messageId)
      })
      .justifyContent(FlexAlign.Center)
      .width('auto')
      .margin({ top: Theme.sp.md })
      .alignSelf(ItemAlign.Center)
    }
  }
}
