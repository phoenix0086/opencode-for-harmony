import { Theme } from '../Theme'

@Component
export struct RuntimeLogPanel {
  @Prop logs: string[] = []

  build() {
    Column() {
      Text('RUNTIME LOGS')
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
            .margin({ bottom: Theme.sp.sm })
            .width('100%')
        }, (line: string) => line)
      }
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .backgroundColor(Theme.CODE_BG)
    .borderRadius(Theme.rd.lg)
    .borderWidth(1)
    .borderColor(Theme.CODE_BORDER)
    .alignItems(HorizontalAlign.Start)
  }
}
