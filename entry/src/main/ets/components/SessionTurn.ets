import { Theme } from './Theme'
import { MarkdownRenderer } from './MarkdownRenderer'
import { ThinkingHeading } from './ThinkingHeading'
import { BasicToolCard } from './BasicToolCard'
import {
  BashToolCard,
  EditToolCard,
  WriteToolCard,
  ReadToolCard,
  GrepToolCard,
  GlobToolCard,
  WebFetchToolCard
} from './ToolCards'

/**
 * Turn data — groups a user message with subsequent assistant/tool responses.
 * Matches OpenCode Desktop's session-turn concept.
 */
export class TurnData {
  id: string = ''
  userContent: string = ''
  assistantBlocks: TranscriptBlock[] = []
  streamingState: string = '' // '' | 'thinking' | 'acting' | 'responding'
  activeToolName: string = ''
}

/**
 * Re-export TranscriptBlock for AgentTranscript convenience.
 */
export class TranscriptBlock {
  id: string = ''
  type: string = '' // 'user' | 'assistant' | 'tool' | 'permission' | 'system'
  content: string = ''
  role: string = ''
  // Tool-specific
  toolName: string = ''
  toolId: string = ''
  toolStatus: string = '' // 'running' | 'success' | 'error' | 'cancelled'
  toolInput: string = ''
  toolOutput: string = ''
  toolStep: number = 0
  // Permission-specific
  permType: string = ''
  permTitle: string = ''
  permDescription: string = ''
  permRiskLevel: string = ''
  permStatus: string = ''
  // Metadata
  isStreaming: boolean = false
  timestamp: string = ''
}

/**
 * SessionTurn — renders a single conversation turn.
 * Combines user message, assistant markdown, tool cards, and system messages.
 * Matches OpenCode Desktop's session-turn component layout.
 */
@Component
export struct SessionTurn {
  @Prop turn: TurnData = new TurnData()

  build() {
    Column() {
      // ═══════ User Message ═══════
      if (this.turn.userContent.length > 0) {
        Column() {
          Text('user')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT_TEXT)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: Theme.sp.sm })

          Text(this.turn.userContent)
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .lineHeight(20)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({ top: Theme.sp.lg, bottom: Theme.sp.lg })
        .borderWidth({ bottom: 1 })
        .borderColor(Theme.BORDER)
      }

      // ═══════ Assistant / Tool / System Blocks ═══════
      ForEach(this.turn.assistantBlocks, (block: TranscriptBlock) => {
        if (block.type === 'assistant') {
          this.AssistantContent(block)
        } else if (block.type === 'tool') {
          this.ToolContent(block)
        } else if (block.type === 'system') {
          this.SystemContent(block)
        }
      }, (block: TranscriptBlock) => block.id)

