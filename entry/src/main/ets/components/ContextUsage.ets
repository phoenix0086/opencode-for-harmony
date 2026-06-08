import { Theme } from './Theme'

/**
 * Context usage indicator showing token consumption
 * Displays compact label like "12k/128k" with color coding by usage ratio
 */
@Component
export struct ContextUsage {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop tokensUsed: number = 0
  @Prop tokensMax: number = 128000

  build() {
    Row() {
      Text(this.formatTokens())
        .fontSize(Theme.fs.xs)
        .fontColor(this.usageColor())
        .fontFamily(Theme.FONT_MONO)
    }
    .padding({ left: Theme.sp.sm, right: Theme.sp.sm })
  }

  private formatTokens(): string {
    let usedK: number = Math.round(this.tokensUsed / 1000)
    let maxK: number = Math.round(this.tokensMax / 1000)
    return usedK.toString() + 'k/' + maxK.toString() + 'k'
  }

  private usageColor(): string {
    let ratio: number = this.tokensUsed / this.tokensMax
    if (ratio > 0.9) {
      return Theme.DANGER
    }
    if (ratio > 0.7) {
      return Theme.WARNING
    }
    return Theme.TEXT_MUTED
  }
}
