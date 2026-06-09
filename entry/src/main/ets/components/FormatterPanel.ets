import { Theme } from './Theme'

/**
 * Formatter Management Panel (Sprint 2-A.7)
 *
 * Display installed formatters from /formatter endpoint.
 * v1 server returns: [{ name, enabled?, command? }]
 */

@Observed
export class FormatterEntry {
  name: string = ''
  command: string = ''
  enabled: boolean = true
  extensions: string[] = []
}

@Component
export struct FormatterPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop formatters: FormatterEntry[] = []
  onRefresh: () => void = () => {}
  onToggle: (name: string, enabled: boolean) => void = (_n: string, _e: boolean) => {}

  build() {
    Column() {
      Row() {
        Text('FORMATTERS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        if (this.formatters.length > 0) {
          Text(`${this.formatters.length}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }

        Text('\u21BB')
          .fontSize(Theme.fs.lg)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.md })
          .onClick(() => {
            this.onRefresh()
          })
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.lg, bottom: Theme.sp.md })

      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      if (this.formatters.length === 0) {
        Column() {
          Text('No formatters registered')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('OpenCode 会自动发现 prettier / black / gofmt 等格式化工具。')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
            .textAlign(TextAlign.Center)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.formatters, (f: FormatterEntry) => {
            ListItem() {
              Row() {
                Column() {
                  Text(f.name)
                    .fontSize(Theme.fs.sm)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .fontFamily(Theme.FONT_MONO)
                    .fontWeight(FontWeight.Medium)
                  if (f.command.length > 0) {
                    Text(f.command)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ top: 2 })
                  }
                  if (f.extensions.length > 0) {
                    Row() {
                      ForEach(f.extensions.slice(0, 5), (ext: string) => {
                        Text(ext)
                          .fontSize(Theme.fs.xs)
                          .fontColor(Theme.ACCENT)
                          .fontFamily(Theme.FONT_MONO)
                          .backgroundColor(Theme.ACCENT_DIM)
                          .borderRadius(Theme.rd.sm)
                          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                          .margin({ right: 4 })
                      })
                    }
                    .margin({ top: 4 })
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: f.enabled })
                  .selectedColor(Theme.SUCCESS)
                  .switchPointColor(Theme.TEXT_PRIMARY)
                  .onChange((isOn: boolean) => {
                    this.onToggle(f.name, isOn)
                  })
              }
              .width('100%')
              .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
            }
          }, (f: FormatterEntry) => f.name)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: Theme.BORDER, startMargin: Theme.sp.lg, endMargin: Theme.sp.lg })
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
