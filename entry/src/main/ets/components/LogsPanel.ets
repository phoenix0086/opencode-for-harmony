import { Theme } from './Theme'

/**
 * Logs Panel
 * 右侧面板 — 显示运行时/server 事件日志
 */
@Component
export struct LogsPanel {
  @Prop entries: string[] = []

  build() {
    Column() {
      // Header
      Row() {
        Text('LOGS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        if (this.entries.length > 0) {
          Text(`${this.entries.length}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.lg, bottom: Theme.sp.md })

      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      if (this.entries.length === 0) {
        Column() {
          Text('No logs yet')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('Event stream logs will appear here once a session is active.')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
            .textAlign(TextAlign.Center)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.entries, (entry: string) => {
            ListItem() {
              Text(entry)
                .fontSize(Theme.fs.xs)
                .fontColor(this.getLogColor(entry))
                .fontFamily(Theme.FONT_MONO)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }, (entry: string) => entry)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Auto)
        .backgroundColor('transparent')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.SIDEBAR)
  }

  private getLogColor(entry: string): string {
    if (entry.includes('error') || entry.includes('failed')) return Theme.DANGER
    if (entry.includes('connected') || entry.includes('success') || entry.includes('idle')) return Theme.SUCCESS
    if (entry.includes('started') || entry.includes('Sending')) return Theme.ACCENT
    return Theme.TEXT_MUTED
  }
}
