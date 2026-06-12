import { MainViewModel } from '../viewmodel/MainViewModel';
import { ChatMessage, MessageRole } from '../model/ChatMessage';
import { Constants } from '../utils/Constants';

/**
 * Dedicated session/chat page for focused conversation view.
 * Provides full-screen chat with message history and input.
 */
@Entry
@Component
struct Session {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel();
  @State inputText: string = '';
  @State autoScroll: boolean = true;
  @State thinkingDots: number = 0;
  private scroller: Scroller = new Scroller();
  private thinkingTimerId: number = -1;

  aboutToAppear(): void {
    this.startThinkingAnimation();
  }

  aboutToDisappear(): void {
    this.stopThinkingAnimation();
  }

  private startThinkingAnimation(): void {
    this.stopThinkingAnimation();
    this.thinkingDots = 0;
    this.thinkingTimerId = setInterval(() => {
      this.thinkingDots = (this.thinkingDots + 1) % 4;
    }, 500);
  }

  private stopThinkingAnimation(): void {
    if (this.thinkingTimerId !== -1) {
      clearInterval(this.thinkingTimerId);
      this.thinkingTimerId = -1;
    }
  }

  private buildDots(): string {
    let s = '';
    for (let i = 0; i < this.thinkingDots; i++) {
      s += '.';
    }
    return s;
  }

  build() {
    Column() {
      // Chat header
      Row() {
        Column() {
          Text(this.viewModel.currentSessionId.length > 0 ? 'Session' : 'New Chat')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
          Text(this.viewModel.selectedModel)
            .fontSize(12)
            .fontColor('#FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        if (this.viewModel.isGenerating) {
          Button('Stop')
            .height(32)
            .backgroundColor('#FF5252')
            .borderRadius(6)
            .fontColor('#FFFFFF')
            .fontSize(13)
            .onClick(() => {
              this.viewModel.stopGeneration();
            })
        }

        Button('New')
          .height(32)
          .width(56)
          .backgroundColor('#2D2D2D')
          .borderRadius(6)
          .fontColor('#FFFFFF')
          .fontSize(13)
          .margin({ left: 8 })
          .onClick(() => {
            this.viewModel.currentSessionId = '';
            this.viewModel.messages = [];
          })
      }
      .width('100%')
      .height(Constants.TITLE_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#2D2D2D').width('100%')

      // Messages
      List({ scroller: this.scroller }) {
        ForEach(this.viewModel.messages, (msg: ChatMessage) => {
          ListItem() {
            this.MessageBubble(msg)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })
      .onReachEnd(() => {
        this.autoScroll = true;
      })
      .onScrollIndex(() => {
        if (this.autoScroll && this.viewModel.messages.length > 0) {
          this.scroller.scrollToIndex(this.viewModel.messages.length - 1);
        }
      })
      .onAreaChange((oldArea, newArea) => {
        // 列表区域变化时（消息增减导致高度变化），自动滚动到底部
        if (this.autoScroll && this.viewModel.messages.length > 0) {
          setTimeout(() => {
            this.scroller.scrollToIndex(this.viewModel.messages.length - 1);
          }, 50)
        }
      })

      Divider().color('#2D2D2D').width('100%')

      // Input
      Row() {
        TextInput({ placeholder: 'Type a message...', text: this.inputText })
          .layoutWeight(1)
          .height(44)
          .backgroundColor('#1E1E1E')
          .borderRadius(10)
          .fontColor('#FFFFFF')
          .placeholderColor('#555555')
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.send();
          })

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_up'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])
        }
        .width(44)
        .height(44)
        .backgroundColor(this.inputText.length > 0 ? '#007DFF' : '#333333')
        .borderRadius(22)
        .margin({ left: 8 })
        .enabled(this.inputText.length > 0 && !this.viewModel.isGenerating)
        .onClick(() => {
          this.send();
        })
      }
      .width('100%')
      .height(60)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    if (msg.role === MessageRole.Assistant) {
      // Assistant — LEFT side, AI avatar ABOVE the message bubble
      Column() {
        this.AvatarHeader()
        this.AssistantBubble(msg)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    } else if (msg.role === MessageRole.User) {
      // User — RIGHT side bubble
      Row() {
        Blank()
        this.UserBubble(msg)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Top)
    } else {
      // System message
      Text(msg.content)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .fontStyle(FontStyle.Italic)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ top: 8, bottom: 8 })
    }
  }

  @Builder
  AvatarHeader() {
    Row() {
      Column() {
        Text('AI')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(28)
      .height(28)
      .borderRadius(14)
      .backgroundColor('#007DFF')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .margin({ bottom: 6 })
  }

  @Builder
  AssistantBubble(msg: ChatMessage) {
    Column() {
      if (msg.content.length > 0) {
        Text(msg.content)
          .fontSize(14)
          .fontColor('#FFFFFF')
          .lineHeight(22)
          .copyOption(CopyOptions.LocalDevice)
      } else if (msg.isStreaming) {
        Text('Thinking' + this.buildDots())
          .fontSize(14)
          .fontColor('#FFFFFF')
          .fontStyle(FontStyle.Italic)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .backgroundColor('#1A1A1A')
    .borderRadius(12)
    .borderWidth(1)
    .borderColor('#2D2D2D')
    .constraintSize({ maxWidth: '85%' })
  }

  @Builder
  UserBubble(msg: ChatMessage) {
    Column() {
      Text(msg.content)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .lineHeight(22)
        .textAlign(TextAlign.Start)
        .copyOption(CopyOptions.LocalDevice)
    }
    .alignItems(HorizontalAlign.End)
    .padding(12)
    .backgroundColor('#007DFF')
    .borderRadius(12)
    .constraintSize({ maxWidth: '85%' })
  }

  private send(): void {
    if (this.inputText.length > 0) {
      this.viewModel.sendMessage(this.inputText);
      this.inputText = '';
      this.autoScroll = true;
    }
  }
}
