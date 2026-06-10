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

      // Composer area
      Row() {
        // Model indicator (clickable)
        Column() {
          Text(this.modelLabel.length > 0 ? this.modelLabel : 'model')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .decoration({
              type: TextDecorationType.Underline,
              color: Theme.ACCENT_DIM
            })
            .onClick(() => {
              this.onModelClick()
            })
        }
        .width(60)
        .justifyContent(FlexAlign.Center)

        // Input field
        TextArea({ text: this.inputText, placeholder: 'Send a message to the agent...' })
          .layoutWeight(1)
          .fontSize(Theme.fs.md)
          .fontColor(Theme.TEXT_PRIMARY)
          .placeholderColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.INPUT_BG)
          .borderRadius(Theme.rd.md)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
          .height(Theme.COMPOSER_MIN_H)
          .onChange((v: string) => {
            this.onTextChange(v)
          })

        // Send / Abort button
        Column() {
          if (this.isSending) {
            Text('[x]')
              .fontSize(Theme.fs.lg)
              .fontColor(Theme.DANGER)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .onClick(() => {
                this.onAbort()
              })
          } else {
            Text('[>]')
              .fontSize(Theme.fs.lg)
              .fontColor(this.inputText.trim().length > 0 ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
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
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.sm })

      // Bottom info bar
      // Layout: [agent selector] [session title] [context usage] --- [shift+enter hint]
      Row() {
        // ── Agent selector (Sprint 3-B.14/15) ──
        // 修复 W3: 条件渲染逻辑说明
        // - agents.length > 0 → v2 server 有可用的 agent 列表,渲染 AgentSelector
        // - agentUnsupported = true → v2 探测失败 (404/405),仍渲染 AgentSelector
        //   以显示 "v2 agents unavailable" 占位,让用户知道是这个能力不支持
        //   (vs. 没接好 props 时的静默 fallback)
        // - 都不满足 → parent 没传 v2 props,显示 legacy build/plan 内联切换,
        //   保持向后兼容 (M14 之前的老调用方)
        if (this.agents.length > 0 || this.agentUnsupported) {
          AgentSelector({
            agents: this.agents,
            currentAgent: this.agentMode,
            unsupported: this.agentUnsupported,
            onSelect: (name: string): void => { this.onModeChange(name) }
          })
        } else {
          // Legacy M14 inline toggle (only rendered when parent didn't pass
          // v2 agents — keeps backward compat for Index.ets callers that
          // haven't yet wired the agents prop)
          Row() {
            Text('build')
              .fontSize(Theme.fs.xs)
              .fontColor(this.agentMode === 'build' ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontWeight(this.agentMode === 'build' ? FontWeight.Bold : FontWeight.Normal)
              .fontFamily(Theme.FONT_MONO)
              .onClick(() => {
                this.onModeChange('build')
              })

            Text('/')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ left: Theme.sp.xs, right: Theme.sp.xs })

            Text('plan')
              .fontSize(Theme.fs.xs)
              .fontColor(this.agentMode === 'plan' ? Theme.ACCENT : Theme.TEXT_MUTED)
              .fontWeight(this.agentMode === 'plan' ? FontWeight.Bold : FontWeight.Normal)
              .fontFamily(Theme.FONT_MONO)
              .onClick(() => {
                this.onModeChange('plan')
              })
          }
        }

        // ── Session title ──
        if (this.sessionTitle.length > 0) {
          Text(this.sessionTitle)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .maxLines(1)
            .constraintSize({ maxWidth: 200 })
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ left: Theme.sp.md })
        }

        // ── Plan mode description (shown when in plan mode) ──
        if (this.agentMode === 'plan') {
          Text('Plan mode restricts edit/bash permissions to ask')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.WARNING)
            .fontFamily(Theme.FONT_MONO)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 260 })
            .margin({ left: Theme.sp.md })
        }

        // ── Context usage (between left section and shortcut hint) ──
        if (this.tokensUsed > 0) {
          ContextUsage({
            tokensUsed: this.tokensUsed,
            tokensMax: this.tokensMax
          })
            .margin({ left: Theme.sp.md })
        }

        Blank()

        Text('Shift+Enter to send')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')
      .padding({ left: Theme.sp.xl, right: Theme.sp.xl, bottom: Theme.sp.sm })
    }
    .width('100%')
    .backgroundColor(Theme.COMPOSER)
  }
}
