import { Theme } from './Theme'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { Runner } from '../models/Runner'

/**
 * File Panel
 * 工作区文件浏览器 — 中心面板
 * 显示项目信息和文件列表
 *
 * M17: file-type icons, search filter, file count
 */
@Component
export struct FilePanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop projectName: string = ''
  @Prop branchName: string = ''
  @Prop activeRunner: Runner | null = null
  @State filePaths: string[] = []
  @State isLoading: boolean = false
  @State errorMsg: string = ''
  @State searchText: string = ''

  async aboutToAppear(): Promise<void> {
    await this.loadFiles()
  }

  async loadFiles(): Promise<void> {
    if (this.activeRunner === null) {
      this.errorMsg = 'No server connected'
      return
    }
    this.isLoading = true
    this.errorMsg = ''
    try {
      const client = new OpenCodeClient(this.activeRunner)
      const result = await client.listFiles('/')
      const paths: string[] = []
      for (const item of result) {
        const pathVal: string = item['path'] as string
        if (pathVal) {
          paths.push(pathVal)
        }
      }
      this.filePaths = paths
    } catch (e) {
      this.errorMsg = `Failed to load files: ${String(e)}`
    }
    this.isLoading = false
  }

  /** Return filtered file list based on search text (case-insensitive) */
  private getFilteredFiles(): string[] {
    if (this.searchText.length === 0) {
      return this.filePaths
    }
    const needle: string = this.searchText.toLowerCase()
    const result: string[] = []
    for (let i = 0; i < this.filePaths.length; i++) {
      if (this.filePaths[i].toLowerCase().indexOf(needle) >= 0) {
        result.push(this.filePaths[i])
      }
    }
    return result
  }

  /** File-type icon label based on extension */
  private getFileIcon(path: string): string {
    if (this.isDirectory(path)) {
      return '\u25b8'
    }
    const ext: string = this.getExtension(path)
    if (ext === 'ts' || ext === 'ets' || ext === 'js') {
      return 'TS'
    }
    if (ext === 'json') {
      return '{}'
    }
    if (ext === 'md') {
      return 'MD'
    }
    if (ext === 'css' || ext === 'scss') {
      return '#'
    }
    if (ext === 'html') {
      return '<>'
    }
    if (ext === 'png' || ext === 'jpg' || ext === 'svg') {
      return 'IMG'
    }
    if (this.isGitignore(path)) {
      return 'G'
    }
    return 'F'
  }

  /** Color for the file-type icon label */
  private getFileIconColor(path: string): string {
    if (this.isDirectory(path)) {
      return Theme.ACCENT
    }
    const ext: string = this.getExtension(path)
    if (ext === 'ts' || ext === 'ets' || ext === 'js') {
      return Theme.WARNING
    }
    if (ext === 'json') {
      return Theme.INFO
    }
    if (ext === 'md') {
      return Theme.SUCCESS
    }
    if (ext === 'css' || ext === 'scss') {
      return Theme.ACCENT
    }
    if (ext === 'html') {
      return Theme.DANGER
    }
    if (ext === 'png' || ext === 'jpg' || ext === 'svg') {
      return Theme.WARNING
    }
    if (this.isGitignore(path)) {
      return Theme.TEXT_MUTED
    }
    return Theme.TEXT_MUTED
  }

  private isDirectory(path: string): boolean {
    return path.endsWith('/')
  }

  private isGitignore(path: string): boolean {
    return path.endsWith('.gitignore')
  }

  /** Extract lowercase file extension from a path */
  private getExtension(path: string): string {
    const dotIdx: number = path.lastIndexOf('.')
    if (dotIdx <= 0 || dotIdx >= path.length - 1) {
      return ''
    }
    return path.substring(dotIdx + 1).toLowerCase()
  }

  /** Build file-count label: "N files" or "N of M files" when filtered */
  private getFileCountText(): string {
    const total: number = this.filePaths.length
    const filtered: string[] = this.getFilteredFiles()
    if (this.searchText.length > 0 && filtered.length !== total) {
      return `${filtered.length} of ${total} files`
    }
    return `${total} files`
  }

  build() {
    Column() {
      // Header with file count
      Row() {
        Text('WORKSPACE')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        Text(this.getFileCountText())
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ right: Theme.sp.lg })

        Text('refresh')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
          .onClick(() => {
            this.loadFiles()
          })
      }
      .width('100%')
      .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.lg, bottom: Theme.sp.md })

      // Search filter
      TextInput({ text: this.searchText, placeholder: 'filter files...' })
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .placeholderColor(Theme.TEXT_MUTED)
        .backgroundColor(Theme.INPUT_BG)
        .border({ width: 1, color: Theme.BORDER, radius: Theme.rd.sm })
        .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
        .width('100%')
        .margin({ left: Theme.sp.xl, right: Theme.sp.xl, bottom: Theme.sp.md })
        .onChange((value: string) => {
          this.searchText = value
        })

      // Project info
      Column() {
        Row() {
          Text('project')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .width(70)
          Text(this.projectName.length > 0 ? this.projectName : '(unknown)')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
        }
        .width('100%')
        .margin({ bottom: Theme.sp.sm })

        Row() {
          Text('branch')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .width(70)
          Text(this.branchName.length > 0 ? this.branchName : '-')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: Theme.sp.xl, right: Theme.sp.xl, bottom: Theme.sp.lg })
      .alignItems(HorizontalAlign.Start)

      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      // File list
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(Theme.ACCENT)
          Text('Loading files...')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg.length > 0) {
        Column() {
          Text(this.errorMsg)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .textAlign(TextAlign.Center)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
      } else if (this.filePaths.length === 0) {
        Column() {
          Text('No files loaded')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('Connect to OpenCode Server and select a workspace to browse files.')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
            .textAlign(TextAlign.Center)
            .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
          Text('Uses OpenCode /file and /path APIs')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredFiles().length === 0) {
        Column() {
          Text('No matching files')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text(`No files match "${this.searchText}"`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
            .textAlign(TextAlign.Center)
            .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.getFilteredFiles(), (path: string) => {
            ListItem() {
              Row() {
                Text(this.getFileIcon(path))
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.getFileIconColor(path))
                  .fontFamily(Theme.FONT_MONO)
                  .fontWeight(FontWeight.Bold)
                  .width(24)
                  .textAlign(TextAlign.Center)

                Text(path)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.TEXT_PRIMARY)
                  .fontFamily(Theme.FONT_MONO)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.sm, bottom: Theme.sp.sm })
            }
          }, (path: string) => path)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Auto)
        .backgroundColor('transparent')
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Theme.BG)
    .alignItems(HorizontalAlign.Start)
  }
}
