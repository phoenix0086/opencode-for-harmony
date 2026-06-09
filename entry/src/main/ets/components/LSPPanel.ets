import { Theme } from './Theme'

/**
 * LSP Server Management Panel (Sprint 2-A.5)
 *
 * Display LSP server status pulled from /lsp endpoint. v1 server returns
 * a list of { name, root, status, error? } objects.
 */

@Observed
export class LspServer {
  id: string = ''
  name: string = ''
  root: string = ''
  status: string = 'disconnected' // 'connected' | 'connecting' | 'disconnected' | 'error'
  errorMessage: string = ''
}

@Component
export struct LSPPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop servers: LspServer[] = []
  onRefresh: () => void = () => {}

  build() {
    Column() {
      Row() {
        Text('LSP SERVERS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        if (this.servers.length > 0) {
          Text(`${this.servers.length}`)
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

      if (this.servers.length === 0) {
        Column() {
          Text('No LSP servers running')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('LSP servers 会在 opencode 启动时自动加载对应项目语言的定义。')
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
          ForEach(this.servers, (server: LspServer) => {
            ListItem() {
              Row() {
                Text(this.getStatusIcon(server.status))
                  .fontSize(Theme.fs.md)
                  .fontColor(this.getStatusColor(server.status))
                  .fontFamily(Theme.FONT_MONO)
                  .width(18)
                  .textAlign(TextAlign.Center)

                Column() {
                  Text(server.name)
                    .fontSize(Theme.fs.sm)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .fontFamily(Theme.FONT_MONO)
                    .fontWeight(FontWeight.Medium)
                  if (server.root.length > 0) {
                    Text(server.root)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ top: 2 })
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  if (server.status === 'error' && server.errorMessage.length > 0) {
                    Text(server.errorMessage)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.DANGER)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ top: 2 })
                      .maxLines(3)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                }
                .layoutWeight(1)
                .margin({ left: Theme.sp.sm })
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
            }
          }, (server: LspServer) => server.id)
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

  private getStatusColor(status: string): string {
    if (status === 'connected' || status === 'running') return Theme.SUCCESS
    if (status === 'starting' || status === 'connecting') return Theme.WARNING
    if (status === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  private getStatusIcon(status: string): string {
    if (status === 'connected' || status === 'running') return '\u25CF'
    if (status === 'starting' || status === 'connecting') return '\u25CC'
    if (status === 'error') return '\u2715'
    return '\u25CB'
  }
}
