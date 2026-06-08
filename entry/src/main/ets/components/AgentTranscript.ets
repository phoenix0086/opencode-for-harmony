import { Theme } from './Theme'
import { SessionTurn, TurnData, TranscriptBlock } from './SessionTurn'

export { TranscriptBlock }

/**
 * Agent Transcript 组件 — M13 重构
 * 以 OpenCode Desktop 风格渲染对话:
 * - 用户消息 + AI 回复 + 工具调用按 turn 分组
 * - AI 回复使用 MarkdownRenderer 渲染
 * - 工具调用使用专用卡片 (Bash/Edit/Write/Read/Grep/Glob/WebFetch)
 * - 流式状态使用 ThinkingHeading 指示器
 */
@Component
export struct AgentTranscript {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop blocks: TranscriptBlock[] = []
  @Prop isStreaming: boolean = false
  onApprovePermission: (id: string) => void = () => {}
  onRejectPermission: (id: string) => void = () => {}
  onAlwaysApprovePermission: (id: string) => void = () => {}
  @State turns: TurnData[] = []
  private lastBlocksLen: number = -1

  aboutToAppear(): void {
    this.buildTurns()
    this.lastBlocksLen = this.blocks.length
  }

  /**
   * Group flat block list into turns.
   * A turn = optional user message + subsequent assistant/tool/system blocks.
   */
  private buildTurns(): void {
    const result: TurnData[] = []
    for (let i = 0; i < this.blocks.length; i++) {
      const block = this.blocks[i]

      if (block.type === 'permission') {
        // Permissions stay at transcript level, not in turns
        continue
      }

      if (block.type === 'user') {
        const turn = new TurnData()
        turn.id = block.id
        turn.userContent = block.content
        result.push(turn)
        continue
      }

      // assistant / tool / system
      if (block.type === 'assistant') {
        const prev = i > 0 ? this.blocks[i - 1] : null
        const isNewTurn = prev === null || prev.type === 'user' || prev.type === 'permission' || prev.type === 'system'
        if (isNewTurn || result.length === 0) {
          const turn = new TurnData()
          turn.id = block.id
          turn.assistantBlocks = [block]
          result.push(turn)
        } else {
          result[result.length - 1].assistantBlocks.push(block)
        }
      } else {
        // tool or system — append to current turn
        if (result.length > 0) {
          result[result.length - 1].assistantBlocks.push(block)
        } else {
          const turn = new TurnData()
          turn.id = block.id
          turn.assistantBlocks = [block]
          result.push(turn)
        }
      }
    }

    // Attach streaming state to last turn
    if (this.isStreaming && result.length > 0) {
      const last = result[result.length - 1]
      let hasRunningTool = false
      let runningToolName = ''
      for (let j = 0; j < last.assistantBlocks.length; j++) {
        const b = last.assistantBlocks[j]
        if (b.type === 'tool' && b.toolStatus === 'running') {
          hasRunningTool = true
          runningToolName = b.toolName
          break
        }
      }
      if (hasRunningTool) {
        last.streamingState = 'acting'
        last.activeToolName = runningToolName
      } else {
        // Check if last block is assistant (text streaming)
        const lastBlock = last.assistantBlocks.length > 0
          ? last.assistantBlocks[last.assistantBlocks.length - 1]
          : null
        if (lastBlock !== null && lastBlock.type === 'assistant') {
          last.streamingState = 'responding'
        } else {
          last.streamingState = 'thinking'
        }
      }
    }

    this.turns = result
  }

  build() {
    List() {
      // ═══════ Interleaved turns and permissions ═══════
      ForEach(this.getRenderItems(), (item: RenderItem) => {
        ListItem() {
          if (item.kind === 'turn') {
            SessionTurn({ turn: item.turn })
          } else if (item.kind === 'permission') {
            this.PermissionBlock(item.block)
          }
        }
      }, (item: RenderItem) => item.id)

    }
    .layoutWeight(1)
    .width('100%')
    .divider({ strokeWidth: 0 })
    .scrollBar(BarState.Auto)
    .backgroundColor('transparent')
    .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
  }

