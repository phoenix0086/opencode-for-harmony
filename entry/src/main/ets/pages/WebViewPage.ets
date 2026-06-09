import web_webview from '@ohos.web.webview';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger';

/**
 * WebView page that loads the OpenCode web interface.
 * Connects to the configured server URL and renders the full web UI.
 */
@Entry
@Component
struct WebViewPage {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel();
  @State webViewUrl: string = '';
  @State isLoading: boolean = true;
  @State loadError: string = '';
  private webController: web_webview.WebviewController = new web_webview.WebviewController();

  aboutToAppear(): void {
    if (this.viewModel.serverInfo.url.length > 0 &&
      this.viewModel.connectionStatus === 'connected') {
      this.webViewUrl = this.viewModel.serverInfo.url;
    } else {
      this.webViewUrl = Constants.DEFAULT_SERVER_URL;
    }
  }

  build() {
    Column() {
      // Toolbar
      Row() {
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.webController.accessBackward()) {
            this.webController.backward();
          }
        })

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.webController.accessForward()) {
            this.webController.forward();
          }
        })

        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
            .fontSize(18)
            .fontColor(['#FFFFFF'])
        }
        .width(32)
        .height(32)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.webController.refresh();
        })

        Text(this.webViewUrl)
          .fontSize(13)
          .fontColor('#AAAAAA')
          .margin({ left: 12 })
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.isLoading ? 'Loading...' : 'Ready')
          .fontSize(12)
          .fontColor(this.isLoading ? '#FFB300' : '#00C853')
      }
      .width('100%')
      .height(Constants.TITLE_BAR_HEIGHT)
      .padding({ left: 8, right: 16 })
      .alignItems(VerticalAlign.Center)
      .backgroundColor('#1A1A1A')

      Divider().color('#2D2D2D').width('100%')

      if (this.loadError.length > 0) {
        // Error state
        Column() {
          Text('Failed to load')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF5252')
            .margin({ bottom: 8 })
          Text(this.loadError)
            .fontSize(14)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 16 })
          Button('Retry')
            .height(40)
            .width(120)
            .backgroundColor('#007DFF')
            .borderRadius(8)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.loadError = '';
              this.webController.loadUrl(this.webViewUrl);
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(32)
      } else {
        // WebView
        Web({ src: this.webViewUrl, controller: this.webController })
          .layoutWeight(1)
          .width('100%')
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .onPageBegin(() => {
            this.isLoading = true;
            Logger.info('WebView loading');
          })
          .onPageEnd(() => {
            this.isLoading = false;
            Logger.info('WebView loaded');
          })
          .onErrorReceive(() => {
            this.isLoading = false;
            this.loadError = 'WebView error';
            Logger.error('WebView error');
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
  }
}
