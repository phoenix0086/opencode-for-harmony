import { Theme } from './Theme'

/**
 * TodoItem — 单个 todo 条目。
 * 对应上游 SessionTodo / v2 TodoItem。
 */
@Observed
export class TodoItem {
  id: string = ''
  content: string = ''
  status: string = '' // 'pending' | 'in_progress' | 'completed' | 'cancelled'
  priority: string = '' // 'low' | 'medium' | 'high'
}

/**
 * TodoListBlock — 整个 turn 的 todo 列表视图。
 * 一个 turn 可能只有一份 todo 列表（agent 在每个 step 输出一份）。
 */
@Component
export struct TodoListBlock {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop items: TodoItem[] = []

  build() {
    if (this.items.length === 0) {
      Column() {
        Text('no todos')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')
      .padding(Theme.sp.md)
      .backgroundColor(Theme.TOOL_BG)
      .borderRadius(Theme.rd.md)
      .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    } else {
      Column() {
        // Header
        Row() {
          Text('todo')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(Theme.rd.sm)
            .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 2, bottom: 2 })

          Text(`${this.getCompletedCount()}/${this.items.length}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.md })
        }
        .width('100%')
        .margin({ bottom: Theme.sp.sm })

        // Items
        ForEach(this.items, (item: TodoItem) => {
          Row() {
            Text(this.getStatusIcon(item.status))
              .fontSize(Theme.fs.sm)
              .fontColor(this.getStatusColor(item.status))
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .width(20)
              .textAlign(TextAlign.Center)

            if (item.priority.length > 0 && item.priority !== 'low') {
              Text(item.priority === 'high' ? '!' : '-')
                .fontSize(Theme.fs.xs)
                .fontColor(item.priority === 'high' ? Theme.DANGER : Theme.WARNING)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(FontWeight.Bold)
                .margin({ right: Theme.sp.sm })
            }

            Text(item.content)
              .fontSize(Theme.fs.sm)
              .fontColor(item.status === 'completed' ? Theme.TEXT_MUTED : Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .layoutWeight(1)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .decoration(item.status === 'completed' ? { type: TextDecorationType.LineThrough } : { type: TextDecorationType.None })
          }
          .width('100%')
          .padding({ top: Theme.sp.xs, bottom: Theme.sp.xs })
        }, (item: TodoItem) => item.id.length > 0 ? item.id : item.content)
      }
      .width('100%')
      .padding(Theme.sp.md)
      .backgroundColor(Theme.TOOL_BG)
      .borderRadius(Theme.rd.md)
      .borderWidth(1)
      .borderColor(Theme.TOOL_BORDER)
      .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    }
  }

  private getCompletedCount(): number {
    let n = 0
    for (const item of this.items) {
      if (item.status === 'completed' || item.status === 'cancelled') {
        n += 1
      }
    }
    return n
  }

  private getStatusIcon(status: string): string {
    if (status === 'completed') return '[x]'
    if (status === 'in_progress') return '[~]'
    if (status === 'cancelled') return '[-]'
    return '[ ]'
  }

  private getStatusColor(status: string): string {
    if (status === 'completed') return Theme.SUCCESS
    if (status === 'in_progress') return Theme.ACCENT
    if (status === 'cancelled') return Theme.TEXT_MUTED
    return Theme.TEXT_SECONDARY
  }
}
