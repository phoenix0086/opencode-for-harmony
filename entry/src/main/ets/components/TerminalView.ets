/**
 * Terminal view component for displaying command output.
 * Renders monospaced text with ANSI color support (simplified).
 */
@Component
export struct TerminalView {
  @Prop lines: string[] = [];
  @Prop isRunning: boolean = false;
  @Prop prompt: string = '$ ';

  private scroller: Scroller = new Scroller();

  build() {
    Column() {
      // Terminal header
      Row() {
        Text('Terminal')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#AAAAAA')
        Blank()
        if (this.isRunning) {
          Row() {
            LoadingProgress()
              .width(12)
              .height(12)
              .color('#00C853')
            Text('Running')
              .fontSize(11)
              .fontColor('#00C853')
              .margin({ left: 6 })
          }
        }
      }
      .width('100%')
      .height(32)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#1A1A1A')

      Divider().color('#2D2D2D').width('100%')

      // Terminal output
      Scroll(this.scroller) {
        Column() {
          ForEach(this.lines, (line) => {
            Text(line)
              .fontSize(13)
              .fontFamily('monospace')
              .fontColor('#E0E0E0')
              .width('100%')
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          })

          if (this.lines.length === 0) {
            Text(this.prompt + ' Waiting for output...')
              .fontSize(13)
              .fontFamily('monospace')
              .fontColor('#555555')
              .width('100%')
              .padding(12)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#0D0D0D')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
  }
}
