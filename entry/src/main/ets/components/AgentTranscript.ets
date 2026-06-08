import { Theme } from './Theme'
import { MessageInfo, MessagePart, PermissionRequest } from '../models/Event'

/**
 * Agent Transcript 组件
 * 以 IDE transcript 格式展示用户消息、AI 回复、工具调用
 * 替代聊天气泡布局
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

@Component
export struct AgentTranscript {
  @Prop blocks: TranscriptBlock[] = []
  @Prop isStreaming: boolean = false
  onApprovePermission: (id: string) => void = () => {}
  onRejectPermission: (id: string) => void = () => {}

  build() {
    List() {
      ForEach(this.blocks, (block: TranscriptBlock) => {
        ListItem() {
          if (block.type === 'user') {
            this.UserBlock(block)
          } else if (block.type === 'assistant') {
            this.AssistantBlock(block)
          } else if (block.type === 'tool') {
            this.ToolBlock(block)
          } else if (block.type === 'permission') {
            this.PermissionBlock(block)
          } else if (block.type === 'system') {
            this.SystemBlock(block)
          }
        }
      }, (block: TranscriptBlock) => block.id)

      // Streaming indicator
      if (this.isStreaming) {
        ListItem() {
          Row() {
            LoadingProgress()
              .width(14)
              .height(14)
              .color(Theme.ACCENT)
            Text('agent is thinking...')
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ left: Theme.sp.md })
          }
          .padding({ left: Theme.sp.xl, top: Theme.sp.md, bottom: Theme.sp.md })
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
    .divider({ strokeWidth: 0 })
    .scrollBar(BarState.Auto)
    .backgroundColor('transparent')
    .padding({ left: Theme.sp.xl, right: Theme.sp.xl })
  }

  // ══════════ User Block ══════════
  @Builder
  UserBlock(block: TranscriptBlock) {
    Column() {
      // Role label
      Text('user')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.ACCENT_TEXT)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: Theme.sp.sm })

      Text(block.content)
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

  // ══════════ Assistant Block ══════════
  @Builder
  AssistantBlock(block: TranscriptBlock) {
    Column() {
      Text('agent')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.SUCCESS)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: Theme.sp.sm })

      Text(block.content)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .lineHeight(20)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: Theme.sp.lg, bottom: Theme.sp.lg })
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }

  // ══════════ Tool Block (Compact Timeline) ══════════
  @Builder
  ToolBlock(block: TranscriptBlock) {
    Row() {
      // Status indicator
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.getToolStatusColor(block.toolStatus))
        .borderRadius(2)
        .margin({ right: Theme.sp.md })

      // Tool info
      Column() {
        Row() {
          // Tool name badge
          Text(block.toolName)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(Theme.rd.sm)
            .padding({ left: Theme.sp.md, right: Theme.sp.md, top: 1, bottom: 1 })

          // Status
          Text(this.getToolStatusLabel(block.toolStatus))
            .fontSize(Theme.fs.xs)
            .fontColor(this.getToolStatusColor(block.toolStatus))
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.md })

          // Step number
          if (block.toolStep > 0) {
            Text(`step ${block.toolStep}`)
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .margin({ left: Theme.sp.md })
          }

          Blank()

          // Running spinner
          if (block.toolStatus === 'running') {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(Theme.ACCENT)
          }
        }
        .width('100%')

        // Tool input (compact)
        if (block.toolInput.length > 0) {
          Text(block.toolInput)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(Theme.rd.sm)
            .padding(Theme.sp.sm)
            .width('100%')
        }

        // Tool output (compact)
        if (block.toolOutput.length > 0 && block.toolStatus !== 'running') {
          Text(block.toolOutput)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: Theme.sp.md, bottom: Theme.sp.md, left: Theme.sp.md, right: Theme.sp.md })
    .backgroundColor(Theme.TOOL_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(Theme.TOOL_BORDER)
    .margin({ top: Theme.sp.sm, bottom: Theme.sp.sm })
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

  // ══════════ System Block ══════════
  @Builder
  SystemBlock(block: TranscriptBlock) {
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

  private getToolStatusColor(status: string): string {
    if (status === 'running') return Theme.ACCENT
    if (status === 'success') return Theme.SUCCESS
    if (status === 'error') return Theme.DANGER
    if (status === 'cancelled') return Theme.TEXT_MUTED
    return Theme.TEXT_MUTED
  }

  private getToolStatusLabel(status: string): string {
    if (status === 'running') return 'running'
    if (status === 'success') return 'done'
    if (status === 'error') return 'error'
    if (status === 'cancelled') return 'cancelled'
    return status
  }

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
