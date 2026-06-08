import { Theme } from './Theme'

/**
 * Thinking heading component — shows agent activity state.
 * Three states: thinking → acting(tool) → responding
 * Matches OpenCode Desktop's thinking-heading component.
 */
@Component
export struct ThinkingHeading {
  @Prop state: string = 'thinking' // 'thinking' | 'acting' | 'responding'
  @Prop toolName: string = ''

  build() {
    Row() {
      if (this.state === 'thinking') {
        LoadingProgress()
          .width(14)
          .height(14)
          .color(Theme.ACCENT)
        Text('thinking...')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.md })
      } else if (this.state === 'acting') {
        LoadingProgress()
          .width(14)
          .height(14)
          .color(Theme.WARNING)
        Text(this.toolName.length > 0 ? `using ${this.toolName}` : 'acting...')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.WARNING)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.md })
      } else {
        LoadingProgress()
          .width(14)
          .height(14)
          .color(Theme.SUCCESS)
        Text('responding...')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.md })
      }
    }
    .padding({ left: Theme.sp.xl, top: Theme.sp.md, bottom: Theme.sp.md })
    .width('100%')
  }
}
