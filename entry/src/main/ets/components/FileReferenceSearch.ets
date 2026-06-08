import { Theme } from './Theme'
import { FileNode } from '../models/Event'

/**
 * File reference model for @ file search in ComposerBar.
 * Represents a single file or directory that can be attached to a prompt.
 */
export class FileReference {
  path: string = ''
  name: string = ''
  type: string = '' // 'file' | 'directory'
  selected: boolean = false
}

/**
 * FileReferenceSearch
 * Floating popup that appears when user types @ in the ComposerBar.
 * Displays a searchable, scrollable list of files/directories to attach.
 */
@Component
export struct FileReferenceSearch {
  @Prop visible: boolean = false
  @Prop searchQuery: string = ''
  @Prop files: FileReference[] = []
  onSelectFile: (file: FileReference) => void = () => {}
  onDismiss: () => void = () => {}

  build() {
    if (this.visible) {
      Stack() {
        // Transparent backdrop to dismiss on outside tap
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.onDismiss()
          })

        // Popup card
        Column() {
          // ── Header row ──
          Row() {
            Text('Attach files')
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)

            Text('\u2715')
              .fontSize(Theme.fs.md)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .width(24)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.onDismiss()
              })
          }
          .width('100%')
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.md,
            bottom: Theme.sp.sm
          })

          // ── Search display (read-only) ──
          Row() {
            Text('@' + this.searchQuery)
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.ACCENT)
              .fontFamily(Theme.FONT_MONO)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({
            left: Theme.sp.lg,
            right: Theme.sp.lg,
            top: Theme.sp.sm,
            bottom: Theme.sp.sm
          })
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(Theme.rd.sm)
          .margin({ left: Theme.sp.md, right: Theme.sp.md })

          // ── Divider ──
          Divider()
            .color(Theme.BORDER)
            .strokeWidth(1)
            .margin({ top: Theme.sp.sm, bottom: Theme.sp.xs })

          // ── File list ──
          if (this.files.length === 0) {
            Column() {
              Text('No matching files')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .constraintSize({ minHeight: 60 })
            .justifyContent(FlexAlign.Center)
          } else {
            Scroll() {
              Column() {
                ForEach(this.files, (file: FileReference, index: number) => {
                  Row() {
                    // File/directory icon
                    if (file.type === 'directory') {
                      Text('\u2750')
                        .fontSize(Theme.fs.md)
                        .fontColor(Theme.ACCENT)
                        .fontFamily(Theme.FONT_MONO)
                        .width(20)
                        .textAlign(TextAlign.Center)
                    } else {
                      Text('\u2637')
                        .fontSize(Theme.fs.md)
                        .fontColor(Theme.TEXT_MUTED)
                        .fontFamily(Theme.FONT_MONO)
                        .width(20)
                        .textAlign(TextAlign.Center)
                    }

                    // File path
                    Text(file.path)
                      .fontSize(Theme.fs.sm)
                      .fontColor(Theme.TEXT_PRIMARY)
                      .fontFamily(Theme.FONT_MONO)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)
                      .margin({ left: Theme.sp.md })

                    // Selected checkmark
                    if (file.selected) {
                      Text('\u2713')
                        .fontSize(Theme.fs.md)
                        .fontColor(Theme.SUCCESS)
                        .fontFamily(Theme.FONT_MONO)
                        .fontWeight(FontWeight.Bold)
                        .width(20)
                        .textAlign(TextAlign.Center)
                    }
                  }
                  .width('100%')
                  .padding({
                    left: Theme.sp.lg,
                    right: Theme.sp.lg,
                    top: Theme.sp.sm,
                    bottom: Theme.sp.sm
                  })
                  .borderRadius(Theme.rd.sm)
                  .onClick(() => {
                    this.onSelectFile(file)
                  })
                }, (file: FileReference, index: number) => file.path + '_' + index)
              }
              .width('100%')
            }
            .constraintSize({ maxHeight: 200 })
            .scrollBar(BarState.Auto)
            .width('100%')
          }
        }
        .constraintSize({ maxWidth: 300 })
        .width('100%')
        .backgroundColor(Theme.SIDEBAR)
        .borderRadius(Theme.rd.md)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .padding({ top: Theme.sp.xs, bottom: Theme.sp.xs })
        .position({ x: 0, y: 0 })
        .alignSelf(ItemAlign.Start)
      }
      .width('100%')
      .height('100%')
    }
  }
}
