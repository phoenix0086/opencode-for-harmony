import { router } from '@kit.ArkUI';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { ConnectionStatus } from '../model/AppState';
import { Constants } from '../utils/Constants';

/**
 * Settings page for configuring server connection, model, and app preferences.
 */
@Entry
@Component
struct Settings {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel();
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State model: string = '';
  @State theme: string = Constants.DEFAULT_THEME;
  @State language: string = Constants.DEFAULT_LANGUAGE;
  @State saveMessage: string = '';

  aboutToAppear(): void {
    this.serverUrl = this.viewModel.serverInfo.url;
    this.username = this.viewModel.serverInfo.username;
    this.password = this.viewModel.serverInfo.password;
    this.model = this.viewModel.selectedModel;
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor(['#FFFFFF'])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.back();
        })

        Text('Settings')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ left: 12 })
      }
      .width('100%')
      .height(Constants.TITLE_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#2D2D2D').width('100%')

      // Settings form
      Scroll() {
        Column() {
          this.SectionHeader('Server Connection')
          this.FormField('Server URL', this.serverUrl, 'http://localhost:3000', (v: string) => {
            this.serverUrl = v;
          })
          this.FormField('Username', this.username, 'opencode', (v: string) => {
            this.username = v;
          })
          this.FormField('Password', this.password, 'password', (v: string) => {
            this.password = v;
          }, true)

          this.SectionHeader('AI Model')
          this.FormField('Model', this.model, Constants.DEFAULT_MODEL, (v: string) => {
            this.model = v;
          })

          this.SectionHeader('Appearance')
          this.SelectField('Theme', [Constants.THEME_SYSTEM, Constants.THEME_LIGHT, Constants.THEME_DARK],
            this.theme, (v: string) => {
              this.theme = v;
            })
          this.SelectField('Language', ['zh_CN', 'en_US'], this.language, (v: string) => {
            this.language = v;
          })

          // Action buttons
          Row() {
            Button('Save & Connect')
              .height(44)
              .layoutWeight(1)
              .backgroundColor('#007DFF')
              .borderRadius(8)
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.viewModel.serverInfo.url = this.serverUrl;
                this.viewModel.serverInfo.username = this.username;
                this.viewModel.serverInfo.password = this.password;
                this.viewModel.selectedModel = this.model;
                this.viewModel.saveServerConfig();
                this.viewModel.connect();
                this.saveMessage = 'Saved. Connecting...';
              })
            Button('Save Only')
              .height(44)
              .width(100)
              .backgroundColor('#2D2D2D')
              .borderRadius(8)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
              .onClick(() => {
                this.viewModel.serverInfo.url = this.serverUrl;
                this.viewModel.serverInfo.username = this.username;
                this.viewModel.serverInfo.password = this.password;
                this.viewModel.selectedModel = this.model;
                this.viewModel.saveServerConfig();
                this.saveMessage = 'Settings saved';
              })
          }
          .width('100%')
          .margin({ top: 24 })

          if (this.saveMessage.length > 0) {
            Text(this.saveMessage)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .margin({ top: 12 })
          }

          if (this.viewModel.errorMessage.length > 0) {
            Text(this.viewModel.errorMessage)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .margin({ top: 8 })
          }

          // Connection status
          Row() {
            Circle()
              .width(10)
              .height(10)
              .fill(this.getStatusColor())
            Text(this.getStatusText())
              .fontSize(14)
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
          }
          .margin({ top: 20 })
        }
        .padding(24)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor('#FFFFFF')
      .margin({ top: 24, bottom: 12 })
  }

  @Builder
  FormField(label: string, value: string, placeholder: string,
    onChange: (v: string) => void, isPassword: boolean = false) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .margin({ bottom: 6 })
      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(40)
        .backgroundColor('#1E1E1E')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .placeholderColor('#555555')
        .type(isPassword ? InputType.Password : InputType.Normal)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SelectField(label: string, options: string[], selected: string,
    onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .margin({ bottom: 6 })
      Row() {
        ForEach(options, (option: string) => {
          Button(option)
            .height(36)
            .backgroundColor(selected === option ? '#007DFF' : '#1E1E1E')
            .borderRadius(8)
            .fontColor('#FFFFFF')
            .fontSize(13)
            .margin({ right: 8 })
            .onClick(() => {
              onChange(option);
            })
        })
      }
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): ResourceColor {
    switch (this.viewModel.connectionStatus) {
      case ConnectionStatus.Connected: return '#00C853';
      case ConnectionStatus.Connecting: return '#FFB300';
      case ConnectionStatus.Error: return '#FF5252';
      default: return '#666666';
    }
  }

  private getStatusText(): string {
    switch (this.viewModel.connectionStatus) {
      case ConnectionStatus.Connected: return 'Connected to ' + this.viewModel.serverInfo.url;
      case ConnectionStatus.Connecting: return 'Connecting...';
      case ConnectionStatus.Error: return 'Error: ' + this.viewModel.errorMessage;
      default: return 'Disconnected';
    }
  }
}
