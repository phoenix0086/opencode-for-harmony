import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { StorageService } from '../service/StorageService';
import { initStorageService } from '../services/StorageService';
import { localOpenCodeServerManager } from '../services/LocalOpenCodeServerManager';
import { ConnectionStatus, AppView, SessionInfo, ProviderInfo } from '../model/AppState';
import { ChatMessage } from '../model/ChatMessage';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger'
import { ProviderPage } from './ProviderPage';
import { OpenCodeHomeLaunch } from '../components/home/OpenCodeHomeLaunch';
import { RuntimePage } from './RuntimePage';
import { Runner } from '../models/Runner';
import { ProjectEntry } from '../components/DirectoryPicker';
import { DirectoryPicker } from '../components/DirectoryPicker';

/**
 * Main page of the OpenCode app.
 * Provides the primary navigation shell with a sidebar and content area.
 */
@Entry
@Component
struct Index {
  @State viewModel: MainViewModel = new MainViewModel();
  @State currentView: AppView = AppView.Home;
  @State sidebarCollapsed: boolean = false;
  @State showSettings: boolean = false;
  @State initialized: boolean = false;

  // ── OpenCodeHomeLaunch 相关状态 ──
  @State homeProjects: ProjectEntry[] = []
  @State showDirectoryPicker: boolean = false
  @State showServerStatusDialog: boolean = false
  @State showHelpDialog: boolean = false
  @State inputText: string = '';

  // ── Settings 页面状态 ──
  @State settingsTab: string = 'general'
  @State settingAutoAllow: boolean = false
  @State settingShowReasoning: boolean = false
  @State settingExpandShell: boolean = false
  @State settingExpandEditor: boolean = false
  @State settingShowProgress: boolean = true
  @State settingNewLayout: boolean = false
  @State settingNotifAgent: boolean = true
  @State settingNotifPermission: boolean = true
  @State settingNotifError: boolean = false
  @State settingUpdateCheck: boolean = false
  @State settingReleaseNotes: boolean = true
  @State settingPinchZoom: boolean = false
  @State settingFileTree: boolean = false
  @State settingNavControls: boolean = false
  @State settingCommandPalette: boolean = false
  @State settingServerStatus: boolean = false
  @State settingCustomAgents: boolean = false
  @State settingLanguage: string = '简体中文'
  @State settingShell: string = 'Auto (Default)'
  @State settingColorScheme: string = '系统'
  @State settingThemeName: string = 'OC-2'
  @State settingUiFont: string = 'System Sans'
  @State settingCodeFont: string = 'System Mono'
  @State settingTermFont: string = 'JetBrainsMono Nerd Font M'
  @State settingSoundAgent: string = '斯泰普博普斯 01'
  @State settingSoundPermission: string = '斯泰普博普斯 02'
  @State settingSoundError: string = '否 03'

