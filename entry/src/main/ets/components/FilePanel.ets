import { Theme } from './Theme'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { Runner } from '../models/Runner'

/**
 * File Panel
 * 工作区文件浏览器 — 中心面板
 * 显示项目信息和文件列表
 */
@Component
export struct FilePanel {
  @Prop projectName: string = ''
  @Prop branchName: string = ''
  @Prop activeRunner: Runner | null = null
  @State filePaths: string[] = []
  @State isLoading: boolean = false
  @State errorMsg: string = ''

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

  build() {
    Column() {
      // Header
      Row() {
        Text('WORKSPACE')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

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
      } else {
        List() {
          ForEach(this.filePaths, (path: string) => {
            ListItem() {
              Row() {
                Text(this.isDirectory(path) ? 'D' : 'F')
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.isDirectory(path) ? Theme.ACCENT : Theme.TEXT_MUTED)
                  .fontFamily(Theme.FONT_MONO)
                  .fontWeight(FontWeight.Bold)
                  .width(16)

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

  private isDirectory(path: string): boolean {
    return path.endsWith('/')
  }
}
