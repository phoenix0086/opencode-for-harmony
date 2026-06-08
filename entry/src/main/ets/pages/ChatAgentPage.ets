import { Theme } from '../components/Theme'

/**
 * ChatAgentPage - 简化版
 * 核心 transcript 逻辑已迁移到 Index.ets + components/AgentTranscript.ets
 * 此文件保留作为兼容占位
 *
 * Bug fixes applied in Index.ets convertMessage():
 * - Tool blocks are now properly added to the display list
 * - updateToolCall matches by exact tool id (part.id), not by prefix
 * - part.id is used as stable tool identifier
 */
@Component
export struct ChatAgentPage {
  build() {
    Column() {
      Text('Agent transcript is rendered by AppShell')
        .fontSize(13)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.BG)
  }
}
