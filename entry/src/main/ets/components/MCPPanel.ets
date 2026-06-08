import { Theme } from './Theme'

/**
 * MCP Server Management Panel
 * MCP 服务器管理面板 — 显示服务器状态、工具列表及开关控制
 */

export class MCPTool {
  name: string = ''
  description: string = ''
  enabled: boolean = true
}

export class MCPServer {
  id: string = ''
  name: string = ''
  status: string = 'disconnected' // 'connected' | 'connecting' | 'disconnected' | 'error'
  tools: MCPTool[] = []
  errorMessage: string = ''
  command: string = ''
  args: string[] = []
}

@Component
export struct MCPPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop servers: MCPServer[] = []
  onToggleServer: (id: string, enabled: boolean) => void = (_id: string, _enabled: boolean) => {}
  onToggleTool: (serverId: string, toolName: string, enabled: boolean) => void =
    (_serverId: string, _toolName: string, _enabled: boolean) => {}
  onRefresh: () => void = () => {}
  @State expandedServers: string[] = []
  @State searchQuery: string = ''

  build() {
    Column() {
      // ── Header ──────────────────────────────────────────────
      Row() {
        Text('MCP SERVERS')
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

        // Refresh button
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

      // ── Search / Filter ─────────────────────────────────────
      Row() {
        Text('\u2315')
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ right: Theme.sp.sm })

        TextInput({ placeholder: 'filter servers...', text: this.searchQuery })
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
      .margin({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm })
      .backgroundColor(Theme.CODE_BG)
      .borderRadius(Theme.rd.md)
      .border({ width: 1, color: Theme.BORDER })

      // ── Server List ─────────────────────────────────────────
      if (this.getFilteredServers().length === 0) {
        Column() {
          Text(this.servers.length === 0 ? 'No MCP servers configured' : 'No servers match filter')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .textAlign(TextAlign.Center)

          Text(this.servers.length === 0
            ? 'Add MCP server configurations to get started.'
            : 'Try a different search term.')
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
      } else {
        List() {
          ForEach(this.getFilteredServers(), (server: MCPServer) => {
            ListItem() {
              Column() {
                // ── Server Row ────────────────────────────────
                Row() {
                  // Status indicator
                  Text(this.getStatusIcon(server.status))
                    .fontSize(Theme.fs.md)
                    .fontColor(this.getStatusColor(server.status))
                    .fontFamily(Theme.FONT_MONO)
                    .width(18)
                    .textAlign(TextAlign.Center)

                  // Server name
                  Text(server.name)
                    .fontSize(Theme.fs.sm)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .fontFamily(Theme.FONT_MONO)
                    .fontWeight(FontWeight.Medium)
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ left: Theme.sp.sm })

                  // Tool count badge
                  if (server.tools.length > 0) {
                    Row() {
                      Text(`${server.tools.length}`)
                        .fontSize(Theme.fs.xs)
                        .fontColor(Theme.TEXT_SECONDARY)
                        .fontFamily(Theme.FONT_MONO)
                      Text(server.tools.length === 1 ? 'tool' : 'tools')
                        .fontSize(Theme.fs.xs)
                        .fontColor(Theme.TEXT_MUTED)
                        .fontFamily(Theme.FONT_MONO)
                        .margin({ left: Theme.sp.xs })
                    }
                    .padding({
                      left: Theme.sp.md,
                      right: Theme.sp.md,
                      top: Theme.sp.xs,
                      bottom: Theme.sp.xs
                    })
                    .backgroundColor(Theme.CODE_BG)
                    .borderRadius(Theme.rd.sm)
                    .margin({ left: Theme.sp.sm })
                  }

                  // Server enable/disable toggle
                  Toggle({ type: ToggleType.Switch, isOn: server.status !== 'disconnected' })
                    .selectedColor(Theme.SUCCESS)
                    .switchPointColor(Theme.TEXT_PRIMARY)
                    .margin({ left: Theme.sp.sm })
                    .onChange((isOn: boolean) => {
                      this.onToggleServer(server.id, isOn)
                    })

                  // Expand/collapse chevron
                  Text(this.isExpanded(server.id) ? '\u25BE' : '\u25B8')
                    .fontSize(Theme.fs.md)
                    .fontColor(Theme.TEXT_MUTED)
                    .fontFamily(Theme.FONT_MONO)
                    .margin({ left: Theme.sp.sm })
                    .onClick(() => {
                      this.toggleExpanded(server.id)
                    })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)

                // ── Error message ─────────────────────────────
                if (server.status === 'error' && server.errorMessage.length > 0) {
                  Row() {
                    Text('\u26A0')
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.DANGER)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ right: Theme.sp.sm })

                    Text(server.errorMessage)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.DANGER)
                      .fontFamily(Theme.FONT_MONO)
                      .layoutWeight(1)
                      .maxLines(3)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .padding({
                    left: Theme.sp.lg,
                    right: Theme.sp.md,
                    top: Theme.sp.sm,
                    bottom: Theme.sp.sm
                  })
                  .margin({ top: Theme.sp.sm })
                  .backgroundColor(Theme.DANGER_DIM)
                  .borderRadius(Theme.rd.sm)
                  .border({ width: 1, color: Theme.DANGER })
                }

                // ── Command info ──────────────────────────────
                if (this.isExpanded(server.id) && server.command.length > 0) {
                  Row() {
                    Text('cmd')
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .width(30)

                    Text(server.command + (server.args.length > 0 ? ' ' + server.args.join(' ') : ''))
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_SECONDARY)
                      .fontFamily(Theme.FONT_MONO)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .padding({
                    left: Theme.sp.lg,
                    right: Theme.sp.md,
                    top: Theme.sp.sm,
                    bottom: Theme.sp.xs
                  })
                  .margin({ top: Theme.sp.sm })
                  .backgroundColor(Theme.CODE_BG)
                  .borderRadius(Theme.rd.sm)
                }

                // ── Expanded Tool List ────────────────────────
                if (this.isExpanded(server.id) && server.tools.length > 0) {
                  Column() {
                    ForEach(server.tools, (tool: MCPTool) => {
                      Row() {
                        // Tool name
                        Column() {
                          Text(tool.name)
                            .fontSize(Theme.fs.xs)
                            .fontColor(Theme.TEXT_PRIMARY)
                            .fontFamily(Theme.FONT_MONO)

                          if (tool.description.length > 0) {
                            Text(tool.description)
                              .fontSize(Theme.fs.xs)
                              .fontColor(Theme.TEXT_MUTED)
                              .fontFamily(Theme.FONT_MONO)
                              .maxLines(2)
                              .textOverflow({ overflow: TextOverflow.Ellipsis })
                              .margin({ top: Theme.sp.xs })
                          }
                        }
                        .layoutWeight(1)
                        .alignItems(HorizontalAlign.Start)

                        // Tool toggle
                        Toggle({ type: ToggleType.Switch, isOn: tool.enabled })
                          .selectedColor(Theme.ACCENT)
                          .switchPointColor(Theme.TEXT_PRIMARY)
                          .onChange((isOn: boolean) => {
                            this.onToggleTool(server.id, tool.name, isOn)
                          })
                      }
                      .width('100%')
                      .padding({
                        left: Theme.sp.md,
                        right: Theme.sp.md,
                        top: Theme.sp.sm,
                        bottom: Theme.sp.sm
                      })
                      .alignItems(VerticalAlign.Center)
                    }, (tool: MCPTool) => server.id + ':' + tool.name)
                  }
                  .width('100%')
                  .margin({ top: Theme.sp.sm })
                  .backgroundColor(Theme.PANEL)
                  .borderRadius(Theme.rd.md)
                  .border({ width: 1, color: Theme.BORDER })
                }
              }
              .width('100%')
              .padding({
                left: Theme.sp.lg,
                right: Theme.sp.lg,
                top: Theme.sp.md,
                bottom: Theme.sp.md
              })
            }
          }, (server: MCPServer) => server.id)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: Theme.BORDER, startMargin: Theme.sp.lg, endMargin: Theme.sp.lg })
        .scrollBar(BarState.Auto)
        .backgroundColor('transparent')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  // ── Helper Methods ────────────────────────────────────────────

  private getStatusColor(status: string): string {
    if (status === 'connected') return Theme.SUCCESS
    if (status === 'connecting') return Theme.WARNING
    if (status === 'error') return Theme.DANGER
    return Theme.TEXT_MUTED
  }

  private getStatusIcon(status: string): string {
    if (status === 'connected') return '\u25CF'     // ●
    if (status === 'connecting') return '\u25CC'    // ◌
    if (status === 'error') return '\u2715'         // ✕
    return '\u25CB'                                  // ○
  }

  private isExpanded(id: string): boolean {
    return this.expandedServers.indexOf(id) >= 0
  }

  private toggleExpanded(id: string): void {
    const idx: number = this.expandedServers.indexOf(id)
    if (idx >= 0) {
      const updated: string[] = this.expandedServers.filter((s: string) => s !== id)
      this.expandedServers = updated
    } else {
      const updated: string[] = [...this.expandedServers]
      updated.push(id)
      this.expandedServers = updated
    }
  }

  private getFilteredServers(): MCPServer[] {
    if (this.searchQuery.length === 0) {
      return this.servers
    }
    const query: string = this.searchQuery.toLowerCase()
    return this.servers.filter((s: MCPServer) => {
      if (s.name.toLowerCase().indexOf(query) >= 0) return true
      if (s.status.toLowerCase().indexOf(query) >= 0) return true
      if (s.command.toLowerCase().indexOf(query) >= 0) return true
      for (let i = 0; i < s.tools.length; i++) {
        if (s.tools[i].name.toLowerCase().indexOf(query) >= 0) return true
      }
      return false
    })
  }
}
