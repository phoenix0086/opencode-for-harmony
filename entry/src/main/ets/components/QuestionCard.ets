import { Theme } from './Theme'

/**
 * QuestionOption — agent 给用户的选择项。
 */
@Observed
export class QuestionOption {
  id: string = ''
  label: string = ''
  description: string = ''
}

/**
 * QuestionBlock — UI 渲染的 question 卡片。
 */
@Observed
export class QuestionBlockData {
  id: string = ''          // 内部稳定 id，用于在 Index.ets 状态中索引
  requestID: string = ''   // 后端真实 requestID（用于 replyQuestion API）
  header: string = ''      // 标题
  question: string = ''    // 问题
  options: QuestionOption[] = []
  multiSelect: boolean = false
  status: string = 'pending' // 'pending' | 'answered'
  selected: string[] = []   // 已选 option id
}

@Component
export struct QuestionCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop data: QuestionBlockData = new QuestionBlockData()
  onSelect: (id: string, optionIds: string[]) => void = () => {}

  build() {
    Column() {
      Row() {
        Text('?')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.ACCENT_DIM)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 2, bottom: 2 })

        Text('agent question')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })
      }
      .width('100%')

      Text(this.data.question)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .margin({ top: Theme.sp.sm })

      ForEach(this.data.options, (opt: QuestionOption) => {
        Row() {
          if (this.data.multiSelect) {
            // ☐ / ☑
            Text(this.isSelected(opt.id) ? '☑' : '☐')
              .fontSize(Theme.fs.md)
              .fontColor(this.isSelected(opt.id) ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
          } else {
            // ○ / ●
            Text(this.isSelected(opt.id) ? '●' : '○')
              .fontSize(Theme.fs.md)
              .fontColor(this.isSelected(opt.id) ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
          }

          Column() {
            Text(opt.label)
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Medium)
            if (opt.description.length > 0) {
              Text(opt.description)
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .margin({ top: 2 })
            }
          }
          .margin({ left: Theme.sp.sm })
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
        .onClick(() => {
          if (this.data.status !== 'pending') return
          if (this.data.multiSelect) {
            this.toggleMulti(opt.id)
          } else {
            this.onSelect(this.data.id, [opt.id])
          }
        })
      }, (opt: QuestionOption) => opt.id.length > 0 ? opt.id : opt.label)

      if (this.data.multiSelect && this.data.status === 'pending') {
        Row() {
          Text('confirm')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.SUCCESS)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.SUCCESS_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .onClick(() => {
              this.onSelect(this.data.id, this.data.selected.slice())
            })
        }
        .justifyContent(FlexAlign.End)
        .width('100%')
        .margin({ top: Theme.sp.sm })
      }

      if (this.data.status === 'answered') {
        Text(`answered: ${this.data.selected.join(', ')}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ top: Theme.sp.sm })
      }
    }
    .width('100%')
    .padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(Theme.ACCENT)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
  }

  private isSelected(optionID: string): boolean {
    for (const id of this.data.selected) {
      if (id === optionID) return true
    }
    return false
  }

  private toggleMulti(optionID: string): void {
    const idx = this.data.selected.indexOf(optionID)
    if (idx >= 0) {
      this.data.selected.splice(idx, 1)
    } else {
      this.data.selected.push(optionID)
    }
  }
}
