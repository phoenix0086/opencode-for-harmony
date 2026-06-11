import { Theme } from './Theme'
import { ContextUsage } from './ContextUsage'
import { AgentSelector } from './AgentSelector'
import { AgentDetail } from '../services/V2Type'

/**
 * Bottom Composer input bar with M14 features
 * - Agent mode toggle (Build/Plan) via AgentSelector
 * - Context usage indicator
 * - Clickable model label
 * - TextArea with send/abort controls
 */
@Component
export struct ComposerBar {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  // ── Existing props ──
  @Prop inputText: string = ''
  @Prop isSending: boolean = false
  @Prop modelLabel: string = ''
  @Prop sessionTitle: string = ''
  onTextChange: (text: string) => void = () => {}
  onSend: () => void = () => {}
  onAbort: () => void = () => {}

  // ── M14: Agent Mode Toggle ──
  @Prop agentMode: string = 'build'
  onModeChange: (mode: string) => void = () => {}

  // ── M14: Model Label Click ──
  onModelClick: () => void = () => {}

  // ── M14: Context Usage ──
  @Prop tokensUsed: number = 0
  @Prop tokensMax: number = 128000

  // ── Sprint 3-B.14/15: Agent list (v2 detail) ──
  @Prop agents: AgentDetail[] = []
  @Prop agentUnsupported: boolean = false

  build() {
    Column() {
      // Top border
      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)

      // Toolbar row
      Row() {
        // Mode toggle
        Row() {
          Text('build')
            .fontSize(12)
            .fontColor(this.agentMode === 'build' ? Theme.TEXT_PRIMARY : Theme.TEXT_MUTED)
            .fontWeight(this.agentMode === 'build' ? FontWeight.Bold : FontWeight.Normal)
            .fontFamily(Theme.FONT_MONO)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor(this.agentMode === 'build' ? Theme.ACTIVE_BG : 'transparent')
            .borderRadius(Theme.rd.md)
            .onClick(() => {
              this.onModeChange('build')
            })

          Text('plan')
            .fontSize(12)
            .fontColor(this.agentMode === 'plan' ? Theme.TEXT_PRIMARY : Theme.TEXT_MUTED)
            .fontWeight(this.agentMode === 'plan' ? FontWeight.Bold : FontWeight.Normal)
            .fontFamily(Theme.FONT_MONO)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .backgroundColor(this.agentMode === 'plan' ? Theme.ACTIVE_BG : 'transparent')
            .borderRadius(Theme.rd.md)
            .onClick(() => {
              this.onModeChange('plan')
            })
        }
        .backgroundColor(Theme.PANEL)
        .borderRadius(Theme.rd.md)
        .padding(2)

        Blank()

        // Context usage
        if (this.tokensUsed > 0) {
          Text(`Context: ${this.tokensUsed.toLocaleString()} / ${this.tokensMax.toLocaleString()} tokens`)
            .fontSize(11)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })

      // Composer area
      Row() {
        // Input field
        TextArea({ text: this.inputText, placeholder: 'How can I help you today?' })
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Theme.TEXT_PRIMARY)
          .placeholderColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(8)
          .borderWidth(1)
          .borderColor(Theme.BORDER_LIGHT)
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .height(52)
          .onChange((v: string) => {
            this.onTextChange(v)
          })

        // Send / Abort button
        Column() {
          if (this.isSending) {
            Column() {
              Text('✕')
                .fontSize(16)
                .fontColor(Theme.DANGER)
                .fontWeight(FontWeight.Bold)
            }
            .width(40)
            .height(40)
            .backgroundColor(Theme.DANGER_DIM)
            .borderRadius(8)
            .borderWidth(1)
            .borderColor(Theme.DANGER)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.onAbort()
            })
          } else {
            Column() {
              Text('↑')
                .fontSize(18)
                .fontColor(Theme.TEXT_INVERSE)
                .fontWeight(FontWeight.Bold)
            }
            .width(40)
            .height(40)
            .backgroundColor(this.inputText.trim().length > 0 ? Theme.ACCENT : Theme.ACTIVE_BG)
            .borderRadius(8)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              if (this.inputText.trim().length > 0) {
                this.onSend()
              }
            })
          }
        }
        .width(48)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('100%')
    .backgroundColor(Theme.COMPOSER)
  }
}
