import { ChatMessage, MessageRole } from '../model/ChatMessage';
import { Theme } from './Theme';

/**
 * Chat view component that renders message bubbles and handles scrolling.
 * Reusable across different pages that need chat display.
 * Updated with Catppuccin Mocha design system.
 */
@Component
export struct ChatView {
  @Prop messages: ChatMessage[] = [];
  @Prop isGenerating: boolean = false;
  onStopGeneration?: () => void;

  private scroller: Scroller = new Scroller();
  private lastMessageCount: number = 0;

  aboutToAppear(): void {
    setTimeout(() => { this.scrollToBottom(); }, 100)
  }

  private scrollToBottom(): void {
    if (this.messages.length > 0) {
      this.scroller.scrollEdge(Edge.Bottom)
    }
  }

  build() {
    if (this.messages.length !== this.lastMessageCount) {
      this.lastMessageCount = this.messages.length;
      setTimeout(() => { this.scrollToBottom(); }, 50)
    }

    Column() {
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (msg) => {
          ListItem() {
            this.MessageBubble(msg)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })
      .onReachEnd(() => {})

      if (this.messages.length === 0) {
        this.EmptyState()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  EmptyState() {
    Column() {
      Column() {
        Text('OC')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
      }
      .width(64)
      .height(64)
      .backgroundColor(Theme.ACCENT_DIM)
      .borderRadius(16)
      .justifyContent(FlexAlign.Center)
      .margin({ bottom: 16 })

      Text('Welcome to OpenCode')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: 8 })

      Text('Type a message below to start coding with AI')
        .fontSize(14)
        .fontColor(Theme.TEXT_MUTED)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    Row() {
      if (msg.role === MessageRole.Assistant) {
        this.AssistantMessage(msg)
      } else if (msg.role === MessageRole.User) {
        Blank()
        this.UserMessage(msg)
      } else {
        Text(msg.content)
          .fontSize(12)
          .fontColor(Theme.TEXT_MUTED)
          .fontStyle(FontStyle.Italic)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding(8)
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  AssistantMessage(msg: ChatMessage) {
    Row() {
      // Avatar
      Column() {
        Text('AI')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
      }
      .width(32)
      .height(32)
      .backgroundColor(Theme.ACTIVE_BG)
      .borderRadius(8)
      .justifyContent(FlexAlign.Center)
      .margin({ right: 12 })

      Column() {
        // Header
        Row() {
          Text('Assistant')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_SECONDARY)

          if (msg.isStreaming) {
            LoadingProgress()
              .width(12)
              .height(12)
              .color(Theme.ACCENT)
              .margin({ left: 8 })
          }
        }
        .margin({ bottom: 6 })

        // Content
        Text(msg.content.length > 0 ? msg.content : (msg.isStreaming ? 'Thinking...' : ''))
          .fontSize(14)
          .fontColor(Theme.TEXT_PRIMARY)
          .lineHeight(22)
          .copyOption(CopyOptions.LocalDevice)
      }
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .backgroundColor(Theme.PANEL)
      .borderWidth(1)
      .borderColor(Theme.BORDER)
      .borderRadius(12)
      .constraintSize({ maxWidth: '85%' })
    }
  }

  @Builder
  UserMessage(msg: ChatMessage) {
    Column() {
      // Header
      Row() {
        Text('You')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.TEXT_SECONDARY)
      }
      .margin({ bottom: 6 })
      .alignSelf(ItemAlign.End)

      // Content
      Text(msg.content)
        .fontSize(14)
        .fontColor(Theme.TEXT_PRIMARY)
        .lineHeight(22)
        .copyOption(CopyOptions.LocalDevice)
    }
    .alignItems(HorizontalAlign.End)
    .padding(12)
    .backgroundColor(Theme.ACCENT_DIM)
    .borderWidth(1)
    .borderColor(Theme.ACCENT)
    .borderRadius({ topLeft: 12, topRight: 12, bottomLeft: 12, bottomRight: 4 })
    .constraintSize({ maxWidth: '85%' })
  }
}
