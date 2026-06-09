import { Theme } from './Theme'
import { SnapshotInfo } from '../services/V2Type'

/**
 * SnapshotPanel — 文件历史 / Undo 列表 (Sprint 2-A.3)
 *
 * 列出当前 session 的所有 snapshot(检查点),支持:
 *  - 选定一个 snapshot 查 diff
 *  - 恢复 snapshot(整个 turn 之前的状态)
 *  - 创建新 snapshot(基于最近的 message)
 *
 * v2-only。v1 server 调用 listSnapshots() 会抛 UnsupportedV2Endpoint,
 * UI 会显示 "server not supported" 占位。
 */
@Component
export struct SnapshotPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop snapshots: SnapshotInfo[] = []
  @Prop isLoading: boolean = false
  @Prop unsupported: boolean = false
  @Prop errorMessage: string = ''
  onRefresh: () => void = () => {}
  onRestore: (snapshotID: string) => void = () => {}
  onCreate: () => void = () => {}
  onDiff: (snapshotID: string) => void = () => {}

  build() {
    Column() {
      // ═══════ Header ═══════
      Row() {
        Text('history')
          .fontSize(Theme.fs.md)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)

        if (this.snapshots.length > 0) {
          Text(`${this.snapshots.length}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
        }

        Blank()

        Button(this.isLoading ? '...' : 'refresh')
          .height(28)
          .fontSize(Theme.fs.xs)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.BTN_BG)
          .fontColor(Theme.TEXT_PRIMARY)
          .enabled(!this.isLoading)
          .onClick((): void => { this.onRefresh() })

        Button('snapshot')
          .height(28)
          .fontSize(Theme.fs.xs)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.ACCENT)
          .fontColor(Theme.ACCENT_TEXT)
          .margin({ left: Theme.sp.sm })
          .enabled(!this.unsupported && !this.isLoading)
          .onClick((): void => { this.onCreate() })
      }
      .width('100%')
      .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
      .backgroundColor(Theme.HEADER_BG)

      Divider()
        .color(Theme.BORDER)
        .height(1)

      // ═══════ Body ═══════
      if (this.unsupported) {
        Column() {
          Text('!')
            .fontSize(Theme.fs.xxl)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('snapshot not supported')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
          Text('requires v2 server')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else if (this.errorMessage.length > 0) {
        Column() {
          Text('!')
            .fontSize(Theme.fs.xl)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
          Text(this.errorMessage)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else if (this.snapshots.length === 0) {
        Column() {
          Text('--')
            .fontSize(Theme.fs.xxl)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('no snapshots yet')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
          Text('click snapshot to checkpoint the current state')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else {
        List() {
          ForEach(this.snapshots, (s: SnapshotInfo) => {
            ListItem() {
              this.SnapshotRow(s)
            }
          }, (s: SnapshotInfo) => s.id)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
        .backgroundColor('transparent')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.PANEL_BG)
  }

  // ═══════ Row ═══════
  @Builder
  SnapshotRow(s: SnapshotInfo) {
    Column() {
      // Header
      Row() {
        Text(s.id.substring(0, Math.min(s.id.length, 8)))
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)

        Text(this.formatTime(s.createdAt))
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.md })

        Blank()

        Text(`${s.fileCount} files`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')

      // Description
      if (s.description.length > 0) {
        Text(s.description)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: Theme.sp.xs })
          .width('100%')
      }

      // File list preview
      if (s.files.length > 0) {
        Text(this.previewFiles(s.files))
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: Theme.sp.xs })
          .width('100%')
      }

      // Actions
      Row() {
        Button('diff')
          .height(24)
          .fontSize(Theme.fs.xs)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.BTN_BG)
          .fontColor(Theme.TEXT_PRIMARY)
          .onClick((): void => { this.onDiff(s.id) })

        Button('restore')
          .height(24)
          .fontSize(Theme.fs.xs)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.DANGER_DIM)
          .fontColor(Theme.DANGER)
          .margin({ left: Theme.sp.sm })
          .onClick((): void => { this.onRestore(s.id) })
      }
      .width('100%')
      .margin({ top: Theme.sp.sm })
    }
    .width('100%')
    .padding(Theme.sp.md)
    .backgroundColor(Theme.PANEL_BG)
    .borderBottomWidth(1)
    .borderColor(Theme.BORDER)
  }

  private formatTime(ts: number): string {
    if (ts <= 0) return ''
    const d = new Date(ts)
    const hh = String(d.getHours()).padStart(2, '0')
    const mm = String(d.getMinutes()).padStart(2, '0')
    const ss = String(d.getSeconds()).padStart(2, '0')
    return `${hh}:${mm}:${ss}`
  }

  private previewFiles(files: string[]): string {
    if (files.length === 0) return ''
    if (files.length <= 3) return files.join(', ')
    return `${files[0]}, ${files[1]}, ${files[2]} +${files.length - 3}`
  }
}
