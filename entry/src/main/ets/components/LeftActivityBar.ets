import { Theme } from './Theme'

/**
 * 左侧活动栏
 * IDE 风格窄图标栏，使用文字符号而非 emoji
 */

class ActivityItem {
  id: string = ''
  label: string = ''
  symbol: string = ''
}

@Component
export struct LeftActivityBar {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop activeId: string = 'chat'
  @Prop connectionStatus: string = 'disconnected' // 'connected' | 'disconnected' | 'connecting'
  onActivityChange: (id: string) => void = () => {}
  onOpenDirectoryPicker: () => void = () => {}

  private items: ActivityItem[] = []

  aboutToAppear(): void {
    const chat = new ActivityItem()
    chat.id = 'chat'
    chat.label = 'Chat'
    chat.symbol = '>'

    const files = new ActivityItem()
    files.id = 'files'
    files.label = 'Files'
    files.symbol = '{}'

    const diff = new ActivityItem()
    diff.id = 'diff'
    diff.label = 'Diff'
    diff.symbol = '~'

    const provider = new ActivityItem()
    provider.id = 'provider'
    provider.label = 'Provider'
    provider.symbol = 'P'

    const runtime = new ActivityItem()
    runtime.id = 'runtime'
    runtime.label = 'Runtime'
    runtime.symbol = 'R'

    const server = new ActivityItem()
    server.id = 'server'
    server.label = 'Runtime+'
    server.symbol = 'S'

    const models = new ActivityItem()
    models.id = 'models'
    models.label = 'Models'
    models.symbol = 'M'

    const settings = new ActivityItem()
    settings.id = 'settings'
    settings.label = 'Settings'
    settings.symbol = '*'

    // Sprint 2-A.5 / A.6 / A.7
    const lsp = new ActivityItem()
    lsp.id = 'lsp'
    lsp.label = 'LSP'
    lsp.symbol = 'L'

    const mcp = new ActivityItem()
    mcp.id = 'mcp'
    mcp.label = 'MCP'
    mcp.symbol = 'M'

    const formatters = new ActivityItem()
    formatters.id = 'formatters'
    formatters.label = 'Format'
    formatters.symbol = 'F'

    // Sprint 2-A.3 / A.1: file history + terminal
    const history = new ActivityItem()
    history.id = 'history'
    history.label = 'History'
    history.symbol = 'H'

    const terminal = new ActivityItem()
    terminal.id = 'terminal'
    terminal.label = 'Term'
    terminal.symbol = '$_'

    // Sprint 3-A.9: plugins
    const plugins = new ActivityItem()
    plugins.id = 'plugins'
    plugins.label = 'Plugin'
    plugins.symbol = 'X'

    const arr: ActivityItem[] = []
    arr.push(chat)
    arr.push(files)
    arr.push(diff)
    arr.push(history)
    arr.push(terminal)
    arr.push(provider)
    arr.push(runtime)
    arr.push(server)
    arr.push(models)
    arr.push(lsp)
    arr.push(mcp)
    arr.push(formatters)
    arr.push(plugins)
    arr.push(settings)
    this.items = arr
  }

  build() {
    Column() {
      // Logo mark
      Column() {
        Text('OC')
          .fontSize(Theme.fs.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
      }
      .width(Theme.ACTIVITY_BAR_W)
      .height(40)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: Theme.sp.lg })

      // Divider
      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: 8, right: 8, bottom: Theme.sp.md })

      // Activity items
      ForEach(this.items, (item: ActivityItem) => {
        Column() {
          Text(item.symbol)
            .fontSize(item.symbol === '{}' ? Theme.fs.sm : Theme.fs.lg)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.activeId === item.id ? Theme.ACTIVITY_BAR_ACTIVE : Theme.ACTIVITY_BAR_INACTIVE)
            .fontFamily(Theme.FONT_MONO)

          Text(item.label)
            .fontSize(9)
            .fontColor(this.activeId === item.id ? Theme.TEXT_SECONDARY : Theme.TEXT_MUTED)
            .margin({ top: 2 })
        }
        .width(Theme.ACTIVITY_BAR_W)
        .padding({ top: Theme.sp.md, bottom: Theme.sp.md })
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.activeId === item.id ? Theme.ACTIVE_BG : 'transparent')
        .borderRadius(Theme.rd.md)
        .onClick(() => {
          this.onActivityChange(item.id)
        })
      }, (item: ActivityItem) => item.id)

      Blank()

      // Directory picker button
      Column() {
        Text('/')
          .fontSize(Theme.fs.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ACTIVITY_BAR_INACTIVE)
          .fontFamily(Theme.FONT_MONO)

        Text('dir')
          .fontSize(9)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 2 })
      }
      .width(Theme.ACTIVITY_BAR_W)
      .padding({ top: Theme.sp.md, bottom: Theme.sp.md })
      .justifyContent(FlexAlign.Center)
      .borderRadius(Theme.rd.md)
      .onClick(() => {
        this.onOpenDirectoryPicker()
      })

      // Connection indicator at bottom
      Column() {
        Circle({ width: 6, height: 6 })
          .fill(this.getConnectionColor())
        Text(this.getConnectionLabel())
          .fontSize(8)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ top: 2 })
      }
      .margin({ bottom: Theme.sp.lg })
    }
    .width(Theme.ACTIVITY_BAR_W)
    .height('100%')
    .backgroundColor(Theme.ACTIVITY_BAR_BG)
    .alignItems(HorizontalAlign.Center)
    .borderWidth({ right: 1 })
    .borderColor(Theme.BORDER)
  }

  private getConnectionColor(): string {
    if (this.connectionStatus === 'connected') return Theme.SUCCESS
    if (this.connectionStatus === 'connecting') return Theme.WARNING
    return Theme.DANGER
  }

  private getConnectionLabel(): string {
    if (this.connectionStatus === 'connected') return 'online'
    if (this.connectionStatus === 'connecting') return '...'
    return 'offline'
  }
}