  private context: common.UIAbilityContext = AppStorage.get<Context>('appContext') as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    if (!this.initialized) {
      // Initialize the services/ StorageService singleton (used by ProviderRegistry)
      await initStorageService(this.context);
      // Extract bundled opencode binary from rawfile to filesDir
      await localOpenCodeServerManager.init(this.context);
      const storage = new StorageService(this.context);
      await storage.init();
      await this.viewModel.init(storage);
      this.initialized = true;
      Logger.info('Index page initialized, starting auto-connect...');
      // 修复 W6: autoStartAndConnect 和 loadRecentProjects 互不依赖,
      // 改为 Promise.all 并行,首屏更流畅
      await Promise.all([
        this.viewModel.autoStartAndConnect(),
        this.loadRecentProjects()
      ])
    }
  }

  aboutToDisappear(): void {
    // 不要在页面消失时自动关闭 Runtime。
    // 页面切换、预览刷新、生命周期变化都可能触发 aboutToDisappear(),
    // 切到设置页或弹模态都会杀 Runtime,导致 Chat 残影和未连接状态。
    // Runtime 应该由用户明确点击"停止 Runtime"按钮,或应用真正退出时统一处理。
    Logger.info('Index page disappeared; Runtime kept alive (no shutdown)');
  }

  /**
   * 从 storage 加载最近项目列表 (与 opencode-dev 的 recentProjects 对齐)
   * 数据源: StorageService.recents key,JSON 数组 [{id,directory,lastOpened,worktree}]
   */
  async loadRecentProjects(): Promise<void> {
    try {
      const storage = new StorageService(this.context);
      await storage.init();
      const raw = await storage.getString('recents', '[]')
      const parsed = JSON.parse(raw) as Array<Record<string, Object>>
      const projects: ProjectEntry[] = []
      for (const item of parsed) {
        const p = new ProjectEntry()
        p.id = (item['id'] as string) ?? ''
        p.name = (item['name'] as string) ?? ''
        p.directory = (item['directory'] as string) ?? ''
        p.worktree = (item['worktree'] as string) ?? p.directory
        p.lastOpened = (item['lastOpened'] as string) ?? ''
        p.isActive = false
        projects.push(p)
      }
      // 注入当前工作区作为默认最近项目
      const currentDir = await storage.getString(Constants.KEY_WORKSPACE_PATH, '')
      if (currentDir.length > 0 && !projects.some(p => p.directory === currentDir)) {
        const p = new ProjectEntry()
        p.id = 'current'
        p.name = currentDir.split('/').pop() ?? currentDir
        p.directory = currentDir
        p.worktree = currentDir
        p.lastOpened = new Date().toISOString()
        p.isActive = true
        projects.unshift(p)
      }
      this.homeProjects = projects
    } catch (err) {
      Logger.warn(`loadRecentProjects: ${String(err)}`)
      this.homeProjects = []
    }
  }

  /**
   * 打开一个项目:记录到 recents + 切到 Chat 视图
   */
  async openProject(directory: string): Promise<void> {
    // 修复 W5: directory 为空时直接返回,避免写入空路径污染 storage
    if (directory.length === 0) {
      Logger.warn('openProject: empty directory, ignored')
      return
    }
    try {
      const storage = new StorageService(this.context);
      await storage.init();
      await storage.setString(Constants.KEY_WORKSPACE_PATH, directory)

      // 追加到 recents (去重,前置)
      // 修复 C3: JSON.parse 已加 try/catch,此处补 Array.isArray 防御性校验,
      // 防止 storage 数据损坏为非数组时崩溃
      const raw = await storage.getString('recents', '[]')
      let list: Array<Record<string, Object>> = []
      try { list = JSON.parse(raw) as Array<Record<string, Object>> } catch { list = [] }
      if (!Array.isArray(list)) {
        Logger.warn('openProject: recents is not an array, resetting')
        list = []
      }
      list = list.filter(x => (x['directory'] as string) !== directory)
      const entry: Record<string, Object> = {}
      entry['id'] = directory
      entry['name'] = directory.split('/').pop() ?? directory
      entry['directory'] = directory
      entry['worktree'] = directory
      entry['lastOpened'] = new Date().toISOString()
      list.unshift(entry)
      if (list.length > 10) list = list.slice(0, 10)
      await storage.setString('recents', JSON.stringify(list))

      await this.loadRecentProjects()
      this.currentView = AppView.Chat
    } catch (err) {
      Logger.error(`openProject failed: ${String(err)}`)
    }
  }

  /**
   * 新建 session + 切到 Chat
   */
  async newSessionAndOpenChat(): Promise<void> {
    const id = await this.viewModel.createSession()
    if (id.length > 0) {
      this.currentView = AppView.Chat
    } else {
      this.showSettings = true
    }
  }

  build() {
    // ── Home 全屏模式: 与 opencode-dev 的 LegacyHome 完全对齐 ──
    // 默认 currentView=Home 时直接显示 OpenCodeHomeLaunch,不带侧栏,
    // 真正的 "opencode 风格启动屏"。其它视图(Chat/Provider/...)走侧栏+内容。
    if (this.currentView === AppView.Home) {
      this.FullScreenHome()
    } else {
      this.SidebarLayout()
    }
  }

  @Builder
  FullScreenHome() {
    Stack() {
      OpenCodeHomeLaunch({
        activeRunner: null,
        sessions: this.viewModel.sessions,
        projectName: '',
        projectPath: '',
        branchName: '',
        modelName: this.viewModel.selectedModel,
        isConnected: this.viewModel.connectionStatus === ConnectionStatus.Connected,
        serverVersion: this.viewModel.serverInfo.url,
        projects: this.homeProjects,
        serverName: this.viewModel.serverInfo.displayName.length > 0 ? this.viewModel.serverInfo.displayName : 'Local Server',
        isServerReady: this.viewModel.connectionStatus === ConnectionStatus.Connected ||
                        this.viewModel.connectionStatus === ConnectionStatus.AutoStarting ||
                        this.viewModel.connectionStatus === ConnectionStatus.Connecting,
        onNewSession: () => {
          this.newSessionAndOpenChat()
        },
        onOpenChat: () => {
          this.currentView = AppView.Chat
        },
        onOpenSettings: () => {
          this.currentView = AppView.Settings
          this.showSettings = true
        },
        onOpenHelp: () => {
          this.showHelpDialog = true
        },
        onOpenDirectoryPicker: () => {
          this.showDirectoryPicker = true
        },
        onOpenServerStatus: () => {
          this.showServerStatusDialog = true
        },
        onOpenProject: (directory: string) => {
          this.openProject(directory)
        }
      })

      // ── DirectoryPicker 弹层 ──
      DirectoryPicker({
        visible: this.showDirectoryPicker,
        projects: this.homeProjects,
        currentDirectory: this.viewModel.serverInfo.url,
        onSelect: (directory: string) => {
          this.showDirectoryPicker = false
          this.openProject(directory)
        },
        onDismiss: () => {
          this.showDirectoryPicker = false
        }
      })

      // ── Server Status 弹层 ──
      if (this.showServerStatusDialog) {
        this.ServerStatusDialog()
      }

      // ── Help 弹层 ──
      if (this.showHelpDialog) {
        this.HelpDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0a0a0a')
    .onAppear(() => {
      // 进入 home 时刷新最近项目 (从 Chat 退回时也走这里)
      this.loadRecentProjects()
    })
  }

  @Builder
  SidebarLayout() {
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
            this.NavItem(AppView.Runtime, $r('app.media.server'), 'Runtime')
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
        } else if (this.currentView === AppView.Runtime) {
          this.RuntimeContent()
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
          }, (session: SessionInfo) => session.id)
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

  /**
   * Runtime 未连接 / 启动失败时显示的修复卡片 (Chat 页专用)
   * 给出明确原因 + 可操作按钮 + 错误日志
   */
  @Builder
  RuntimeDisconnectedCard() {
    Column() {
      Text(this.viewModel.connectionStatus === ConnectionStatus.StartFailed
        ? 'Runtime 启动失败'
        : this.viewModel.connectionStatus === ConnectionStatus.AutoStarting
          ? '正在启动 Runtime...'
          : 'Runtime 未连接')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 8 })

      Text(this.viewModel.serverStatusMessage.length > 0
        ? this.viewModel.serverStatusMessage
        : this.viewModel.errorMessage.length > 0
          ? this.viewModel.errorMessage
          : '本地 OpenCode Runtime 未连接，请先启动或手动连接。')
        .fontSize(14)
        .fontColor('#AAAAAA')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 16 })

      Row() {
        Button('打开设置')
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .fontSize(14)
          .onClick(() => {
            this.showSettings = true
          })

        Button('重新启动 / 连接')
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#007DFF')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .fontSize(14)
          .margin({ left: 8 })
          .onClick(() => {
            this.viewModel.autoStartAndConnect()
          })
      }
      .width('100%')

      if (this.viewModel.serverLogs.length > 0) {
        Column() {
          Text('启动日志')
            .fontSize(12)
            .fontColor('#888888')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 6 })
          Text(this.viewModel.serverLogs.slice(-12).join('\n'))
            .fontSize(11)
            .fontColor('#9E9E9E')
            .fontFamily('monospace')
            .maxLines(12)
            .textAlign(TextAlign.Start)
            .width('100%')
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#0F0F0F')
        .borderRadius(8)
        .margin({ top: 16 })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(24)
    .backgroundColor('#1A1A1A')
    .borderRadius(12)
    .margin({ left: 16, right: 16, top: 16, bottom: 16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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

      // Message list — 当 Runtime 未连接时改为显示"启动失败"修复卡片
      if (this.viewModel.connectionStatus !== ConnectionStatus.Connected) {
        this.RuntimeDisconnectedCard()
      } else {
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
          }, (msg: ChatMessage) => msg.id)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
      }

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

  private sendInput(): void {
    if (this.inputText.length === 0) return

    // 未连接时直接提示,不再悄悄调用 sendMessage 然后被 sendMessage 内部 push 一条 AI 错误消息
    if (this.viewModel.connectionStatus !== ConnectionStatus.Connected) {
      this.viewModel.errorMessage = '本地 Runtime 未连接。请先启动或连接 Runtime。'
      this.viewModel.serverStatusMessage = this.viewModel.errorMessage
      return
    }

    this.viewModel.sendMessage(this.inputText)
    this.inputText = ''
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
  RuntimeContent() {
    RuntimePage({
      activeRunner: null,
      isConnected: this.viewModel.connectionStatus === ConnectionStatus.Connected,
      serverUrl: this.viewModel.serverInfo.url,
      onRunnerActivated: (runner: Runner) => {
        this.viewModel.serverInfo.url = `${runner.protocol}://${runner.host}:${runner.port}`
        this.viewModel.connect()
      },
      onReconnect: () => {
        this.viewModel.connect()
      },
      onDiagnose: async () => {
        return await this.viewModel.diagnoseRuntime()
      }
    })
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
                          this.viewModel.syncModelToRuntime()
                        })
                    }, (modelId: string) => `${provider.id}/${modelId}`)
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
          }, (provider: ProviderInfo) => provider.id)
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
        .onClick(async () => {
          await this.viewModel.saveServerConfig()
          await this.viewModel.syncModelToRuntime()
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
    Row() {
      // ── Settings sidebar ──
      Column() {
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 16 })

        this.SettingNavItem('桌面', 'desktop')
        this.SettingNavItem('通用', 'general')
        this.SettingNavItem('快捷键', 'shortcuts')
        this.SettingNavItem('服务器', 'servers')
        this.SettingNavItem('提供商', 'providers')
        this.SettingNavItem('模型', 'models')

        Blank()

        Text('OpenCode Desktop v1.16.2')
          .fontSize(11)
          .fontColor('#555555')
          .padding({ left: 20, bottom: 16 })
      }
      .width(180)
      .height('100%')
      .backgroundColor('#1A1A1A')

      // ── Settings content ──
      Scroll() {
        Column() {
          if (this.settingsTab === 'general') {
            this.SettingsGeneralContent()
          } else if (this.settingsTab === 'desktop') {
            this.SettingsDesktopContent()
          } else if (this.settingsTab === 'shortcuts') {
            this.SettingsShortcutsContent()
          } else if (this.settingsTab === 'servers') {
            this.SettingsServerContent()
          } else if (this.settingsTab === 'providers') {
            this.SettingsProvidersNav()
          } else if (this.settingsTab === 'models') {
            this.SettingsModelsNav()
          }
        }
        .padding({ left: 32, right: 32, top: 24, bottom: 40 })
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingNavItem(label: string, tab: string) {
    Text(label)
      .fontSize(14)
      .fontColor(this.settingsTab === tab ? '#FFFFFF' : '#888888')
      .fontWeight(this.settingsTab === tab ? FontWeight.Medium : FontWeight.Normal)
      .width('100%')
      .padding({ left: 20, right: 12, top: 10, bottom: 10 })
      .backgroundColor(this.settingsTab === tab ? '#2A2A2A' : Color.Transparent)
      .borderRadius(6)
      .margin({ left: 8, right: 8, top: 1, bottom: 1 })
      .onClick(() => {
        this.settingsTab = tab
      })
  }

  // ── Settings section header ──
  @Builder
  SSection(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .width('100%')
      .margin({ top: 28, bottom: 12 })
  }

  // ── Toggle row ──
  @Builder
  SToggle(title: string, desc: string, isOn: boolean, onToggle: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#007DFF')
        .onChange((isOn: boolean) => {
          onToggle()
        })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  // ── Select row (dropdown-style) ──
  @Builder
  SSelect(title: string, desc: string, value: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(value)
          .fontSize(13)
          .fontColor('#AAAAAA')
        Text(' ▾')
          .fontSize(12)
          .fontColor('#666666')
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor('#2D2D2D')
      .borderRadius(6)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  // ── Font select row ──
  @Builder
  SFontSelect(title: string, desc: string, value: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(value)
        .fontSize(13)
        .fontColor('#AAAAAA')
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor('#2D2D2D')
        .borderRadius(6)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  // ── Notification toggle row ──
  @Builder
  SNotifRow(title: string, desc: string, isOn: boolean, onToggle: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor('#007DFF')
        .onChange((isOn: boolean) => {
          onToggle()
        })
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  // ── Sound select row ──
  @Builder
  SSoundRow(title: string, desc: string, value: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text(desc)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(value)
          .fontSize(13)
          .fontColor('#AAAAAA')
        Text(' ▾')
          .fontSize(12)
          .fontColor('#666666')
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .backgroundColor('#2D2D2D')
      .borderRadius(6)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
  }

  // ══════════════════════════════════════════════════════════
  //  通用 (General) Tab — 完整复刻 OpenCode Desktop 设置
  // ══════════════════════════════════════════════════════════

  @Builder
  SettingsGeneralContent() {
    // ── 语言与权限 ──
    Text('通用')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 20 })

    this.SSelect('语言', '更改 OpenCode 的显示语言', this.settingLanguage)
    Divider().color('#222222')
    this.SToggle('自动接受权限', '权限请求将被自动批准', this.settingAutoAllow, () => {
      this.settingAutoAllow = !this.settingAutoAllow
    })
    Divider().color('#222222')
    this.SSelect('Terminal Shell', 'Choose the shell used for your terminal. Compatible shells are also used for agent tool calls.', this.settingShell)

    // ── 时间线显示偏好 ──
    this.SSection('时间线')
    this.SToggle('显示推理摘要', '在时间线中显示模型推理摘要', this.settingShowReasoning, () => {
      this.settingShowReasoning = !this.settingShowReasoning
    })
    Divider().color('#222222')
    this.SToggle('展开 shell 工具部分', '默认在时间线中展开 shell 工具部分', this.settingExpandShell, () => {
      this.settingExpandShell = !this.settingExpandShell
    })
    Divider().color('#222222')
    this.SToggle('展开编辑工具部分', '默认在时间线中展开 edit、write 和 patch 工具部分', this.settingExpandEditor, () => {
      this.settingExpandEditor = !this.settingExpandEditor
    })

    // ── 会话 ──
    this.SSection('会话')
    this.SToggle('显示会话进度条', '当智能体正在工作时，在会话顶部显示动画进度条', this.settingShowProgress, () => {
      this.settingShowProgress = !this.settingShowProgress
    })

    // ── 布局 ──
    this.SSection('布局')
    this.SToggle('New layout and designs', 'Enable the redesigned layout, home, composer, and session UI', this.settingNewLayout, () => {
      this.settingNewLayout = !this.settingNewLayout
    })

    // ── 外观 ──
    this.SSection('外观')
    this.SSelect('配色方案', '选择 OpenCode 跟随系统、浅色或深色主题', this.settingColorScheme)
    Divider().color('#222222')
    this.SSelect('主题', '自定义 OpenCode 的主题。了解更多', this.settingThemeName)
    Divider().color('#222222')
    this.SFontSelect('界面字体', '自定义整个界面使用的字体', this.settingUiFont)
    Divider().color('#222222')
    this.SFontSelect('代码字体', '自定义代码块使用的字体', this.settingCodeFont)
    Divider().color('#222222')
    this.SFontSelect('Terminal Font', 'Customise the font used in the terminal', this.settingTermFont)

    // ── 系统通知 ──
    this.SSection('系统通知')
    this.SNotifRow('智能体', '当智能体完成或需要注意时显示系统通知', this.settingNotifAgent, () => {
      this.settingNotifAgent = !this.settingNotifAgent
    })
    Divider().color('#222222')
    this.SNotifRow('权限', '当需要权限时显示系统通知', this.settingNotifPermission, () => {
      this.settingNotifPermission = !this.settingNotifPermission
    })
    Divider().color('#222222')
    this.SNotifRow('错误', '发生错误时显示系统通知', this.settingNotifError, () => {
      this.settingNotifError = !this.settingNotifError
    })

    // ── 音效 ──
    this.SSection('音效')
    this.SSoundRow('智能体', '当智能体完成或需要注意时播放声音', this.settingSoundAgent)
    Divider().color('#222222')
    this.SSoundRow('权限', '当需要权限时播放声音', this.settingSoundPermission)
    Divider().color('#222222')
    this.SSoundRow('错误', '发生错误时播放声音', this.settingSoundError)

    // ── 更新 ──
    this.SSection('更新')
    this.SToggle('启动时检查更新', '在 OpenCode 启动时自动检查更新', this.settingUpdateCheck, () => {
      this.settingUpdateCheck = !this.settingUpdateCheck
    })
    Divider().color('#222222')
    this.SToggle('发行说明', "更新后显示'新功能'弹窗", this.settingReleaseNotes, () => {
      this.settingReleaseNotes = !this.settingReleaseNotes
    })
    Divider().color('#222222')
    Row() {
      Column() {
        Text('检查更新')
          .fontSize(14)
          .fontColor('#E0E0E0')
        Text('手动检查更新并在有更新时安装')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('立即检查')
        .fontSize(13)
        .height(32)
        .backgroundColor('#2D2D2D')
        .fontColor('#FFFFFF')
        .borderRadius(6)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })

    // ── 显示 ──
    this.SSection('显示')
    this.SToggle('Pinch to zoom', 'Allow trackpad pinch and Ctrl-scroll gestures to zoom', this.settingPinchZoom, () => {
      this.settingPinchZoom = !this.settingPinchZoom
    })

    // ── Advanced ──
    this.SSection('Advanced')
    this.SToggle('File tree', 'Show the file tree panel in desktop sessions', this.settingFileTree, () => {
      this.settingFileTree = !this.settingFileTree
    })
    Divider().color('#222222')
    this.SToggle('Navigation controls', 'Show the back and forward buttons in the desktop title bar', this.settingNavControls, () => {
      this.settingNavControls = !this.settingNavControls
    })
    Divider().color('#222222')
    this.SToggle('Command palette', 'Show the search and command palette button in the desktop title bar', this.settingCommandPalette, () => {
      this.settingCommandPalette = !this.settingCommandPalette
    })
    Divider().color('#222222')
    this.SToggle('Server status', 'Show the server status button in the desktop title bar', this.settingServerStatus, () => {
      this.settingServerStatus = !this.settingServerStatus
    })
    Divider().color('#222222')
    this.SToggle('Custom agents', 'Show the agent picker in the v2 desktop composer', this.settingCustomAgents, () => {
      this.settingCustomAgents = !this.settingCustomAgents
    })
  }

  // ══════════════════════════════════════════════════════════
  //  桌面 (Desktop) Tab
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsDesktopContent() {
    Text('桌面')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 20 })

    Text('桌面端专属设置')
      .fontSize(14)
      .fontColor('#888888')
      .margin({ bottom: 16 })

    this.SToggle('启动时打开窗口', '应用启动时自动打开主窗口', true, () => {})
    Divider().color('#222222')
    this.SToggle('最小化到系统托盘', '关闭窗口时最小化到系统托盘而非退出', false, () => {})
  }

  // ══════════════════════════════════════════════════════════
  //  快捷键 (Shortcuts) Tab
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsShortcutsContent() {
    Text('快捷键')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 20 })

    this.ShortcutRow('发送消息', 'Shift + Enter')
    Divider().color('#222222')
    this.ShortcutRow('新建会话', 'Ctrl + N')
    Divider().color('#222222')
    this.ShortcutRow('切换标签', 'Ctrl + Tab')
    Divider().color('#222222')
    this.ShortcutRow('中止执行', 'Escape')
    Divider().color('#222222')
    this.ShortcutRow('切换侧边栏', 'Ctrl + B')
    Divider().color('#222222')
    this.ShortcutRow('打开设置', 'Ctrl + ,')
    Divider().color('#222222')
    this.ShortcutRow('命令面板', 'Ctrl + Shift + P')
    Divider().color('#222222')
    this.ShortcutRow('搜索', 'Ctrl + F')
  }

  @Builder
  ShortcutRow(action: string, keys: string) {
    Row() {
      Text(action)
        .fontSize(14)
        .fontColor('#E0E0E0')
        .layoutWeight(1)
      Text(keys)
        .fontSize(12)
        .fontColor('#AAAAAA')
        .fontFamily('monospace')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor('#2D2D2D')
        .borderRadius(4)
        .borderWidth(1)
        .borderColor('#3D3D3D')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  // ══════════════════════════════════════════════════════════
  //  服务器 (Servers) Tab — 保留原有连接配置
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsServerContent() {
    Text('服务器')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 20 })

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

    // ── 连接状态 ──
    Row() {
      Circle()
        .width(10)
        .height(10)
        .fill(this.getStatusColor())
      Text(this.getStatusText())
        .fontSize(14)
        .fontColor('#AAAAAA')
        .margin({ left: 8 })
    }
    .margin({ top: 20 })

    // ── 操作按钮 ──
    Row() {
      if (this.viewModel.connectionStatus === ConnectionStatus.Connected) {
        Button('断开连接')
          .height(40)
          .layoutWeight(1)
          .backgroundColor('#FF5252')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .onClick(() => {
            this.viewModel.disconnect();
          })
      } else {
        Button('连接')
          .height(40)
          .layoutWeight(1)
          .backgroundColor('#007DFF')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .enabled(this.viewModel.connectionStatus !== ConnectionStatus.Connecting)
          .onClick(() => {
            this.viewModel.saveServerConfig();
            this.viewModel.connect();
          })
      }

      Button('保存')
        .height(40)
        .width(80)
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
        .fontColor('#FFFFFF')
        .margin({ left: 12 })
        .onClick(() => {
          this.viewModel.saveServerConfig();
        })
    }
    .width('100%')
    .margin({ top: 20 })

    // ── 内置 Runtime 控制 ──
    this.SSection('内置 Runtime')
    Row() {
      Button(this.viewModel.connectionStatus === ConnectionStatus.AutoStarting ? '启动中...' : '启动内置 Runtime')
        .height(36)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .borderRadius(6)
        .layoutWeight(1)
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
        .layoutWeight(1)
        .onClick(() => {
          this.viewModel.shutdown();
        })
    }
    .width('100%')
    .margin({ top: 8 })

    if (this.viewModel.errorMessage.length > 0) {
      Text(this.viewModel.errorMessage)
        .fontSize(13)
        .fontColor('#FF5252')
        .margin({ top: 16 })
    }
  }

  // ══════════════════════════════════════════════════════════
  //  提供商 (Providers) — 导航到 ProviderPage
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsProvidersNav() {
    Text('提供商')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 12 })

    Text('管理 AI 模型提供商的配置、API 密钥和可用模型。')
      .fontSize(14)
      .fontColor('#888888')
      .margin({ bottom: 20 })

    Button('打开提供商管理页面')
      .height(44)
      .backgroundColor('#007DFF')
      .fontColor('#FFFFFF')
      .borderRadius(8)
      .onClick(() => {
        this.currentView = AppView.Provider
        this.showSettings = false
      })
  }

  // ══════════════════════════════════════════════════════════
  //  模型 (Models) — 导航到 Models
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsModelsNav() {
    Text('模型')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 12 })

    Text('当前模型')
      .fontSize(14)
      .fontColor('#AAAAAA')
      .margin({ bottom: 8 })

    TextInput({ placeholder: 'providerId/modelId', text: this.viewModel.selectedModel })
      .width('100%')
      .height(40)
      .backgroundColor('#2D2D2D')
      .borderRadius(8)
      .fontColor('#FFFFFF')
      .margin({ bottom: 16 })
      .onChange((value: string) => {
        this.viewModel.selectedModel = value
      })

    Button('保存模型')
      .height(40)
      .backgroundColor('#007DFF')
      .fontColor('#FFFFFF')
      .borderRadius(8)
      .onClick(() => {
        this.viewModel.saveServerConfig()
      })
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

  // ─────────────────────────────────────────────────────────
  // Home 弹层: Server Status (与 opencode 右上 server 按钮对应)
  // ─────────────────────────────────────────────────────────

  @Builder
  ServerStatusDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000099')
        .onClick(() => {
          this.showServerStatusDialog = false
        })

      Column() {
        Text('SERVER')
          .fontSize(12)
          .fontColor('#8a8a8a')
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .margin({ bottom: 12 })

        Text(this.viewModel.serverInfo.url.length > 0 ? this.viewModel.serverInfo.url : '未配置')
          .fontSize(13)
          .fontColor('#e8e2dd')
          .fontFamily('monospace')
          .width('100%')

        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(this.getStatusColor())
          Text(this.getStatusText())
            .fontSize(12)
            .fontColor('#a8a8a8')
            .fontFamily('monospace')
            .margin({ left: 8 })
        }
        .margin({ top: 16 })

        if (this.viewModel.serverStatusMessage.length > 0) {
          Text(this.viewModel.serverStatusMessage)
            .fontSize(12)
            .fontColor('#7a7a7a')
            .fontFamily('monospace')
            .margin({ top: 8 })
        }

        Row() {
          Button('关闭')
            .fontSize(13)
            .height(32)
            .backgroundColor('#1f1f1f')
            .fontColor('#cfcfcf')
            .borderRadius(6)
            .layoutWeight(1)
            .onClick(() => {
              this.showServerStatusDialog = false
            })

          Button('重新连接')
            .fontSize(13)
            .height(32)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .borderRadius(6)
            .layoutWeight(1)
            .margin({ left: 8 })
            .onClick(() => {
              this.showServerStatusDialog = false
              this.viewModel.connect()
            })
        }
        .margin({ top: 20 })
        .width('100%')
      }
      .width(360)
      .padding(24)
      .backgroundColor('#181818')
      .borderRadius(10)
      .borderWidth(1)
      .borderColor('#2d2d2d')
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  // ─────────────────────────────────────────────────────────
  // Home 弹层: Help (与 opencode 左下 ? 按钮对应)
  // ─────────────────────────────────────────────────────────

  @Builder
  HelpDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000099')
        .onClick(() => {
          this.showHelpDialog = false
        })

      Column() {
        Text('快捷键 / 帮助')
          .fontSize(16)
          .fontColor('#e8e2dd')
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ bottom: 16 })

        this.HelpRow('新建会话', '点击左 + 按钮')
        this.HelpRow('打开项目', '点击 "打开项目" 或搜索目录')
        this.HelpRow('切换会话', '左栏 SessionSidebar')
        this.HelpRow('设置', '点击左下 ⚙ 按钮')
        this.HelpRow('查看文档', 'docs/harmony-native/api-mapping.md')

        Button('关闭')
          .fontSize(13)
          .height(32)
          .backgroundColor('#1f1f1f')
          .fontColor('#cfcfcf')
          .borderRadius(6)
          .margin({ top: 20 })
          .width('100%')
          .onClick(() => {
            this.showHelpDialog = false
          })
      }
      .width(400)
      .padding(24)
      .backgroundColor('#181818')
      .borderRadius(10)
      .borderWidth(1)
      .borderColor('#2d2d2d')
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Center)
  }

  @Builder
  HelpRow(label: string, desc: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#e8e2dd')
        .fontWeight(FontWeight.Medium)
        .width(96)

      Text(desc)
        .fontSize(12)
        .fontColor('#a8a8a8')
        .layoutWeight(1)
    }
    .width('100%')
    .height(28)
    .alignItems(VerticalAlign.Center)
  }
}
