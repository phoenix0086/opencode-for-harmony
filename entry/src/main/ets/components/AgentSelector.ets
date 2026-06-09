import { Theme } from './Theme'
import { AgentDetail } from '../services/V2Type'

/**
 * AgentSelector — Agent 模式选择器 (Sprint 3-B.14/B.15)
 *
 * 显示可用的 agents(build/plan/explore/etc.)，点击切换。
 * 通过 V2Client.listAgentsV2() 拉详情，失败时回退到 v1 /agent names-only 列表。
 */
@Component
export struct AgentSelector {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop agents: AgentDetail[] = []
  @Prop currentAgent: string = 'build'
  @Prop unsupported: boolean = false
  onSelect: (agentName: string) => void = () => {}

  build() {
    Column() {
      Row() {
        Text('agent:')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ right: Theme.sp.sm })

        if (this.unsupported) {
          Text(this.currentAgent)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)
        } else {
          // Quick toggles for common agents
          ForEach(this.getQuickAgents(), (name: string) => {
            this.AgentChip(name)
          }, (name: string) => name)
        }
      }
      .width('100%')
      .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: Theme.sp.xs, bottom: Theme.sp.xs })
      .backgroundColor(Theme.PANEL_BG)
    }
  }

  private getQuickAgents(): string[] {
    const names: string[] = []
    for (const a of this.agents) {
      if (a.builtIn) {
        names.push(a.name)
      }
    }
    // If empty, fall back to common names
    if (names.length === 0) {
      return ['build', 'plan']
    }
    return names
  }

  @Builder
  AgentChip(name: string) {
    Text(name)
      .fontSize(Theme.fs.xs)
      .fontColor(this.currentAgent === name ? Theme.ACCENT_TEXT : Theme.TEXT_PRIMARY)
      .fontFamily(Theme.FONT_MONO)
      .fontWeight(this.currentAgent === name ? FontWeight.Bold : FontWeight.Normal)
      .backgroundColor(this.currentAgent === name ? Theme.ACCENT : Theme.BTN_BG)
      .borderRadius(Theme.rd.sm)
      .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 4, bottom: 4 })
      .margin({ right: Theme.sp.xs })
      .onClick((): void => {
        if (this.currentAgent !== name) {
          this.onSelect(name)
        }
      })
  }
}
