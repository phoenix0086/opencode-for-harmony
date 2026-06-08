import { Theme } from './Theme'
import { FileDiff } from '../models/Event'

/**
 * Diff panel — M17 enhanced
 * Right-side panel showing file change diffs with:
 *  - Line-level diff annotations (color-coded patch lines)
 *  - Expandable / collapsible per-file diff detail
 *  - File status summary badges (added / modified / deleted)
 *  - Search / filter by file name
 */
@Component
export struct DiffPanel {
  @Prop diffs: FileDiff[] = []
  @Prop sessionTitle: string = ''

  /** File paths currently in the expanded state */
  @State expandedFiles: string[] = []
  /** Search query for filtering the file list */
  @State searchQuery: string = ''

  build() {
    Column() {
      // ── Header ──
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

      // ── Status summary badges ──
      if (this.diffs.length > 0) {
        Row({ space: Theme.sp.sm }) {
          if (this.countByStatus('added') > 0) {
            Text(`${this.countByStatus('added')} added`)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.DIFF_ADD_TEXT)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor(Theme.DIFF_ADD_BG)
              .borderRadius(Theme.rd.sm)
              .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }
          if (this.countByStatus('modified') > 0) {
            Text(`${this.countByStatus('modified')} modified`)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.ACCENT)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor(Theme.ACCENT_DIM)
              .borderRadius(Theme.rd.sm)
              .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }
          if (this.countByStatus('deleted') > 0) {
            Text(`${this.countByStatus('deleted')} deleted`)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.DIFF_DEL_TEXT)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor(Theme.DIFF_DEL_BG)
              .borderRadius(Theme.rd.sm)
              .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
          }
        }
        .width('100%')
        .padding({ left: Theme.sp.lg, right: Theme.sp.lg, bottom: Theme.sp.md })
      }

      // ── Additions / Deletions summary bar ──
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

      // ── Search / filter input ──
      if (this.diffs.length > 0) {
        TextInput({ placeholder: 'Filter files...', text: this.searchQuery })
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .placeholderColor(Theme.TEXT_MUTED)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(Theme.rd.md)
          .padding({
            left: Theme.sp.md,
            right: Theme.sp.md,
            top: Theme.sp.sm,
            bottom: Theme.sp.sm
          })
          .margin({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.md
          })
          .onChange((value: string) => {
            this.searchQuery = value
          })
      }

      // ── File list ──
      if (this.diffs.length === 0) {
        Column() {
          Text('No changes')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('No assistant message available for diff. Send a prompt to generate code changes.')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.md })
            .textAlign(TextAlign.Center)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.getFilteredDiffs().length === 0) {
        Column() {
          Text('No matching files')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.getFilteredDiffs(), (diff: FileDiff) => {
            ListItem() {
              Column() {
                // ── File header row ──
                Row() {
                  // Status icon
                  Text(this.getStatusSymbol(diff.status))
                    .fontSize(Theme.fs.xs)
                    .fontColor(this.getStatusColor(diff.status))
                    .fontFamily(Theme.FONT_MONO)
                    .fontWeight(FontWeight.Bold)
                    .width(16)

                  // File path
                  Text(diff.file)
                    .fontSize(Theme.fs.sm)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .fontFamily(Theme.FONT_MONO)
                    .maxLines(1)
                    .layoutWeight(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })

                  // Additions / Deletions counts
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

                  // ── Expand / collapse toggle ──
                  Text(this.isExpanded(diff.file) ? '[-]' : '[+]')
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.ACCENT)
                    .fontFamily(Theme.FONT_MONO)
                    .fontWeight(FontWeight.Bold)
                    .margin({ left: Theme.sp.md })
                    .onClick(() => {
                      this.toggleExpand(diff.file)
                    })
                }
                .width('100%')

                // ── Patch preview — collapsed (first 4 lines) ──
                if (diff.patch.length > 0 && !this.isExpanded(diff.file)) {
                  Column({ space: 1 }) {
                    ForEach(this.getDiffLines(diff.patch, false), (line: string, idx: number) => {
                      Row() {
                        Text(line.length > 0 ? line : ' ')
                          .fontSize(Theme.fs.xs)
                          .fontColor(this.getLineTextColor(line))
                          .fontFamily(Theme.FONT_MONO)
                          .fontStyle(this.isHunkHeader(line) ? FontStyle.Italic : FontStyle.Normal)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .width('100%')
                      .backgroundColor(this.getLineBgColor(line))
                      .padding({ left: Theme.sp.sm, right: Theme.sp.sm })
                    }, (line: string, idx: number) => `${idx}_${line}`)
                  }
                  .margin({ top: Theme.sp.sm })
                  .backgroundColor(Theme.CODE_BG)
                  .borderRadius(Theme.rd.sm)
                  .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
                  .width('100%')
                  .clip(true)
                }

                // ── Patch detail — expanded (all lines) ──
                if (diff.patch.length > 0 && this.isExpanded(diff.file)) {
                  Column({ space: 1 }) {
                    ForEach(this.getDiffLines(diff.patch, true), (line: string, idx: number) => {
                      Row() {
                        Text(line.length > 0 ? line : ' ')
                          .fontSize(Theme.fs.xs)
                          .fontColor(this.getLineTextColor(line))
                          .fontFamily(Theme.FONT_MONO)
                          .fontStyle(this.isHunkHeader(line) ? FontStyle.Italic : FontStyle.Normal)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .width('100%')
                      .backgroundColor(this.getLineBgColor(line))
                      .padding({ left: Theme.sp.sm, right: Theme.sp.sm })
                    }, (line: string, idx: number) => `${idx}_${line}`)
                  }
                  .margin({ top: Theme.sp.sm })
                  .backgroundColor(Theme.CODE_BG)
                  .borderRadius(Theme.rd.sm)
                  .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
                  .width('100%')
                  .clip(true)
                }
              }
              .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
              .borderWidth({ bottom: 1 })
              .borderColor(Theme.BORDER)
            }
          }, (diff: FileDiff) => diff.file)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
        .scrollBar(BarState.Auto)
        .backgroundColor('transparent')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.SIDEBAR)
  }

  // ══════════ Expand / Collapse ══════════

  private isExpanded(filePath: string): boolean {
    return this.expandedFiles.indexOf(filePath) >= 0
  }

  private toggleExpand(filePath: string): void {
    let idx: number = this.expandedFiles.indexOf(filePath)
    if (idx >= 0) {
      let updated: string[] = []
      for (let i: number = 0; i < this.expandedFiles.length; i++) {
        if (i !== idx) {
          updated.push(this.expandedFiles[i])
        }
      }
      this.expandedFiles = updated
    } else {
      let updated: string[] = []
      for (let i: number = 0; i < this.expandedFiles.length; i++) {
        updated.push(this.expandedFiles[i])
      }
      updated.push(filePath)
      this.expandedFiles = updated
    }
  }

  // ══════════ Status Helpers ══════════

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

  private countByStatus(status: string): number {
    let count: number = 0
    for (let i: number = 0; i < this.diffs.length; i++) {
      if (this.diffs[i].status === status) {
        count++
      }
    }
    return count
  }

  // ══════════ Diff Line Parsing ══════════

  /**
   * Parse a patch string into individual lines for display.
   * When `expanded` is false only the first 4 lines are returned.
   */
  private getDiffLines(patch: string, expanded: boolean): string[] {
    let allLines: string[] = patch.split('\n')
    let result: string[] = []
    let limit: number = expanded ? allLines.length : 4
    for (let i: number = 0; i < allLines.length && i < limit; i++) {
      result.push(allLines[i])
    }
    return result
  }

  /** Background colour for a diff line based on its prefix. */
  private getLineBgColor(line: string): string {
    if (line.length > 0 && line.charAt(0) === '+' && !line.startsWith('+++')) {
      return Theme.DIFF_ADD_BG
    }
    if (line.length > 0 && line.charAt(0) === '-' && !line.startsWith('---')) {
      return Theme.DIFF_DEL_BG
    }
    return 'transparent'
  }

  /** Text colour for a diff line based on its prefix. */
  private getLineTextColor(line: string): string {
    if (line.startsWith('@@')) {
      return Theme.ACCENT
    }
    if (line.length > 0 && line.charAt(0) === '+' && !line.startsWith('+++')) {
      return Theme.DIFF_ADD_TEXT
    }
    if (line.length > 0 && line.charAt(0) === '-' && !line.startsWith('---')) {
      return Theme.DIFF_DEL_TEXT
    }
    return Theme.TEXT_MUTED
  }

  /** True when the line is a `@@ ... @@` hunk header. */
  private isHunkHeader(line: string): boolean {
    return line.startsWith('@@')
  }

  // ══════════ Filtering ══════════

  private getFilteredDiffs(): FileDiff[] {
    if (this.searchQuery.length === 0) {
      return this.diffs
    }
    let query: string = this.searchQuery.toLowerCase()
    let result: FileDiff[] = []
    for (let i: number = 0; i < this.diffs.length; i++) {
      if (this.diffs[i].file.toLowerCase().indexOf(query) >= 0) {
        result.push(this.diffs[i])
      }
    }
    return result
  }

  // ══════════ Totals ══════════

  private totalAdditions(): number {
    let total: number = 0
    for (let i: number = 0; i < this.diffs.length; i++) {
      total += this.diffs[i].additions
    }
    return total
  }

  private totalDeletions(): number {
    let total: number = 0
    for (let i: number = 0; i < this.diffs.length; i++) {
      total += this.diffs[i].deletions
    }
    return total
  }
}
