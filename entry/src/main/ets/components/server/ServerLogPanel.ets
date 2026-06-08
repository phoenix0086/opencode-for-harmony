import { Theme } from '../Theme'

@Component
export struct ServerLogPanel {
  @Prop logs: string[] = []

  build() {
    Column() {
      Text('SERVER LOGS')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .margin({ bottom: Theme.sp.lg })

      if (this.logs.length === 0) {
        Text('no logs yet')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      } else {
        ForEach(this.logs, (line: string) => {
          Text(line)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .width('100%')
            .margin({ bottom: Theme.sp.sm })
        }, (line: string) => line)
      }
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.CODE_BG)
    .borderWidth(1)
    .borderColor(Theme.CODE_BORDER)
    .alignItems(HorizontalAlign.Start)
  }
}
