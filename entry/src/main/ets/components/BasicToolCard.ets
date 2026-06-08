import { Theme } from './Theme'

/**
 * Basic tool card — collapsible card for tool execution display.
 * Matches OpenCode Desktop's basic-tool component.
 */
@Component
export struct BasicToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolName: string = ''
  @Prop toolStatus: string = '' // 'running' | 'success' | 'error' | 'cancelled'
  @Prop summary: string = ''
  @Prop detail: string = ''
  @Prop step: number = 0
  @State expanded: boolean = false
  @State cardOpacity: number = 0

  aboutToAppear(): void {
    setTimeout(() => {
      this.cardOpacity = 1
    }, 50)
  }

  build() {
    Column() {
      // Header row (always visible)
      Row() {
        // Status bar
        Column()
          .width(3)
          .height(20)
          .backgroundColor(this.getStatusColor())
          .borderRadius(2)
          .margin({ right: Theme.sp.md })

        // Tool name badge
        Text(this.toolName)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(Theme.CODE_BG)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })

        // Status label
        Text(this.getStatusLabel())
          .fontSize(Theme.fs.xs)
          .fontColor(this.getStatusColor())
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })

        // Step
        if (this.step > 0) {
          Text(`#${this.step}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
        }

        Blank()

        // Spinner for running
        if (this.toolStatus === 'running') {
          LoadingProgress()
            .width(12)
            .height(12)
            .color(Theme.ACCENT)
        }

        // Summary text (truncated)
        if (this.summary.length > 0) {
          Text(this.summary)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: Theme.sp.md })
        }

        // Expand toggle
        if (this.detail.length > 0) {
          Text(this.expanded ? '[-]' : '[+]')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
            .onClick(() => { this.expanded = !this.expanded })
        }
      }
      .width('100%')

      // Expanded detail (animated)
      if (this.detail.length > 0) {
        Column() {
          Scroll() {
            Text(this.detail)
              .fontSize(Theme.fs.code)
              .fontColor(Theme.TEXT_SECONDARY)
              .fontFamily(Theme.FONT_MONO)
              .lineHeight(Theme.fs.code + 5)
              .width('100%')
              .padding(Theme.sp.md)
          }
          .scrollBar(BarState.Auto)
          .width('100%')
        }
        .constraintSize({ maxHeight: this.expanded ? 250 : 0 })
        .clip(true)
        .opacity(this.expanded ? 1 : 0)
        .animation({ duration: 250, curve: Curve.EaseInOut })
        .margin({ top: this.expanded ? Theme.sp.sm : 0 })
        .backgroundColor(Theme.CODE_BG)
        .borderRadius(Theme.rd.sm)
        .width('100%')
      }
    }
    .width('100%')
    .padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
    .opacity(this.cardOpacity)
    .animation({ duration: 200, curve: Curve.FastOutSlowIn })
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    if (this.toolStatus === 'cancelled') return Theme.TEXT_MUTED
    return Theme.TEXT_MUTED
  }

  private getStatusLabel(): string {
    if (this.toolStatus === 'running') return 'running'
    if (this.toolStatus === 'success') return 'done'
    if (this.toolStatus === 'error') return 'error'
    if (this.toolStatus === 'cancelled') return 'cancelled'
    return this.toolStatus
  }
}
