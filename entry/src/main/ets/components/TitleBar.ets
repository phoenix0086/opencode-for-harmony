/**
 * Custom title bar component for the OpenCode app.
 * Supports title text, window controls, and optional action buttons.
 */
@Component
export struct TitleBar {
  @Prop title: string = 'OpenCode';
  @Prop showBack: boolean = false;
  @Prop showMenu: boolean = false;
  onBack?: () => void;
  onMenuClick?: () => void;

  build() {
    Row() {
      if (this.showBack) {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onBack?.();
        })
      }

      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .margin({ left: this.showBack ? 8 : 16 })

      Blank()

      if (this.showMenu) {
        Button() {
          SymbolGlyph($r('sys.symbol.ellipsis_circle'))
            .fontSize(18)
            .fontColor(['#AAAAAA'])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onMenuClick?.();
        })
      }
    }
    .width('100%')
    .height(48)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#1A1A1A')
  }
}