  /**
   * Build render items: interleave turns with permission blocks
   * to preserve the original block ordering.
   */
  private getRenderItems(): RenderItem[] {
    // Rebuild turns when blocks array changes (replaces invalid @Watch on @Prop)
    if (this.blocks.length !== this.lastBlocksLen) {
      this.buildTurns()
      this.lastBlocksLen = this.blocks.length
    }
    const items: RenderItem[] = []
    let turnIdx = 0

    // Walk through original blocks to maintain ordering
    for (let i = 0; i < this.blocks.length; i++) {
      const block = this.blocks[i]
      if (block.type === 'permission') {
        const ri = new RenderItem()
        ri.id = block.id
        ri.kind = 'permission'
        ri.block = block
        items.push(ri)
      } else if (block.type === 'user' || (turnIdx < this.turns.length && this.turns[turnIdx].id === block.id)) {
        // This block starts a turn
        if (turnIdx < this.turns.length) {
          const ri = new RenderItem()
          ri.id = this.turns[turnIdx].id
          ri.kind = 'turn'
          ri.turn = this.turns[turnIdx]
          items.push(ri)
          turnIdx += 1
        }
      }
      // assistant/tool/system blocks that are part of a turn are already included in the turn
    }

    // If streaming with no blocks yet, add a placeholder
    if (items.length === 0 && this.isStreaming) {
      const placeholder = new TurnData()
      placeholder.id = '__streaming__'
      placeholder.streamingState = 'thinking'
      const ri = new RenderItem()
      ri.id = '__streaming__'
      ri.kind = 'turn'
      ri.turn = placeholder
      items.push(ri)
    }

    return items
  }

  // ══════════ Permission Block ══════════
  @Builder
  PermissionBlock(block: TranscriptBlock) {
    Row() {
      // Risk indicator
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.getRiskColor(block.permRiskLevel))
        .borderRadius(2)
        .margin({ right: Theme.sp.md })

      // Info
      Column() {
        Row() {
          Text(this.getPermIcon(block.permType))
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)

          Text(block.permType)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(Theme.rd.sm)
            .padding({ left: Theme.sp.sm, right: Theme.sp.sm })
            .margin({ left: Theme.sp.sm })

          Text(block.permTitle)
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: Theme.sp.md })
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        if (block.permDescription.length > 0) {
          Text(block.permDescription)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)

      // Action buttons
      if (block.permStatus === 'pending') {
        Row() {
          Text('allow')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.SUCCESS)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.SUCCESS_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .onClick(() => {
              this.onApprovePermission(block.id)
            })

          Text('always')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.ACCENT_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .margin({ left: Theme.sp.md })
            .onClick(() => {
              this.onAlwaysApprovePermission(block.id)
            })

          Text('deny')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.DANGER_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .margin({ left: Theme.sp.md })
            .onClick(() => {
              this.onRejectPermission(block.id)
            })
        }
      } else {
        Text(block.permStatus)
          .fontSize(Theme.fs.xs)
          .fontColor(block.permStatus === 'approved' ? Theme.SUCCESS : Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
      }
    }
    .width('100%')
    .padding({ top: Theme.sp.md, bottom: Theme.sp.md, left: Theme.sp.md, right: Theme.sp.md })
    .backgroundColor(Theme.TOOL_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(block.permStatus === 'pending' ? Theme.WARNING : Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
  }

  // ══════════ Permission Helpers ══════════

  private getRiskColor(level: string): string {
    if (level === 'high') return Theme.DANGER
    if (level === 'medium') return Theme.WARNING
    return Theme.SUCCESS
  }

  private getPermIcon(permType: string): string {
    if (permType === 'bash') return '$'
    if (permType === 'edit') return 'E'
    if (permType === 'write') return 'W'
    if (permType === 'delete') return 'X'
    if (permType === 'webfetch') return 'G'
    return '?'
  }
}

/**
 * Internal render item for interleaving turns and permissions.
 */
class RenderItem {
  id: string = ''
  kind: string = '' // 'turn' | 'permission'
  turn: TurnData = new TurnData()
  block: TranscriptBlock = new TranscriptBlock()
}
