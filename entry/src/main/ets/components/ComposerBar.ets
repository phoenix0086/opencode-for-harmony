import { Theme } from './Theme'

/**
 * 底部 Composer 输入区
 * IDE Agent Console 风格，支持多行输入
 */
@Component
export struct ComposerBar {
  @Prop inputText: string = ''
  @Prop isSending: boolean = false
  @Prop modelLabel: string = ''
  @Prop sessionTitle: string = ''
  onTextChange: (text: string) => void = () => {}
  onSend: () => void = () => {}
  onAbort: () => void = () => {}

  build() {
    Column() {
      // Top border
      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)

      // Composer area
      Row() {
        // Model indicator
        Column() {
          Text(this.modelLabel.length > 0 ? this.modelLabel : 'model')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        .width(60)
        .justifyContent(FlexAlign.Center)

        // Input field
        TextArea({ text: this.inputText, placeholder: 'Send a message to the agent...' })
          .layoutWeight(1)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .placeholderColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(Theme.rd.md)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
          .height(Theme.COMPOSER_MIN_H)
          .onChange((v: string) => {
            this.onTextChange(v)
          })

        // Send / Abort button
        Column() {
          if (this.isSending) {
            Text('[x]')
              .fontSize(Theme.fs.lg)
              .fontColor(Theme.DANGER)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .onClick(() => {
                this.onAbort()
              })
          } else {
            Text('[>]')
              .fontSize(Theme.fs.lg)
              .fontColor(this.inputText.trim().length > 0 ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .onClick(() => {
                if (this.inputText.trim().length > 0) {
                  this.onSend()
                }
              })
          }
        }
        .width(48)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.sm })

      // Bottom info bar
      Row() {
        if (this.sessionTitle.length > 0) {
          Text(this.sessionTitle)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .maxLines(1)
            .constraintSize({ maxWidth: 300 })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Blank()
        Text('Shift+Enter to send')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')
      .padding({ left: Theme.sp.xl, right: Theme.sp.xl, bottom: Theme.sp.sm })
    }
    .width('100%')
    .backgroundColor(Theme.COMPOSER)
  }
}
