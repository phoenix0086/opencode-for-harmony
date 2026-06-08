import { Theme } from './Theme'
import { FileDiff } from '../models/Event'

/**
 * Diff 面板
 * 右侧面板显示文件变更差异
 */

class DiffFileEntry {
  path: string = ''
  status: string = ''
  additions: number = 0
  deletions: number = 0
  patch: string = ''
}

@Component
export struct DiffPanel {
  @Prop diffs: FileDiff[] = []
  @Prop sessionTitle: string = ''

  build() {
    Column() {
      // Header
      Row() {
        Text('CHANGES')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        if (this.diffs.length > 0) {
          Text(`${this.diffs.length} files`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.lg, bottom: Theme.sp.md })

      // Summary bar
      if (this.diffs.length > 0) {
        Row() {
          Text(`+${this.totalAdditions()}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.DIFF_ADD_TEXT)
            .fontFamily(Theme.FONT_MONO)
          Text(`-${this.totalDeletions()}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.DIFF_DEL_TEXT)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.lg })
        }
        .width('100%')
        .padding({ left: Theme.sp.lg, right: Theme.sp.lg, bottom: Theme.sp.md })
      }

      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      // File list
      List() {
        ForEach(this.diffs, (diff: FileDiff) => {
          ListItem() {
            Column() {
              // File header
              Row() {
                // Status icon
                Text(this.getStatusSymbol(diff.status))
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.getStatusColor(diff.status))
                  .fontFamily(Theme.FONT_MONO)
                  .fontWeight(FontWeight.Bold)
                  .width(16)

                // File path
                Text(diff.path)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.TEXT_PRIMARY)
                  .fontFamily(Theme.FONT_MONO)
                  .maxLines(1)
                  .layoutWeight(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                // Additions / Deletions
                if (diff.additions > 0) {
                  Text(`+${diff.additions}`)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.DIFF_ADD_TEXT)
                    .fontFamily(Theme.FONT_MONO)
                    .margin({ left: Theme.sp.sm })
                }
                if (diff.deletions > 0) {
                  Text(`-${diff.deletions}`)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.DIFF_DEL_TEXT)
                    .fontFamily(Theme.FONT_MONO)
                    .margin({ left: Theme.sp.sm })
                }
              }
              .width('100%')

              // Patch preview (first few lines)
              if (diff.patch.length > 0) {
                Text(this.getPatchPreview(diff.patch))
                  .fontSize(Theme.fs.xs)
                  .fontColor(Theme.TEXT_MUTED)
                  .fontFamily(Theme.FONT_MONO)
                  .margin({ top: Theme.sp.sm })
                  .maxLines(4)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .backgroundColor(Theme.CODE_BG)
                  .borderRadius(Theme.rd.sm)
                  .padding(Theme.sp.sm)
                  .width('100%')
              }
            }
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
            .borderWidth({ bottom: 1 })
            .borderColor(Theme.BORDER)
          }
        }, (diff: FileDiff) => diff.path)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })
      .scrollBar(BarState.Auto)
      .backgroundColor('transparent')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.SIDEBAR)
  }

  private getStatusSymbol(status: string): string {
    if (status === 'added') return 'A'
    if (status === 'modified') return 'M'
    if (status === 'deleted') return 'D'
    if (status === 'renamed') return 'R'
    return '?'
  }

  private getStatusColor(status: string): string {
    if (status === 'added') return Theme.SUCCESS
    if (status === 'modified') return Theme.ACCENT
    if (status === 'deleted') return Theme.DANGER
    if (status === 'renamed') return Theme.WARNING
    return Theme.TEXT_MUTED
  }

  private getPatchPreview(patch: string): string {
    const lines = patch.split('\n')
    const preview: string[] = []
    for (let i = 0; i < lines.length && i < 6; i++) {
      preview.push(lines[i])
    }
    return preview.join('\n')
  }

  private totalAdditions(): number {
    let total = 0
    for (const d of this.diffs) {
      total += d.additions
    }
    return total
  }

  private totalDeletions(): number {
    let total = 0
    for (const d of this.diffs) {
      total += d.deletions
    }
    return total
  }
}
