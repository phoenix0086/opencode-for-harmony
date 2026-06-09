import { ConnectionStatus } from '../model/AppState';

/**
 * Bottom status bar showing connection status, model info, and quick actions.
 */
@Component
export struct StatusBar {
  @Prop connectionStatus: ConnectionStatus = ConnectionStatus.Disconnected;
  @Prop model: string = '';
  @Prop serverUrl: string = '';
  @Prop messageCount: number = 0;
  @Prop isGenerating: boolean = false;

  build() {
    Row() {
      // Connection status
      Row() {
        Circle()
          .width(6)
          .height(6)
          .fill(this.getStatusColor())
        Text(this.getStatusLabel())
          .fontSize(11)
          .fontColor('#AAAAAA')
          .margin({ left: 6 })
      }

      Divider()
        .vertical(true)
        .height(16)
        .color('#333333')
        .margin({ left: 12, right: 12 })

      // Server
      Text(this.serverUrl.length > 0 ? this.serverUrl : 'No server')
        .fontSize(11)
        .fontColor('#666666')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 200 })

      Blank()

      if (this.isGenerating) {
        Row() {
          LoadingProgress()
            .width(12)
            .height(12)
            .color('#007DFF')
          Text('Generating...')
            .fontSize(11)
            .fontColor('#007DFF')
            .margin({ left: 6 })
        }
      }

      // Model
      if (this.model.length > 0) {
        Text(this.model)
          .fontSize(11)
          .fontColor('#666666')
          .margin({ left: 16 })
      }

      // Message count
      if (this.messageCount > 0) {
        Text(this.messageCount.toString() + ' msgs')
          .fontSize(11)
          .fontColor('#555555')
          .margin({ left: 16 })
      }
    }
    .width('100%')
    .height(28)
    .padding({ left: 12, right: 12 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor('#0D0D0D')
  }

  private getStatusColor(): ResourceColor {
    switch (this.connectionStatus) {
      case ConnectionStatus.Connected: return '#00C853';
      case ConnectionStatus.Connecting: return '#FFB300';
      case ConnectionStatus.Error: return '#FF5252';
      default: return '#555555';
    }
  }

  private getStatusLabel(): string {
    switch (this.connectionStatus) {
      case ConnectionStatus.Connected: return 'Connected';
      case ConnectionStatus.Connecting: return 'Connecting';
      case ConnectionStatus.Error: return 'Error';
      default: return 'Offline';
    }
  }
}
