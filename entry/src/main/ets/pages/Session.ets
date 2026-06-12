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
  private scroller: Scroller = new Scroller();

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
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
            if (msg.isStreaming) {
              LoadingProgress()
                .width(16)
                .height(16)
                .color('#007DFF')
                .margin({ left: 8 })
            }
          }
          .margin({ bottom: 6 })

          Text(msg.content)
            .fontSize(14)
            .fontColor('#FFFFFF')
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
    .width('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 6 })
    .alignItems(VerticalAlign.Top)
  }

  private send(): void {
    if (this.inputText.length > 0) {
      this.viewModel.sendMessage(this.inputText);
      this.inputText = '';
      this.autoScroll = true;
    }
  }
}