      // ═══════ Streaming Indicator ═══════
      if (this.turn.streamingState.length > 0) {
        ThinkingHeading({
          state: this.turn.streamingState,
          toolName: this.turn.activeToolName
        })
      }
    }
    .width('100%')
  }

  // ══════════ Assistant Content (Markdown) ══════════
  @Builder
  AssistantContent(block: TranscriptBlock) {
    Column() {
      Text('agent')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.SUCCESS)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: Theme.sp.sm })

      MarkdownRenderer({
        content: block.content,
        baseFontSize: Theme.fs.md
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: Theme.sp.lg, bottom: Theme.sp.lg })
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }

  // ══════════ Tool Content (Specialized Cards) ══════════
  @Builder
  ToolContent(block: TranscriptBlock) {
    Stack() {
      if (this.normalizeToolName(block.toolName) === 'bash') {
        BashToolCard({
          toolStatus: block.toolStatus,
          command: this.getStringArg(block.toolInput, 'command'),
          output: block.toolOutput,
          exitCode: this.getExitCode(block.toolOutput)
        })
      } else if (this.normalizeToolName(block.toolName) === 'edit') {
        EditToolCard({
          toolStatus: block.toolStatus,
          filePath: this.getStringArg(block.toolInput, 'path'),
          diff: this.getStringArg(block.toolInput, 'diff')
        })
      } else if (this.normalizeToolName(block.toolName) === 'write') {
        WriteToolCard({
          toolStatus: block.toolStatus,
          filePath: this.getStringArg(block.toolInput, 'path'),
          content: this.getStringArg(block.toolInput, 'content')
        })
      } else if (this.normalizeToolName(block.toolName) === 'read') {
        ReadToolCard({
          toolStatus: block.toolStatus,
          filePath: this.getStringArg(block.toolInput, 'path')
        })
      } else if (this.normalizeToolName(block.toolName) === 'grep') {
        GrepToolCard({
          toolStatus: block.toolStatus,
          pattern: this.getStringArg(block.toolInput, 'pattern'),
          matchCount: '',
          results: block.toolOutput
        })
      } else if (this.normalizeToolName(block.toolName) === 'glob') {
        GlobToolCard({
          toolStatus: block.toolStatus,
          pattern: this.getStringArg(block.toolInput, 'pattern'),
          fileCount: ''
        })
      } else if (this.normalizeToolName(block.toolName) === 'webfetch') {
        WebFetchToolCard({
          toolStatus: block.toolStatus,
          url: this.getStringArg(block.toolInput, 'url'),
          summary: block.toolOutput
        })
      } else {
        BasicToolCard({
          toolName: block.toolName,
          toolStatus: block.toolStatus,
          summary: this.getSummary(block.toolInput),
          detail: block.toolOutput,
          step: block.toolStep
        })
      }
    }
  }

  // ══════════ System Content ══════════
  @Builder
  SystemContent(block: TranscriptBlock) {
    Row() {
      Text('--')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .margin({ right: Theme.sp.md })
      Text(block.content)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
    }
    .width('100%')
    .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
  }

  // ══════════ Helpers ══════════

  private normalizeToolName(name: string): string {
    const lower = name.toLowerCase()
    if (lower.indexOf('bash') >= 0) return 'bash'
    if (lower.indexOf('edit') >= 0) return 'edit'
    if (lower.indexOf('write') >= 0) return 'write'
    if (lower.indexOf('read') >= 0) return 'read'
    if (lower.indexOf('grep') >= 0) return 'grep'
    if (lower.indexOf('glob') >= 0) return 'glob'
    if (lower.indexOf('webfetch') >= 0 || lower.indexOf('web_fetch') >= 0) return 'webfetch'
    return lower
  }

  private getStringArg(jsonStr: string, key: string): string {
    if (jsonStr.length === 0) return ''
    // Fast path: look for "key":"value" or "key": "value" pattern
    const pattern1 = `"${key}":"`
    const pattern2 = `"${key}": "`
    const pattern3 = `"${key}":"`
    let idx = jsonStr.indexOf(pattern1)
    if (idx >= 0) {
      const start = idx + pattern1.length
      const end = jsonStr.indexOf('"', start)
      if (end > start) return jsonStr.substring(start, end)
    }
    idx = jsonStr.indexOf(pattern2)
    if (idx >= 0) {
      const start = idx + pattern2.length
      const end = jsonStr.indexOf('"', start)
      if (end > start) return jsonStr.substring(start, end)
    }
    return ''
  }

  private getSummary(input: string): string {
    if (input.length === 0) return ''
    if (input.length <= 80) return input
    return input.substring(0, 80) + '...'
  }

  private getExitCode(result: string): string {
    if (result.length === 0) return ''
    const pattern = `"exit_code":`
    const idx = result.indexOf(pattern)
    if (idx >= 0) {
      const start = idx + pattern.length
      let end = start
      while (end < result.length) {
        const ch = result.charAt(end)
        if (ch === ',' || ch === '}' || ch === ' ') {
          if (end > start) return result.substring(start, end).trim()
          break
        }
        end += 1
      }
    }
    return ''
  }
}
