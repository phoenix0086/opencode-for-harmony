import { router } from '@kit.ArkUI';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { ConnectionStatus } from '../model/AppState';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';
import { errStr } from '../utils/ErrorUtil';

/**
 * Server configuration page.
 * Allows users to add/edit server connections and manage saved servers.
 */
@Entry
@Component
struct ServerConfig {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel();
  @State serverUrl: string = '';
  @State username: string = '';
  @State password: string = '';
  @State displayName: string = '';
  @State testingConnection: boolean = false;
  @State testResult: string = '';
  @State testSuccess: boolean = false;

  aboutToAppear(): void {
    this.serverUrl = this.viewModel.serverInfo.url || Constants.DEFAULT_SERVER_URL;
    this.username = this.viewModel.serverInfo.username;
    this.password = this.viewModel.serverInfo.password;
    this.displayName = this.viewModel.serverInfo.displayName;
  }

  build() {
    Column() {
      // Header
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

        Text('Server Configuration')
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

      Scroll() {
        Column() {
          // Server info card
          Column() {
            Row() {
              Text('🖥️').fontSize(32)
                .fontSize(32)
                .fontColor('#FFFFFF')
              Column() {
                Text(this.displayName || 'OpenCode Server')
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                Text(this.serverUrl)
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 16 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#1E1E1E')
          .borderRadius(12)
          .margin({ bottom: 24 })

          // Connection fields
          Text('Connection Details')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .margin({ bottom: 16 })

          this.Field('Display Name', this.displayName, 'My Server', (v: string) => {
            this.displayName = v;
          })

          this.Field('Server URL', this.serverUrl, Constants.DEFAULT_SERVER_URL, (v: string) => {
            this.serverUrl = v;
          })

          this.Field('Username', this.username, 'opencode', (v: string) => {
            this.username = v;
          })

          this.Field('Password', this.password, 'password', (v: string) => {
            this.password = v;
          }, true)

          // Test connection
          if (this.testResult.length > 0) {
            Row() {
              Circle()
                .width(8)
                .height(8)
                .fill(this.testSuccess ? '#00C853' : '#FF5252')
              Text(this.testResult)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .margin({ left: 8 })
            }
            .margin({ top: 12 })
          }

          // Action buttons
          Row() {
            Button(this.testingConnection ? 'Testing...' : 'Test Connection')
              .height(44)
              .layoutWeight(1)
              .backgroundColor('#2D2D2D')
              .borderRadius(8)
              .fontColor('#FFFFFF')
              .enabled(!this.testingConnection)
              .onClick(() => {
                this.testConnection();
              })

            Button('Save & Connect')
              .height(44)
              .layoutWeight(1)
              .backgroundColor('#007DFF')
              .borderRadius(8)
              .fontColor('#FFFFFF')
              .margin({ left: 12 })
              .onClick(() => {
                this.viewModel.serverInfo.url = this.serverUrl;
                this.viewModel.serverInfo.username = this.username;
                this.viewModel.serverInfo.password = this.password;
                this.viewModel.serverInfo.displayName = this.displayName;
                this.viewModel.saveServerConfig();
                this.viewModel.connect();
                router.back();
              })
          }
          .width('100%')
          .margin({ top: 24 })
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
  Field(label: string, value: string, placeholder: string,
    onChange: (v: string) => void, isPassword: boolean = false) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .margin({ bottom: 6 })
      TextInput({ placeholder: placeholder, text: value })
        .width('100%')
        .height(44)
        .backgroundColor('#1E1E1E')
        .borderRadius(10)
        .fontColor('#FFFFFF')
        .placeholderColor('#555555')
        .type(isPassword ? InputType.Password : InputType.Normal)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  private async testConnection(): Promise<void> {
    this.testingConnection = true;
    this.testResult = '';

    try {
      // Temporarily set server info for testing
      const savedUrl = this.viewModel.serverInfo.url;
      const savedUser = this.viewModel.serverInfo.username;
      const savedPass = this.viewModel.serverInfo.password;

      this.viewModel.serverInfo.url = this.serverUrl;
      this.viewModel.serverInfo.username = this.username;
      this.viewModel.serverInfo.password = this.password;
      this.viewModel.httpService.setServer(this.viewModel.serverInfo);

      const ok = await this.viewModel.httpService.checkHealth();
      this.testSuccess = ok;
      this.testResult = ok ? 'Connection successful!' : 'Health check failed';

      // Restore
      this.viewModel.serverInfo.url = savedUrl;
      this.viewModel.serverInfo.username = savedUser;
      this.viewModel.serverInfo.password = savedPass;
    } catch (err) {
      this.testSuccess = false;
      this.testResult = 'Connection failed: ' + errStr(err);
    } finally {
      this.testingConnection = false;
    }
  }
}
