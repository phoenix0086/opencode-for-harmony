import { ChatMessage, MessageRole } from '../model/ChatMessage';

/**
 * Chat view component that renders message bubbles and handles scrolling.
 * Reusable across different pages that need chat display.
 */
@Component
export struct ChatView {
  @Prop messages: ChatMessage[] = [];
  @Prop isGenerating: boolean = false;
  onStopGeneration?: () => void;

  private scroller: Scroller = new Scroller();
  private lastMessageCount: number = 0;

  aboutToAppear(): void {
    // 初始加载后滚动到底部
    setTimeout(() => { this.scrollToBottom(); }, 100)
  }

  private scrollToBottom(): void {
    if (this.messages.length > 0) {
      this.scroller.scrollEdge(Edge.Bottom)
    }
  }

  build() {
    // 检测消息数量变化，自动滚动到底部
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
        Column() {
          Text('Start a conversation')
            .fontSize(18)
            .fontColor('#555555')
            .margin({ bottom: 8 })
          Text('Type a message below to begin')
            .fontSize(14)
            .fontColor('#444444')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    Row() {
      if (msg.role === MessageRole.Assistant) {
        Column() {
          Row() {
            Circle()
              .width(24)
              .height(24)
              .fill('#007DFF')
            Text('AI')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#007DFF')
              .margin({ left: 8 })
            if (msg.isStreaming) {
              LoadingProgress()
                .width(14)
                .height(14)
                .color('#007DFF')
                .margin({ left: 8 })
            }
          }
          .margin({ bottom: 6 })

          Text(msg.content.length > 0 ? msg.content : (msg.isStreaming ? 'Thinking...' : ''))
            .fontSize(14)
            .fontColor('#E0E0E0')
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(HorizontalAlign.Start)
        .padding(12)
        .backgroundColor('#1A1A1A')
        .borderRadius(12)
        .constraintSize({ maxWidth: '80%' })
      } else if (msg.role === MessageRole.User) {
        Blank()
        Column() {
          Text(msg.content)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(HorizontalAlign.End)
        .padding(12)
        .backgroundColor('#007DFF')
        .borderRadius(12)
        .constraintSize({ maxWidth: '80%' })
      } else {
        Text(msg.content)
          .fontSize(12)
          .fontColor('#666666')
          .fontStyle(FontStyle.Italic)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding(8)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top)
  }
}
