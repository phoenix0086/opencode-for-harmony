import { Theme } from './Theme'
import { LogEntry } from '../models/Event'

/**
 * Logs Panel
 * 右侧面板 — 显示结构化运行时/server 事件日志
 */
@Component
export struct LogsPanel {
  @Prop entries: LogEntry[] = []

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
          ForEach(this.entries, (entry: LogEntry) => {
            ListItem() {
              Row() {
                // Timestamp
                Text(entry.timestamp)
                  .fontSize(Theme.fs.xs)
                  .fontColor(Theme.TEXT_MUTED)
                  .fontFamily(Theme.FONT_MONO)
                  .width(75)

                // Source badge
                Text(entry.source)
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.getSourceColor(entry.source))
                  .fontFamily(Theme.FONT_MONO)
                  .fontWeight(FontWeight.Bold)
                  .width(65)

                // Message
                Text(entry.message)
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.getLevelColor(entry.level))
                  .fontFamily(Theme.FONT_MONO)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
            }
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }, (entry: LogEntry) => entry.timestamp + entry.message)
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

  private getLevelColor(level: string): string {
    if (level === 'error') return Theme.DANGER
    if (level === 'warn') return Theme.WARNING
    if (level === 'debug') return Theme.TEXT_MUTED
    return Theme.TEXT_SECONDARY
  }

  private getSourceColor(source: string): string {
    if (source === 'server') return Theme.ACCENT
    if (source === 'session') return Theme.SUCCESS
    if (source === 'message') return Theme.ACCENT
    if (source === 'tool') return Theme.WARNING
    if (source === 'permission') return Theme.DANGER
    if (source === 'diff') return Theme.TEXT_SECONDARY
    if (source === 'poll') return Theme.TEXT_MUTED
    return Theme.TEXT_MUTED
  }
}
