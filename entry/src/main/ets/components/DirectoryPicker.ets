import { Theme } from './Theme'

// ════════════════════════════════════════════════════════════
// ProjectEntry — data model for a project/workspace item
// ════════════════════════════════════════════════════════════

export class ProjectEntry {
  id: string = ''
  name: string = ''
  directory: string = ''
  worktree: string = ''
  lastOpened: string = ''
  isActive: boolean = false
}

// ════════════════════════════════════════════════════════════
// DirectoryPicker — project/workspace selection dialog
// ════════════════════════════════════════════════════════════

@Component
export struct DirectoryPicker {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop visible: boolean = false
  @Prop projects: ProjectEntry[] = []
  @Prop currentDirectory: string = ''
  onSelect: (directory: string) => void = () => {}
  onDismiss: () => void = () => {}
  @State searchQuery: string = ''

  // ── Helpers ──────────────────────────────────────────────

  getFilteredProjects(): ProjectEntry[] {
    if (this.searchQuery.length === 0) {
      return this.projects
    }
    const q: string = this.searchQuery.toLowerCase()
    const result: ProjectEntry[] = []
    for (let i = 0; i < this.projects.length; i++) {
      const p: ProjectEntry = this.projects[i]
      if (p.name.toLowerCase().indexOf(q) >= 0 ||
          p.directory.toLowerCase().indexOf(q) >= 0) {
        result.push(p)
      }
    }
    return result
  }

  getShortPath(dir: string): string {
    if (dir.length === 0) {
      return ''
    }
    const parts: string[] = dir.split('/')
    if (parts.length <= 2) {
      return dir
    }
    return '.../' + parts[parts.length - 2] + '/' + parts[parts.length - 1]
  }

  // ── Build ────────────────────────────────────────────────

  build() {
    if (this.visible) {
      Stack() {
        // ── Semi-transparent backdrop ──
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000088')
          .onClick(() => {
            this.onDismiss()
          })

        // ── Floating dialog ──
        Column() {

          // ── Header: title + dismiss ──
          Row() {
            Text('SELECT PROJECT')
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)

            Text('\u00D7')
              .fontSize(Theme.fs.xl)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .width(28)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.onDismiss()
              })
          }
          .width('100%')
          .padding({
            left: Theme.sp.xl,
            right: Theme.sp.lg,
            top: Theme.sp.lg,
            bottom: Theme.sp.md
          })

          // ── Search input ──
          Row() {
            Text('>')
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ right: Theme.sp.md })

            TextInput({ placeholder: 'filter projects...', text: this.searchQuery })
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_PRIMARY)
              .placeholderColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor('transparent')
              .layoutWeight(1)
              .caretColor(Theme.ACCENT)
              .onChange((value: string) => {
                this.searchQuery = value
              })
          }
          .width('100%')
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.md
          })
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(Theme.rd.md)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.xs,
            bottom: Theme.sp.md
          })

          // ── Project list (scrollable) ──
          Scroll() {
            Column() {
              if (this.getFilteredProjects().length === 0) {
                // Empty state
                Column() {
                  Text('no matching projects')
                    .fontSize(Theme.fs.sm)
                    .fontColor(Theme.TEXT_MUTED)
                    .fontFamily(Theme.FONT_MONO)
                    .textAlign(TextAlign.Center)
                }
                .width('100%')
                .constraintSize({ minHeight: 80 })
                .justifyContent(FlexAlign.Center)
              } else {
                ForEach(this.getFilteredProjects(), (project: ProjectEntry, index: number) => {
                  Row() {
                    // Active indicator prefix
                    Text(project.isActive ? '>' : ' ')
                      .fontSize(Theme.fs.sm)
                      .fontColor(project.isActive ? Theme.ACCENT : Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .fontWeight(project.isActive ? FontWeight.Bold : FontWeight.Normal)
                      .width(18)
                      .textAlign(TextAlign.Center)

                    // Project name + directory path
                    Column() {
                      Text(project.name)
                        .fontSize(Theme.fs.md)
                        .fontColor(Theme.TEXT_PRIMARY)
                        .fontFamily(Theme.FONT_MONO)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Text(this.getShortPath(project.directory))
                        .fontSize(Theme.fs.xs)
                        .fontColor(Theme.TEXT_MUTED)
                        .fontFamily(Theme.FONT_MONO)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: Theme.sp.xs })
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: Theme.sp.md })

                    // Active badge
                    if (project.isActive) {
                      Text('active')
                        .fontSize(Theme.fs.xs)
                        .fontColor(Theme.SUCCESS)
                        .fontFamily(Theme.FONT_MONO)
                        .fontWeight(FontWeight.Bold)
                        .padding({
                          left: Theme.sp.md,
                          right: Theme.sp.md,
                          top: Theme.sp.xs,
                          bottom: Theme.sp.xs
                        })
                        .backgroundColor(Theme.SUCCESS_DIM)
                        .borderRadius(Theme.rd.sm)
                    }
                  }
                  .width('100%')
                  .padding({
                    left: Theme.sp.lg,
                    right: Theme.sp.lg,
                    top: Theme.sp.md,
                    bottom: Theme.sp.md
                  })
                  .backgroundColor(project.isActive ? Theme.ACTIVE_BG : 'transparent')
                  .borderRadius(Theme.rd.sm)
                  .borderWidth({ left: project.isActive ? 2 : 0 })
                  .borderColor({ left: project.isActive ? Theme.ACCENT : 'transparent' })
                  .onClick(() => {
                    this.onSelect(project.directory)
                    this.onDismiss()
                  })
                }, (project: ProjectEntry, index: number) => project.id + '_' + index)
              }
            }
            .width('100%')
          }
          .constraintSize({ maxHeight: 340 })
          .scrollBar(BarState.Auto)
          .width('100%')

          // ── Footer: recent projects count ──
          Row() {
            Divider()
              .color(Theme.BORDER)
              .strokeWidth(1)
              .layoutWeight(1)

            Text('recent projects \u00B7 ' + this.projects.length)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ left: Theme.sp.md, right: Theme.sp.md })

            Divider()
              .color(Theme.BORDER)
              .strokeWidth(1)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.lg
          })
          .alignItems(VerticalAlign.Center)
        }
        .width(400)
        .constraintSize({ maxHeight: 500 })
        .backgroundColor(Theme.PANEL)
        .borderRadius(Theme.rd.lg)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
      }
      .width('100%')
      .height('100%')
      .alignContent(Alignment.Center)
    }
  }
}
