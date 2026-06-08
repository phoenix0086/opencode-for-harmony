import { Theme } from './Theme'

// ════════════════════════════════════════════════════════════
// StatusPopover — dropdown showing detailed server/connection info
// ════════════════════════════════════════════════════════════

@Component
export struct StatusPopover {
  @Prop visible: boolean = false
  @Prop isConnected: boolean = false
  @Prop serverUrl: string = ''
  @Prop serverVersion: string = ''
  @Prop projectName: string = ''
  @Prop branchName: string = ''
  @Prop sessionCount: number = 0
  @Prop tokensUsed: number = 0
  @Prop tokensMax: number = 128000
  @Prop agentMode: string = 'build'
  @Prop uptime: string = ''

  onDismiss: () => void = () => {}
  onReconnect: () => void = () => {}

  // ── Helper methods ──────────────────────────────────────────

  private getTokenPercentage(): number {
    if (this.tokensMax <= 0) {
      return 0
    }
    let pct: number = (this.tokensUsed / this.tokensMax) * 100
    if (pct > 100) {
      return 100
    }
    if (pct < 0) {
      return 0
    }
    return Math.round(pct)
  }

  private formatTokens(n: number): string {
    if (n >= 1000) {
      let k: number = Math.round(n / 1000)
      return k.toString() + 'k'
    }
    return n.toString()
  }

  private getTokenBarColor(): string {
    let pct: number = this.getTokenPercentage()
    if (pct >= 90) {
      return Theme.DANGER
    }
    if (pct >= 70) {
      return Theme.WARNING
    }
    return Theme.SUCCESS
  }

  // ── Build ───────────────────────────────────────────────────

  build() {
    if (this.visible) {
      Stack() {
        // Transparent backdrop — tap to dismiss
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.onDismiss()
          })

        // Floating card — positioned near top-right
        Column() {
          // ── Header ──────────────────────────────────────
          Text('SERVER STATUS')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .letterSpacing(1.2)
            .width('100%')

          // ── Connection section ──────────────────────────
          Column() {
            // Status row
            Row() {
              Circle({ width: 7, height: 7 })
                .fill(this.isConnected ? Theme.SUCCESS : Theme.DANGER)
                .margin({ right: Theme.sp.md })

              Text(this.isConnected ? 'Connected' : 'Disconnected')
                .fontSize(Theme.fs.sm)
                .fontColor(this.isConnected ? Theme.SUCCESS : Theme.DANGER)
                .fontFamily(Theme.FONT_MONO)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.md })

            // Server URL
            Row() {
              Text('url')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.serverUrl.length > 0 ? this.serverUrl : '--')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.sm })

            // Server version
            Row() {
              Text('version')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.serverVersion.length > 0 ? this.serverVersion : '--')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.sm })

            // Uptime (only when connected)
            if (this.isConnected && this.uptime.length > 0) {
              Row() {
                Text('uptime')
                  .fontSize(Theme.fs.xs)
                  .fontColor(Theme.TEXT_MUTED)
                  .fontFamily(Theme.FONT_MONO)
                  .width(60)

                Text(this.uptime)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.TEXT_PRIMARY)
                  .fontFamily(Theme.FONT_MONO)
              }
              .width('100%')
            }
          }
          .width('100%')
          .margin({ top: Theme.sp.lg })

          // ── Divider ─────────────────────────────────────
          Divider()
            .color(Theme.BORDER)
            .strokeWidth(1)
            .width('100%')
            .margin({ top: Theme.sp.lg, bottom: Theme.sp.lg })

          // ── Project section ─────────────────────────────
          Column() {
            Text('PROJECT')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(1.2)
              .width('100%')
              .margin({ bottom: Theme.sp.md })

            // Project name
            Row() {
              Text('name')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.projectName.length > 0 ? this.projectName : '--')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.sm })

            // Branch
            Row() {
              Text('branch')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.branchName.length > 0 ? this.branchName : '--')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.sm })

            // Active sessions
            Row() {
              Text('sessions')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.sessionCount.toString())
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
            }
            .width('100%')
          }
          .width('100%')

          // ── Divider ─────────────────────────────────────
          Divider()
            .color(Theme.BORDER)
            .strokeWidth(1)
            .width('100%')
            .margin({ top: Theme.sp.lg, bottom: Theme.sp.lg })

          // ── Usage section ───────────────────────────────
          Column() {
            Text('USAGE')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(1.2)
              .width('100%')
              .margin({ bottom: Theme.sp.md })

            // Token usage label
            Row() {
              Text('tokens')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.formatTokens(this.tokensUsed) + ' / ' + this.formatTokens(this.tokensMax) + ' tokens')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
                .fontFamily(Theme.FONT_MONO)
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: Theme.sp.md })

            // Progress bar — track
            Row() {
              // Fill
              Row()
                .height(4)
                .width(this.getTokenPercentage() + '%')
                .backgroundColor(this.getTokenBarColor())
                .borderRadius(2)
            }
            .width('100%')
            .height(4)
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(2)
            .clip(true)
            .margin({ bottom: Theme.sp.lg })

            // Agent mode
            Row() {
              Text('mode')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .width(60)

              Text(this.agentMode)
                .fontSize(Theme.fs.sm)
                .fontColor(this.agentMode === 'build' ? Theme.ACCENT : Theme.WARNING)
                .fontFamily(Theme.FONT_MONO)
                .backgroundColor(this.agentMode === 'build' ? Theme.ACCENT_DIM : Theme.WARNING_DIM)
                .borderRadius(Theme.rd.sm)
                .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 2, bottom: 2 })
            }
            .width('100%')
          }
          .width('100%')

          // ── Footer buttons ──────────────────────────────
          Row() {
            if (!this.isConnected) {
              Text('reconnect')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.ACCENT)
                .fontFamily(Theme.FONT_MONO)
                .padding({
                  left: Theme.sp.lg,
                  right: Theme.sp.lg,
                  top: Theme.sp.md,
                  bottom: Theme.sp.md
                })
                .backgroundColor(Theme.ACCENT_DIM)
                .borderRadius(Theme.rd.md)
                .onClick(() => {
                  this.onReconnect()
                })

              Blank().width(Theme.sp.md)
            }

            Text('dismiss')
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .padding({
                left: Theme.sp.lg,
                right: Theme.sp.lg,
                top: Theme.sp.md,
                bottom: Theme.sp.md
              })
              .backgroundColor(Theme.ACTIVE_BG)
              .borderRadius(Theme.rd.md)
              .onClick(() => {
                this.onDismiss()
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .margin({ top: Theme.sp.xl })
        }
        .width(300)
        .padding({
          left: Theme.sp.xl,
          right: Theme.sp.xl,
          top: Theme.sp.xl,
          bottom: Theme.sp.xl
        })
        .backgroundColor(Theme.PANEL)
        .borderRadius(Theme.rd.lg)
        .border({ width: 1, color: Theme.BORDER, style: BorderStyle.Solid })
        .position({ top: Theme.STATUS_BAR_H + Theme.sp.md, right: Theme.sp.xl })
        .shadow({
          radius: 16,
          color: '#00000060',
          offsetX: 0,
          offsetY: 4
        })
      }
      .width('100%')
      .height('100%')
    }
  }
}
