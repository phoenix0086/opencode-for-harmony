import { Theme } from './Theme'

/**
 * 工具时间线面板
 * 右侧面板展示工具调用历史记录
 */

class ToolTimelineEntry {
  id: string = ''
  toolName: string = ''
  status: string = '' // 'running' | 'success' | 'error' | 'cancelled'
  input: string = ''
  output: string = ''
  step: number = 0
  timestamp: string = ''
}

@Component
export struct ToolTimelinePanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop entries: ToolTimelineEntry[] = []
  @Prop title: string = 'TOOLS'

  build() {
    Column() {
      // Header
      Row() {
        Text(this.title)
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

      // Timeline
      if (this.entries.length === 0) {
        Column() {
          Text('No tool calls yet')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.entries, (entry: ToolTimelineEntry) => {
            ListItem() {
              Row() {
                // Timeline dot
                Column() {
                  Circle({ width: 6, height: 6 })
                    .fill(this.getStatusColor(entry.status))
                  // Connector line
                  Column()
                    .width(1)
                    .layoutWeight(1)
                    .backgroundColor(Theme.BORDER)
                    .margin({ top: Theme.sp.xs })
                }
                .width(20)
                .alignItems(HorizontalAlign.Center)

                // Entry content
                Column() {
                  Row() {
                    Text(entry.toolName)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_SECONDARY)
                      .fontFamily(Theme.FONT_MONO)
                      .backgroundColor(Theme.CODE_BG)
                      .borderRadius(Theme.rd.sm)
                      .padding({ left: Theme.sp.sm, right: Theme.sp.sm })

                    Text(this.getStatusLabel(entry.status))
                      .fontSize(Theme.fs.xs)
                      .fontColor(this.getStatusColor(entry.status))
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ left: Theme.sp.sm })

                    if (entry.step > 0) {
                      Text(`#${entry.step}`)
                        .fontSize(Theme.fs.xs)
                        .fontColor(Theme.TEXT_MUTED)
                        .fontFamily(Theme.FONT_MONO)
                        .margin({ left: Theme.sp.sm })
                    }

                    if (entry.status === 'running') {
                      LoadingProgress()
                        .width(10)
                        .height(10)
                        .color(Theme.ACCENT)
                        .margin({ left: Theme.sp.sm })
                    }
                  }
                  .width('100%')

                  // Input snippet
                  if (entry.input.length > 0) {
                    Text(entry.input)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ top: Theme.sp.xs })
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }

                  // Output snippet
                  if (entry.output.length > 0 && entry.status !== 'running') {
                    Text(entry.output)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_SECONDARY)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ top: Theme.sp.xs })
                      .maxLines(3)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .layoutWeight(1)
                .padding({ bottom: Theme.sp.md })
              }
              .width('100%')
              .padding({ left: Theme.sp.md, right: Theme.sp.lg, top: Theme.sp.sm })
            }
          }, (entry: ToolTimelineEntry) => entry.id)
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

  private getStatusColor(status: string): string {
    if (status === 'running') return Theme.ACCENT
    if (status === 'success') return Theme.SUCCESS
    if (status === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  private getStatusLabel(status: string): string {
    if (status === 'running') return 'running'
    if (status === 'success') return 'done'
    if (status === 'error') return 'error'
    if (status === 'cancelled') return 'cancelled'
    return status
  }
}

export { ToolTimelineEntry }
