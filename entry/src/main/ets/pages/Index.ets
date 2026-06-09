import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { StorageService } from '../service/StorageService';
import { ConnectionStatus, AppView, SessionInfo, ProviderInfo } from '../model/AppState';
import { ChatMessage } from '../model/ChatMessage';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger'
import { ProviderPage } from './ProviderPage';

/**
 * Main page of the OpenCode app.
 * Provides the primary navigation shell with a sidebar and content area.
 */
@Entry
@Component
struct Index {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel();
  @State currentView: AppView = AppView.Home;
  @State sidebarCollapsed: boolean = false;
  @State showSettings: boolean = false;
  @State initialized: boolean = false;

  private context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    if (!this.initialized) {
      const storage = new StorageService(this.context);
      await storage.init();
      await this.viewModel.init(storage);
      this.initialized = true;
      Logger.info('Index page initialized, starting auto-connect...');
      // Auto-start the built-in server and connect
      await this.viewModel.autoStartAndConnect();
    }
  }

  aboutToDisappear(): void {
    // Gracefully shut down the built-in server when the page is destroyed
    this.viewModel.shutdown();
    Logger.info('Index page destroyed, server shut down');
  }

  build() {
    Row() {
      // Sidebar
      if (!this.sidebarCollapsed) {
        Column() {
          // Logo area
          Row() {
            Text('OpenCode')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .margin({ left: 16 })
            Blank()
            Button() {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(16)
                .fontColor(['#FFFFFF'])
            }
            .width(28)
            .height(28)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.sidebarCollapsed = true;
            })
          }
          .width('100%')
          .height(Constants.TITLE_BAR_HEIGHT)
          .padding({ left: 8, right: 8 })
          .alignItems(VerticalAlign.Center)

          Divider()
            .color('#404040')
            .width('100%')

          // Nav items
          Column() {
            this.NavItem(AppView.Home, $r('app.media.home'), 'Home')
            this.NavItem(AppView.Chat, $r('app.media.chat'), 'Chat')
            this.NavItem(AppView.Provider, $r('app.media.server'), 'Provider')
            this.NavItem(AppView.Models, $r('app.media.settings'), 'Models')
            this.NavItem(AppView.Files, $r('app.media.globe'), 'Files')
            this.NavItem(AppView.Terminal, $r('app.media.terminal'), 'Terminal')
            this.NavItem(AppView.WebView, $r('app.media.globe'), 'Web UI')
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ top: 8 })

          Divider()
            .color('#404040')
            .width('100%')

          // Connection status
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill(this.getStatusColor())
            Text(this.getStatusText())
              .fontSize(12)
              .fontColor('#AAAAAA')
              .margin({ left: 8 })
          }
          .width('100%')
          .height(40)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          // Settings button
          Button() {
            Row() {
              Text('⚙️').fontSize(18)
                .fontSize(16)
                .fontColor('#FFFFFF')
              Text('Settings')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .margin({ left: 12 })
            }
          }
          .width('100%')
          .height(44)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.showSettings = !this.showSettings;
          })
        }
        .width(Constants.SIDEBAR_WIDTH)
        .height('100%')
        .backgroundColor('#1A1A1A')
      }

      // Collapse/expand handle
      if (this.sidebarCollapsed) {
        Column() {
          Button() {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor(['#FFFFFF'])
          }
          .width(32)
          .height(32)
          .backgroundColor('#2D2D2D')
          .borderRadius(16)
          .onClick(() => {
            this.sidebarCollapsed = false;
          })
        }
        .width(48)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#111111')
      }

      // Main content area
      Column() {
        if (this.showSettings) {
          this.SettingsContent()
        } else if (this.currentView === AppView.Home) {
          this.HomeContent()
        } else if (this.currentView === AppView.Chat) {
          this.ChatContent()
        } else if (this.currentView === AppView.Provider) {
          ProviderPage({ activeRunner: null })
        } else if (this.currentView === AppView.Models) {
          this.ModelsContent()
        } else if (this.currentView === AppView.WebView) {
          this.WebViewContent()
        } else if (this.currentView === AppView.Terminal) {
          this.TerminalContent()
        } else if (this.currentView === AppView.Files) {
          this.FilesContent()
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor('#111111')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  NavItem(view: AppView, icon: Resource, label: string) {
    Button() {
      Row() {
        SymbolGlyph(icon)
          .fontSize(18)
          .fontColor([this.currentView === view ? '#007DFF' : '#AAAAAA'])
        Text(label)
          .fontSize(14)
          .fontColor(this.currentView === view ? '#FFFFFF' : '#AAAAAA')
          .fontWeight(this.currentView === view ? FontWeight.Medium : FontWeight.Normal)
          .margin({ left: 12 })
      }
    }
    .width('100%')
    .height(40)
    .backgroundColor(this.currentView === view ? '#2A2A2A' : Color.Transparent)
    .borderRadius(8)
    .margin({ left: 8, right: 8, top: 2, bottom: 2 })
    .onClick(() => {
      this.currentView = view;
      this.showSettings = false;
    })
  }

  @Builder
  HomeContent() {
    Column() {
      Text('Welcome to OpenCode')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 16 })

      Text('Your AI-powered coding assistant on HarmonyOS')
        .fontSize(16)
        .fontColor('#AAAAAA')
        .margin({ bottom: 32 })

      if (this.viewModel.connectionStatus === ConnectionStatus.Connected) {
        // Show recent sessions
        Text('Recent Sessions')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .margin({ bottom: 16 })

        if (this.viewModel.sessions.length === 0) {
          Text('No sessions yet. Start a new chat!')
            .fontSize(14)
            .fontColor('#666666')
        } else {
          ForEach(this.viewModel.sessions.slice(0, 5), (session: SessionInfo) => {
            Row() {
              Column() {
                Text(session.title || 'Untitled Session')
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(new Date(session.updatedAt).toLocaleString())
                  .fontSize(12)
                  .fontColor('#666666')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .height(56)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#1A1A1A')
            .borderRadius(8)
            .margin({ bottom: 8 })
            .onClick(() => {
              this.viewModel.currentSessionId = session.id;
              this.currentView = AppView.Chat;
            })
          })
        }
      } else if (this.viewModel.connectionStatus === ConnectionStatus.AutoStarting) {
        // Auto-start in progress
        Column() {
          LoadingProgress()
            .width(48)
            .height(48)
            .color('#007DFF')
            .margin({ bottom: 16 })

          Text(this.viewModel.serverStatusMessage.length > 0
            ? this.viewModel.serverStatusMessage
            : '正在启动内置 Runtime...')
            .fontSize(16)
            .fontColor('#FFB300')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 8 })

          if (this.viewModel.serverLogs.length > 0) {
            Text(this.viewModel.serverLogs[this.viewModel.serverLogs.length - 1])
              .fontSize(12)
              .fontColor('#666666')
              .textAlign(TextAlign.Center)
              .maxLines(2)
          }
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.viewModel.connectionStatus === ConnectionStatus.StartFailed) {
        // Auto-start failed
        Column() {
          Text('Runtime 启动失败')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FF5252')
            .margin({ bottom: 12 })

          Text(this.viewModel.serverStatusMessage.length > 0
            ? this.viewModel.serverStatusMessage
            : '内置 Runtime 无法启动')
            .fontSize(14)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 8 })
            .padding({ left: 32, right: 32 })

          if (this.viewModel.serverLogs.length > 0) {
            Text(this.viewModel.serverLogs.slice(-3).join('\n'))
              .fontSize(11)
              .fontColor('#666666')
              .textAlign(TextAlign.Start)
              .padding(12)
              .backgroundColor('#1A1A1A')
              .borderRadius(8)
              .width('100%')
              .margin({ bottom: 16 })
          }

          Button('重新启动')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .width(200)
            .height(48)
            .backgroundColor('#007DFF')
            .borderRadius(8)
            .margin({ bottom: 12 })
            .onClick(() => {
              this.viewModel.autoStartAndConnect();
            })

          Button('手动连接')
            .fontSize(14)
            .width(200)
            .height(40)
            .backgroundColor('#2D2D2D')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .onClick(() => {
              this.showSettings = true;
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .padding(32)
      } else {
        // Connection prompt
        Button('启动并连接 Runtime')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .width(200)
          .height(48)
          .backgroundColor('#007DFF')
          .borderRadius(8)
          .margin({ top: 24 })
          .onClick(() => {
            this.viewModel.autoStartAndConnect();
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  @Builder
  ChatContent() {
    Column() {
      // Chat header
      Row() {
        Text(this.viewModel.currentSessionId.length > 0 ? 'Session' : 'New Chat')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
        Blank()
        Button('New Session')
          .fontSize(13)
          .height(32)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .onClick(() => {
            this.viewModel.currentSessionId = '';
          })
      }
      .width('100%')
      .height(Constants.TITLE_BAR_HEIGHT)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#2D2D2D').width('100%')

      // Message list
      List() {
        ForEach(this.viewModel.messages, (msg: ChatMessage) => {
          ListItem() {
            Row() {
              if (msg.role === 'assistant') {
                Column() {
                  Text('AI')
                    .fontSize(12)
                    .fontColor('#007DFF')
                    .margin({ bottom: 4 })
                  Text(msg.content)
                    .fontSize(14)
                    .fontColor('#E0E0E0')
                    .margin({ left: 0 })
                }
                .alignItems(HorizontalAlign.Start)
              } else {
                Blank()
                Column() {
                  Text(msg.content)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .textAlign(TextAlign.End)
                }
                .alignItems(HorizontalAlign.End)
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })

      Divider().color('#2D2D2D').width('100%')

      // Input area
      Row() {
        TextInput({ placeholder: 'Type a message...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#2D2D2D')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .placeholderColor('#666666')
          .onChange((value: string) => {
            this.inputText = value;
          })
          .onSubmit(() => {
            this.sendInput();
          })
        Button('Send')
          .height(40)
          .width(72)
          .backgroundColor('#007DFF')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .margin({ left: 8 })
          .onClick(() => {
            this.sendInput();
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }

  @State inputText: string = '';

  private sendInput(): void {
    if (this.inputText.length > 0) {
      this.viewModel.sendMessage(this.inputText);
      this.inputText = '';
    }
  }

  @Builder
  WebViewContent() {
    Column() {
      Text('Web View')
        .fontSize(18)
        .fontColor('#FFFFFF')
        .margin(16)
      Text('连接本地 OpenCode Runtime 后可继续使用')
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  TerminalContent() {
    Column() {
      Text('Terminal')
        .fontSize(18)
        .fontColor('#FFFFFF')
        .margin(16)
      Text('Terminal output will appear here')
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  FilesContent() {
    Column() {
      Text('Files')
        .fontSize(18)
        .fontColor('#FFFFFF')
        .margin(16)
      Text('File browser will appear here')
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ProviderContent() {
    Column() {
      Row() {
        Text('Providers')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Blank()

        Button('刷新')
          .fontSize(13)
          .height(32)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .onClick(() => {
            this.viewModel.loadProviders()
          })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#2D2D2D').width('100%')

      if (this.viewModel.connectionStatus !== ConnectionStatus.Connected) {
        Column() {
          Text('本地 Runtime 未连接')
            .fontSize(18)
            .fontColor('#FFFFFF')
            .margin({ bottom: 8 })

          Text('Provider 列表来自 OpenCode Runtime 的 /provider。请先连接本地 Runtime。')
            .fontSize(14)
            .fontColor('#888888')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 20 })

          Button('去连接 Runtime')
            .height(40)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .onClick(() => {
              this.showSettings = true
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.viewModel.providers.length === 0) {
        Column() {
          Text('没有从 Runtime 读取到 Provider')
            .fontSize(18)
            .fontColor('#FFFFFF')
            .margin({ bottom: 8 })

          Text('请确认 opencode 配置里已有 provider，或先在 Runtime 配置中添加自定义 Provider。')
            .fontSize(14)
            .fontColor('#888888')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 20 })

          Button('重新读取 Provider')
            .height(40)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .onClick(() => {
              this.viewModel.loadProviders()
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.viewModel.providers, (provider: ProviderInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(provider.name.length > 0 ? provider.name : provider.id)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#FFFFFF')

                    Text(provider.id)
                      .fontSize(12)
                      .fontColor('#888888')
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(provider.connected ? 'connected' : 'not connected')
                    .fontSize(12)
                    .fontColor(provider.connected ? '#3DDC84' : '#FFB020')
                }
                .width('100%')

                if (provider.models.length > 0) {
                  Flex({ wrap: FlexWrap.Wrap }) {
                    ForEach(provider.models, (modelId: string) => {
                      Button(modelId)
                        .fontSize(12)
                        .height(30)
                        .backgroundColor(this.viewModel.selectedModel === `${provider.id}/${modelId}` ? '#007DFF' : '#2D2D2D')
                        .fontColor('#FFFFFF')
                        .borderRadius(6)
                        .margin({ right: 8, top: 8 })
                        .onClick(() => {
                          this.viewModel.selectedModel = `${provider.id}/${modelId}`
                          this.viewModel.saveServerConfig()
                        })
                    })
                  }
                  .width('100%')
                  .margin({ top: 12 })
                } else {
                  Text('No models')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 12 })
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#1A1A1A')
              .borderRadius(10)
              .margin({ left: 16, right: 16, bottom: 12 })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ModelsContent() {
    Column() {
      Text('Models')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 24 })

      Text('Current Model')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ bottom: 8 })

      TextInput({ placeholder: 'providerId/modelId', text: this.viewModel.selectedModel })
        .width('100%')
        .height(40)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .onChange((value: string) => {
          this.viewModel.selectedModel = value
        })

      Button('保存模型')
        .height(40)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          this.viewModel.saveServerConfig()
        })

      Button('从 Provider 页面选择模型')
        .height(40)
        .backgroundColor('#2D2D2D')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ top: 12 })
        .onClick(() => {
          this.currentView = AppView.Provider
        })
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SettingsContent() {
    Column() {
      Text('Settings')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 24 })

      // Runtime URL
      Text('Runtime URL')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ bottom: 8 })
      TextInput({ placeholder: 'http://127.0.0.1:4096', text: this.viewModel.serverInfo.url })
        .width('100%')
        .height(40)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .onChange((value: string) => {
          this.viewModel.serverInfo.url = value;
        })

      // Username
      Text('Username')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ top: 16, bottom: 8 })
      TextInput({ placeholder: 'opencode', text: this.viewModel.serverInfo.username })
        .width('100%')
        .height(40)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .onChange((value: string) => {
          this.viewModel.serverInfo.username = value;
        })

      // Password
      Text('Password')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ top: 16, bottom: 8 })
      TextInput({ placeholder: 'password', text: this.viewModel.serverInfo.password })
        .width('100%')
        .height(40)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .type(InputType.Password)
        .onChange((value: string) => {
          this.viewModel.serverInfo.password = value;
        })

      // Model
      Text('Model')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ top: 16, bottom: 8 })
      TextInput({ placeholder: 'providerId/modelId，例如 xiaomi-mimo/mimo-v2.5-pro', text: this.viewModel.selectedModel })
        .width('100%')
        .height(40)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .onChange((value: string) => {
          this.viewModel.selectedModel = value;
        })

      Row() {
        Button('刷新 Provider')
          .height(36)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .onClick(() => {
            this.viewModel.loadProviders()
            this.currentView = AppView.Provider
            this.showSettings = false
          })

        Button('打开 Models')
          .height(36)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .margin({ left: 8 })
          .onClick(() => {
            this.currentView = AppView.Models
            this.showSettings = false
          })
      }
      .margin({ top: 8 })

      // Connect/Disconnect button
      Row() {
        if (this.viewModel.connectionStatus === ConnectionStatus.Connected) {
          Button('Disconnect')
            .width(120)
            .height(44)
            .backgroundColor('#FF5252')
            .borderRadius(8)
            .fontColor('#FFFFFF')
            .onClick(() => {
              this.viewModel.disconnect();
            })
        } else if (this.viewModel.connectionStatus === ConnectionStatus.AutoStarting) {
          Button('启动中...')
            .width(120)
            .height(44)
            .backgroundColor('#FFB300')
            .borderRadius(8)
            .fontColor('#FFFFFF')
            .enabled(false)
        } else {
          Button('Connect')
            .width(120)
            .height(44)
            .backgroundColor('#007DFF')
            .borderRadius(8)
            .fontColor('#FFFFFF')
            .enabled(this.viewModel.connectionStatus !== ConnectionStatus.Connecting)
            .onClick(() => {
              this.viewModel.saveServerConfig();
              this.viewModel.connect();
            })
        }

        Button('Save')
          .width(80)
          .height(44)
          .backgroundColor('#2D2D2D')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .margin({ left: 12 })
          .onClick(() => {
            this.viewModel.saveServerConfig();
          })
      }
      .margin({ top: 24 })

      // Built-in server control
      Row() {
        Text('内置 Runtime')
          .fontSize(14)
          .fontColor('#AAAAAA')
          .layoutWeight(1)

        Button(this.viewModel.connectionStatus === ConnectionStatus.AutoStarting ? '启动中...' : '启动内置 Runtime')
          .height(36)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .enabled(this.viewModel.connectionStatus !== ConnectionStatus.AutoStarting)
          .onClick(() => {
            this.viewModel.autoStartAndConnect();
          })

        Button('停止 Runtime')
          .height(36)
          .backgroundColor('#FF5252')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .margin({ left: 8 })
          .onClick(() => {
            this.viewModel.shutdown();
          })
      }
      .margin({ top: 12 })
      .width('100%')

      if (this.viewModel.errorMessage.length > 0) {
        Text(this.viewModel.errorMessage)
          .fontSize(13)
          .fontColor('#FF5252')
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .alignItems(HorizontalAlign.Start)
  }

  private getStatusColor(): ResourceColor {
    switch (this.viewModel.connectionStatus) {
      case ConnectionStatus.Connected:
        return '#00C853';
      case ConnectionStatus.AutoStarting:
      case ConnectionStatus.Connecting:
        return '#FFB300';
      case ConnectionStatus.StartFailed:
      case ConnectionStatus.Error:
        return '#FF5252';
      default:
        return '#666666';
    }
  }

  private getStatusText(): string {
    switch (this.viewModel.connectionStatus) {
      case ConnectionStatus.Connected:
        return 'Connected';
      case ConnectionStatus.AutoStarting:
        return 'Starting...';
      case ConnectionStatus.Connecting:
        return 'Connecting...';
      case ConnectionStatus.StartFailed:
        return 'Start Failed';
      case ConnectionStatus.Error:
        return 'Error';
      default:
        return 'Disconnected';
    }
  }
}
