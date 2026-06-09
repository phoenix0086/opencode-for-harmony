import { AppView } from '../model/AppState';
import { ConnectionStatus } from '../model/AppState';

/**
 * Navigation sidebar component with collapsible design.
 * Provides navigation items and connection status indicator.
 */
@Component
export struct SidePanel {
  @Prop currentView: AppView = AppView.Home;
  @Prop collapsed: boolean = false;
  @Prop connectionStatus: ConnectionStatus = ConnectionStatus.Disconnected;
  @Prop serverUrl: string = '';
  onNavigate?: (view: AppView) => void;
  onToggleCollapse?: () => void;
  onSettingsClick?: () => void;

  private navItems: NavItemInfo[] = [
    { view: AppView.Home, icon: 'sys.symbol.house', label: 'Home' },
    { view: AppView.Chat, icon: 'sys.symbol.bubble_left', label: 'Chat' },
    { view: AppView.Files, icon: 'sys.symbol.folder', label: 'Files' },
    { view: AppView.Terminal, icon: 'sys.symbol.terminal', label: 'Terminal' },
    { view: AppView.WebView, icon: 'sys.symbol.globe', label: 'Web UI' }
  ];

  build() {
    Column() {
      // Header
      Row() {
        if (!this.collapsed) {
          Text('OpenCode')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
        Blank()
        Button() {
          SymbolGlyph(this.collapsed ? $r('sys.symbol.chevron_right') : $r('sys.symbol.chevron_left'))
            .fontSize(14)
            .fontColor(['#AAAAAA'])
        }
        .width(28)
        .height(28)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.onToggleCollapse?.();
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 12, right: 8 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#333333').width('100%')

      // Navigation items
      Column() {
        ForEach(this.navItems, (item) => {
          Button() {
            Row() {
              SymbolGlyph($r(item.icon))
                .fontSize(18)
                .fontColor([this.currentView === item.view ? '#007DFF' : '#AAAAAA'])
              if (!this.collapsed) {
                Text(item.label)
                  .fontSize(14)
                  .fontColor(this.currentView === item.view ? '#FFFFFF' : '#AAAAAA')
                  .fontWeight(this.currentView === item.view ? FontWeight.Medium : FontWeight.Normal)
                  .margin({ left: 12 })
              }
            }
          }
          .width('100%')
          .height(40)
          .backgroundColor(this.currentView === item.view ? '#2A2A2A' : Color.Transparent)
          .borderRadius(8)
          .margin({ left: 4, right: 4, top: 2, bottom: 2 })
          .onClick(() => {
            this.onNavigate?.(item.view);
          })
        })
      }
      .layoutWeight(1)
      .padding({ top: 8 })

      Divider().color('#333333').width('100%')

      // Status
      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.getStatusColor())
        if (!this.collapsed) {
          Text(this.getStatusText())
            .fontSize(12)
            .fontColor('#AAAAAA')
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .height(36)
      .padding({ left: 12, right: 12 })
      .alignItems(VerticalAlign.Center)

      // Settings
      Button() {
        Row() {
          SymbolGlyph($r('sys.symbol.gear'))
            .fontSize(16)
            .fontColor(['#AAAAAA'])
          if (!this.collapsed) {
            Text('Settings')
              .fontSize(14)
              .fontColor('#AAAAAA')
              .margin({ left: 10 })
          }
        }
      }
      .width('100%')
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onSettingsClick?.();
      })
    }
    .width(this.collapsed ? 56 : 240)
    .height('100%')
    .backgroundColor('#1A1A1A')
    .animation({ duration: 200, curve: Curve.EaseInOut })
  }

  private getStatusColor(): ResourceColor {
    switch (this.connectionStatus) {
      case ConnectionStatus.Connected: return '#00C853';
      case ConnectionStatus.Connecting: return '#FFB300';
      case ConnectionStatus.Error: return '#FF5252';
      default: return '#666666';
    }
  }

  private getStatusText(): string {
    switch (this.connectionStatus) {
      case ConnectionStatus.Connected: return 'Connected';
      case ConnectionStatus.Connecting: return 'Connecting...';
      case ConnectionStatus.Error: return 'Error';
      default: return 'Disconnected';
    }
  }
}

class NavItemInfo {
  view: AppView = AppView.Home;
  icon: string = '';
  label: string = '';
}
