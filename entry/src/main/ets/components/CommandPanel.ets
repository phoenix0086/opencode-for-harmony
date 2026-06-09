import { Theme } from './Theme'
import { CommandInfo } from '../models/Event'

/**
 * CommandPanel - v2 命令列表面板
 * 显示 OpenCode Server 注册的 slash 命令
 */
@Component
export struct CommandPanel {
  @Prop commands: CommandInfo[] = []
  @Prop isLoading: boolean = false
  @Prop unsupported: boolean = false
  @Prop errorMessage: string = ''
  onRefresh: () => void = () => {}

  build() {
    Column() {
      // Header
      Row() {
        Text('commands')
          .fontSize(Theme.fs.md)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)

        Blank()

        if (!this.unsupported) {
          Text('refresh')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
            .onClick(() => { this.onRefresh() })
        }
      }
      .width('100%')
      .padding({ bottom: Theme.sp.md })

      if (this.unsupported) {
        this.UnsupportedBanner()
      } else if (this.errorMessage.length > 0) {
        this.ErrorBanner()
      } else if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Theme.ACCENT)
          Text('loading...')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: Theme.sp.sm })
        }
        .width('100%')
        .padding({ top: Theme.sp.xl })
        .alignItems(HorizontalAlign.Center)
      } else if (this.commands.length === 0) {
        Column() {
          Text('/')
            .fontSize(24)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('no commands registered')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: Theme.sp.sm })
        }
        .width('100%')
        .padding({ top: Theme.sp.xl })
        .alignItems(HorizontalAlign.Center)
      } else {
        // Command list
        List() {
          ForEach(this.commands, (cmd: CommandInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Text('/' + cmd.name)
                    .fontSize(Theme.fs.sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ACCENT)
                    .fontFamily(Theme.FONT_MONO)

                  if (cmd.agent.length > 0) {
                    Text(cmd.agent)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .fontFamily(Theme.FONT_MONO)
                      .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 2, bottom: 2 })
                      .backgroundColor(Theme.SURFACE)
                      .borderRadius(Theme.rd.sm)
                      .margin({ left: Theme.sp.sm })
                  }

                  if (!cmd.enabled) {
                    Text('disabled')
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.DANGER)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ left: Theme.sp.sm })
                  }

                  Blank()
                }
                .width('100%')

                if (cmd.description.length > 0) {
                  Text(cmd.description)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.TEXT_SECONDARY)
                    .margin({ top: Theme.sp.xs })
                }

                if (cmd.args.length > 0) {
                  Text('args: ' + cmd.args)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.TEXT_MUTED)
                    .fontFamily(Theme.FONT_MONO)
                    .margin({ top: Theme.sp.xs })
                }
              }
              .width('100%')
              .padding({ top: Theme.sp.md, bottom: Theme.sp.md, left: Theme.sp.lg, right: Theme.sp.lg })
              .backgroundColor(Theme.SURFACE)
              .borderRadius(Theme.rd.md)
              .margin({ bottom: Theme.sp.sm })
            }
          }, (cmd: CommandInfo) => cmd.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(Theme.sp.lg)
    .backgroundColor(Theme.BG)
  }

  @Builder
  UnsupportedBanner() {
    Column() {
      Text('/')
        .fontSize(24)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
      Text('commands not supported')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.WARNING)
        .margin({ top: Theme.sp.sm })
      Text('requires OpenCode Server v2')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .margin({ top: Theme.sp.xs })
    }
    .width('100%')
    .padding({ top: Theme.sp.xl })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ErrorBanner() {
    Column() {
      Text('error: ' + this.errorMessage)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .fontFamily(Theme.FONT_MONO)
    }
    .width('100%')
    .padding({ top: Theme.sp.xl })
    .alignItems(HorizontalAlign.Center)
  }
}
