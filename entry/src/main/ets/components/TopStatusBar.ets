import { Theme } from './Theme'

/**
 * 顶部状态栏
 * 显示 Project / Branch / Model / Server / Token 信息
 */
@Component
export struct TopStatusBar {
  @Prop projectName: string = 'No Project'
  @Prop branchName: string = 'main'
  @Prop modelName: string = '--'
  @Prop serverUrl: string = '--'
  @Prop serverVersion: string = '--'
  @Prop tokenCost: string = '0 tokens'
  @Prop isConnected: boolean = false

  build() {
    Row() {
      // Left: Project & Branch
      Row() {
        // Connection dot
        Circle({ width: 6, height: 6 })
          .fill(this.isConnected ? Theme.SUCCESS : Theme.DANGER)
          .margin({ right: Theme.sp.md })

        Text(this.projectName)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .constraintSize({ maxWidth: 200 })
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.branchName.length > 0) {
          Text('/')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ left: Theme.sp.sm, right: Theme.sp.sm })

          Text(this.branchName)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .maxLines(1)
            .constraintSize({ maxWidth: 120 })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }

      Blank()

      // Center: Model
      Row() {
        Text('model')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ right: Theme.sp.sm })

        Text(this.modelName)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.ACCENT_TEXT)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(1)
          .constraintSize({ maxWidth: 250 })
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .backgroundColor(Theme.ACCENT_DIM)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
      }

      Blank()

      // Right: Server & Token
      Row() {
        Text(this.serverUrl)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(1)
          .constraintSize({ maxWidth: 150 })
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.serverVersion.length > 0) {
          Text(`v${this.serverVersion}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ left: Theme.sp.md })
        }

        Divider()
          .vertical(true)
          .height(14)
          .color(Theme.BORDER)
          .margin({ left: Theme.sp.lg, right: Theme.sp.lg })

        Text(this.tokenCost)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
    }
    .width('100%')
    .height(Theme.STATUS_BAR_H)
    .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
    .backgroundColor(Theme.STATUSBAR)
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }
}
