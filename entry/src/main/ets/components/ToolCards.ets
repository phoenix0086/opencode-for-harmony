import { Theme } from './Theme'

/**
 * Specialized tool cards for OpenCode agent tools.
 * Each card renders tool-specific information with appropriate visual treatment.
 */

// ══════════ Bash Tool Card ══════════
@Component
export struct BashToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop command: string = ''
  @Prop output: string = ''
  @Prop exitCode: string = ''
  @State expanded: boolean = false

  build() {
    Column() {
      Row() {
        Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
        Text('$')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.ACCENT).borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
        Text(this.toolStatus === 'running' ? 'running' : this.exitCode.length > 0 ? `exit ${this.exitCode}` : 'done')
          .fontSize(Theme.fs.xs).fontColor(this.getStatusColor()).fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })
        Blank()
        if (this.toolStatus === 'running') {
          LoadingProgress().width(12).height(12).color(Theme.ACCENT)
        }
        Text(this.expanded ? '[-]' : '[+]')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })
          .onClick(() => { this.expanded = !this.expanded })
      }
      .width('100%')

      // Command (always visible)
      Text(this.command)
        .fontSize(Theme.fs.code).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
        .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
        .padding(Theme.sp.md).width('100%')
        .margin({ top: Theme.sp.sm })

      // Output (expandable)
      if (this.expanded && this.output.length > 0) {
        Scroll() {
          Text(this.output)
            .fontSize(Theme.fs.code).fontColor(Theme.TEXT_SECONDARY).fontFamily(Theme.FONT_MONO)
            .lineHeight(Theme.fs.code + 5).width('100%').padding(Theme.sp.md)
        }
        .scrollBar(BarState.Auto).constraintSize({ maxHeight: 200 })
        .margin({ top: Theme.sp.sm })
        .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ Edit Tool Card ══════════
@Component
export struct EditToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop filePath: string = ''
  @Prop diff: string = ''
  @State expanded: boolean = false

  build() {
    Column() {
      Row() {
        Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
        Text('E')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.WARNING).borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
        Text(this.filePath)
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: Theme.sp.sm })
        Blank()
        if (this.toolStatus === 'running') {
          LoadingProgress().width(12).height(12).color(Theme.ACCENT)
        } else {
          Text(this.toolStatus === 'success' ? 'edited' : this.toolStatus)
            .fontSize(Theme.fs.xs).fontColor(this.getStatusColor()).fontFamily(Theme.FONT_MONO)
        }
        if (this.diff.length > 0) {
          Text(this.expanded ? '[-]' : '[+]')
            .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
            .onClick(() => { this.expanded = !this.expanded })
        }
      }
      .width('100%')

      if (this.expanded && this.diff.length > 0) {
        Scroll() {
          Text(this.diff)
            .fontSize(Theme.fs.code).fontColor(Theme.TEXT_SECONDARY).fontFamily(Theme.FONT_MONO)
            .lineHeight(Theme.fs.code + 5).width('100%').padding(Theme.sp.md)
        }
        .scrollBar(BarState.Auto).constraintSize({ maxHeight: 250 })
        .margin({ top: Theme.sp.sm })
        .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ Write Tool Card ══════════
@Component
export struct WriteToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop filePath: string = ''
  @Prop content: string = ''
  @State expanded: boolean = false

  build() {
    Column() {
      Row() {
        Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
        Text('W')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.INFO).borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
        Text(this.filePath)
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: Theme.sp.sm })
        Blank()
        Text(this.content.length > 0 ? `${this.content.split('\n').length} lines` : '')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
        if (this.toolStatus === 'running') {
          LoadingProgress().width(12).height(12).color(Theme.ACCENT).margin({ left: Theme.sp.sm })
        }
        if (this.content.length > 0) {
          Text(this.expanded ? '[-]' : '[+]')
            .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
            .onClick(() => { this.expanded = !this.expanded })
        }
      }
      .width('100%')

      if (this.expanded && this.content.length > 0) {
        Scroll() {
          Text(this.content)
            .fontSize(Theme.fs.code).fontColor(Theme.TEXT_SECONDARY).fontFamily(Theme.FONT_MONO)
            .lineHeight(Theme.fs.code + 5).width('100%').padding(Theme.sp.md)
        }
        .scrollBar(BarState.Auto).constraintSize({ maxHeight: 250 })
        .margin({ top: Theme.sp.sm })
        .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ Read Tool Card ══════════
@Component
export struct ReadToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop filePath: string = ''

  build() {
    Row() {
      Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
      Text('R')
        .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(Theme.SUCCESS).borderRadius(Theme.rd.sm)
        .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
      Text(this.filePath)
        .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: Theme.sp.sm })
      Blank()
      if (this.toolStatus === 'running') {
        LoadingProgress().width(12).height(12).color(Theme.ACCENT)
      } else {
        Text('read')
          .fontSize(Theme.fs.xs).fontColor(this.getStatusColor()).fontFamily(Theme.FONT_MONO)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ Grep Tool Card ══════════
@Component
export struct GrepToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop pattern: string = ''
  @Prop matchCount: string = ''
  @Prop results: string = ''
  @State expanded: boolean = false

  build() {
    Column() {
      Row() {
        Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
        Text('G')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor('#89b4fa').borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
        Text(`/${this.pattern}/`)
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: Theme.sp.sm })
        if (this.matchCount.length > 0) {
          Text(`${this.matchCount} matches`)
            .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
        }
        Blank()
        if (this.toolStatus === 'running') {
          LoadingProgress().width(12).height(12).color(Theme.ACCENT)
        }
        if (this.results.length > 0) {
          Text(this.expanded ? '[-]' : '[+]')
            .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
            .onClick(() => { this.expanded = !this.expanded })
        }
      }
      .width('100%')

      if (this.expanded && this.results.length > 0) {
        Scroll() {
          Text(this.results)
            .fontSize(Theme.fs.code).fontColor(Theme.TEXT_SECONDARY).fontFamily(Theme.FONT_MONO)
            .lineHeight(Theme.fs.code + 5).width('100%').padding(Theme.sp.md)
        }
        .scrollBar(BarState.Auto).constraintSize({ maxHeight: 200 })
        .margin({ top: Theme.sp.sm })
        .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ Glob Tool Card ══════════
@Component
export struct GlobToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop pattern: string = ''
  @Prop fileCount: string = ''

  build() {
    Row() {
      Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
      Text('*')
        .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .backgroundColor('#a6adc8').borderRadius(Theme.rd.sm)
        .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
      Text(this.pattern)
        .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_PRIMARY).fontFamily(Theme.FONT_MONO)
        .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: Theme.sp.sm })
      if (this.fileCount.length > 0) {
        Text(`${this.fileCount} files`)
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
      }
      Blank()
      if (this.toolStatus === 'running') {
        LoadingProgress().width(12).height(12).color(Theme.ACCENT)
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}

// ══════════ WebFetch Tool Card ══════════
@Component
export struct WebFetchToolCard {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toolStatus: string = ''
  @Prop url: string = ''
  @Prop summary: string = ''
  @State expanded: boolean = false

  build() {
    Column() {
      Row() {
        Column().width(3).height(20).backgroundColor(this.getStatusColor()).borderRadius(2).margin({ right: Theme.sp.md })
        Text('G')
          .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_INVERSE).fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(Theme.INFO).borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })
        Text(this.url)
          .fontSize(Theme.fs.xs).fontColor(Theme.ACCENT).fontFamily(Theme.FONT_MONO)
          .layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: Theme.sp.sm })
        Blank()
        if (this.toolStatus === 'running') {
          LoadingProgress().width(12).height(12).color(Theme.ACCENT)
        } else {
          Text('fetched')
            .fontSize(Theme.fs.xs).fontColor(this.getStatusColor()).fontFamily(Theme.FONT_MONO)
        }
        if (this.summary.length > 0) {
          Text(this.expanded ? '[-]' : '[+]')
            .fontSize(Theme.fs.xs).fontColor(Theme.TEXT_MUTED).fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
            .onClick(() => { this.expanded = !this.expanded })
        }
      }
      .width('100%')

      if (this.expanded && this.summary.length > 0) {
        Text(this.summary)
          .fontSize(Theme.fs.code).fontColor(Theme.TEXT_SECONDARY).fontFamily(Theme.FONT_MONO)
          .lineHeight(Theme.fs.code + 5).width('100%').padding(Theme.sp.md)
          .margin({ top: Theme.sp.sm })
          .backgroundColor(Theme.CODE_BG).borderRadius(Theme.rd.sm)
          .constraintSize({ maxHeight: 200 })
      }
    }
    .width('100%').padding(Theme.sp.md)
    .backgroundColor(Theme.TOOL_BG).borderRadius(Theme.rd.md)
    .borderWidth(1).borderColor(this.toolStatus === 'running' ? Theme.ACCENT_DIM : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): string {
    if (this.toolStatus === 'running') return Theme.ACCENT
    if (this.toolStatus === 'success') return Theme.SUCCESS
    if (this.toolStatus === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }
}
