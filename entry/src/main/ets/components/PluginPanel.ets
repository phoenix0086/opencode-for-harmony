import { Theme } from './Theme'
import { PluginInfo } from '../services/V2Type'

/**
 * PluginPanel — 插件管理 (Sprint 3-A.9)
 *
 * - 列出已安装/可用的 plugin
 * - enable / disable 单个 plugin
 * - 标出有错误的 plugin
 *
 * v2-only。v1 显示 "unsupported" 占位。
 */
@Component
export struct PluginPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop plugins: PluginInfo[] = []
  @Prop isLoading: boolean = false
  @Prop unsupported: boolean = false
  @Prop errorMessage: string = ''
  onRefresh: () => void = () => {}
  onToggle: (pluginID: string, enabled: boolean) => void = () => {}

  build() {
    Column() {
      // ═══════ Header ═══════
      Row() {
        Text('plugins')
          .fontSize(Theme.fs.md)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)

        const enabled = this.countEnabled()
        if (this.plugins.length > 0) {
          Text(`${enabled}/${this.plugins.length} enabled`)
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
          Text('plugin manager not supported')
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
      } else if (this.plugins.length === 0) {
        Column() {
          Text('--')
            .fontSize(Theme.fs.xxl)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('no plugins installed')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else {
        List() {
          ForEach(this.plugins, (p: PluginInfo) => {
            ListItem() {
              this.PluginRow(p)
            }
          }, (p: PluginInfo) => p.id)
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

  @Builder
  PluginRow(p: PluginInfo) {
    Column() {
      Row() {
        Text(p.name)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (p.version.length > 0) {
          Text(`v${p.version}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
        }

        Toggle({ type: ToggleType.Switch, isOn: p.enabled })
          .selectedColor(Theme.ACCENT)
          .switchPointColor(Theme.ACCENT_TEXT)
          .width(44)
          .height(22)
          .margin({ left: Theme.sp.md })
          .onChange((isOn: boolean): void => {
            this.onToggle(p.id, isOn)
          })
      }
      .width('100%')

      if (p.description.length > 0) {
        Text(p.description)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: Theme.sp.xs })
          .width('100%')
      }

      // Meta line
      Row() {
        if (p.author.length > 0) {
          Text(`by ${p.author}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        if (p.scope.length > 0) {
          Text(` · ${p.scope}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        if (p.path.length > 0) {
          Text(` · ${p.path}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
      }
      .width('100%')
      .margin({ top: Theme.sp.xs })

      // Error line
      if (p.error.length > 0) {
        Text(`! ${p.error}`)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: Theme.sp.xs })
          .width('100%')
      }
    }
    .width('100%')
    .padding(Theme.sp.md)
    .backgroundColor(Theme.PANEL_BG)
    .borderBottomWidth(1)
    .borderColor(Theme.BORDER)
  }

  private countEnabled(): number {
    let n = 0
    for (const p of this.plugins) {
      if (p.enabled) n++
    }
    return n
  }
}
