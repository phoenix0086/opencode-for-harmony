import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { MainViewModel, PendingPermission, PendingQuestion, QuestionOption } from '../viewmodel/MainViewModel';
import { storageService as storageSingleton, initStorageService } from '../services/StorageService';
import { errStr } from '../utils/ErrorUtil';
import { localOpenCodeServerManager } from '../services/LocalOpenCodeServerManager';
import { localRuntimeService } from '../services/LocalRuntimeService';
import { ProcessBridge } from '../services/ProcessBridge';
import { ConnectionStatus, AppView, SessionInfo, ProviderInfo } from '../model/AppState';
import { ChatMessage, ToolCall } from '../model/ChatMessage';
import { Constants } from '../utils/Constants';
import { Logger } from '../utils/Logger'
import { ProviderPage } from './ProviderPage';
import { OpenCodeHomeLaunch } from '../components/home/OpenCodeHomeLaunch';
import { RuntimePage } from './RuntimePage';
import { Runner } from '../models/Runner';
import { ProjectEntry } from '../components/DirectoryPicker';
import { DirectoryPicker } from '../components/DirectoryPicker';
import { ProviderConnectDialog } from '../components/provider/ProviderConnectDialog';
import { providerConnectionService, ProviderConnectInput, ProviderModelInput } from '../services/ProviderConnectionService';
import { providerRegistry } from '../services/ProviderRegistry';

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
  // PR 3:权限 Tab
  @State permissionFileRead: boolean = true
  @State permissionFileWrite: boolean = true
  @State permissionShell: boolean = true
  @State permissionAutoAccept: boolean = false
  // PR 3:高级 Tab
  @State developerMode: boolean = false
  // M21: server mode for StatusPopover
  @State serverMode: string = 'unknown'
  // Runtime 连接模式: dev-pc | local | remote
  @State runtimeConnectionMode: string = 'dev-pc'
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
  @State settingsModelSearch: string = ''

  // ── Provider dialog 状态 ──
  @State showProviderDialog: boolean = false
  @State editingProviderId: string = ''
  @State providerDialogPrefill: ProviderConnectInput | null = null
  @State providerDialogSubmitting: boolean = false

  private context: common.UIAbilityContext = AppStorage.get<Context>('appContext') as common.UIAbilityContext;

  async aboutToAppear(): Promise<void> {
    if (!this.initialized) {
      // Initialize the services/ StorageService singleton (used by ProviderRegistry)
      await initStorageService(this.context);
      // Extract bundled opencode binary from rawfile to filesDir
      await localOpenCodeServerManager.init(this.context);
      // Load saved runtime connection mode (dev-pc / local / remote)
      let autoFallbackDone = false
      try {
        const savedCfg = await localOpenCodeServerManager.loadLastConfig()
        // Auto-fallback: local mode requires native bridge
        if (savedCfg.mode === 'local' && !ProcessBridge.isAvailable) {
          this.runtimeConnectionMode = 'dev-pc'
          savedCfg.mode = 'dev-pc'
          await localOpenCodeServerManager.saveLastConfig(savedCfg)
          autoFallbackDone = true
          Logger.info('Auto-switched to dev-pc: native bridge unavailable')
        } else {
          this.runtimeConnectionMode = savedCfg.mode
        }
        Logger.info(`Runtime connection mode: ${this.runtimeConnectionMode}`)
      } catch (e) {
        Logger.warn(`Failed to load runtime connection mode: ${errStr(e)}`)
      }
      // C1 fix: 之前是 new StorageService(...) + storage.init() 创建第二个实例,
      // 跟 storageSingleton 各持一份 preferences.Preferences in-memory 缓存,
      // 一边 put 一边 get 容易读到旧值。现在统一用 storageSingleton (initStorageService 已初始化)。
      await this.viewModel.init(storageSingleton);

      // After init: fix URL to match current mode (especially after auto-fallback)
      if (autoFallbackDone) {
        const cfg = await localOpenCodeServerManager.loadLastConfig()
        this.viewModel.serverInfo.url = `http://${cfg.host}:${cfg.port}`
        Logger.info(`URL auto-updated to: ${this.viewModel.serverInfo.url}`)
      }

      this.initialized = true;
      Logger.info('Index page initialized, starting auto-connect...');
      // 修复 W6: autoStartAndConnect 和 loadRecentProjects 互不依赖,
      // 改为 Promise.allSettled 并行,首屏更流畅。
      // 使用 allSettled 而非 all，确保一个失败不影响另一个完成。
      await Promise.allSettled([
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
      const raw = await storageSingleton.getRecentWorkspaces()
      const projects: ProjectEntry[] = []
      for (const dir of raw) {
        const p = new ProjectEntry()
        p.id = dir
        p.name = dir.split('/').pop() ?? dir
        p.directory = dir
        p.worktree = dir
        p.lastOpened = ''
        p.isActive = false
        projects.push(p)
      }
      // 注入当前工作区作为默认最近项目
      const currentDir = await storageSingleton.getWorkspacePath()
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
      Logger.warn(`loadRecentProjects: ${errStr(err)}`)
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
      await storageSingleton.saveWorkspacePath(directory)
      await storageSingleton.addRecentWorkspace(directory)

      await this.loadRecentProjects()
      this.currentView = AppView.Chat
    } catch (err) {
      Logger.error(`openProject failed: ${errStr(err)}`)
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
    Stack() {
      // ── Home 全屏模式: 与 opencode-dev 的 LegacyHome 完全对齐 ──
      // 默认 currentView=Home 时直接显示 OpenCodeHomeLaunch,不带侧栏,
      // 真正的 "opencode 风格启动屏"。其它视图(Chat/Provider/...)走侧栏+内容。
      if (this.currentView === AppView.Home) {
        this.FullScreenHome()
      } else {
        this.SidebarLayout()
      }

      if (this.showSettings) {
        this.SettingsModal()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingsSectionTitle(title: string) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ top: 22, bottom: 8 })
  }

  @Builder
  SettingsRowText(title: string, desc: string, value: string) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#FFFFFF')
        Text(desc).fontSize(12).fontColor('#FFFFFF').margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(value)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
    }
    .height(64)
    .borderColor('#252525')
    .borderWidth({ bottom: 1 })
  }

  @Builder
  SettingsRowSwitch(title: string, desc: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#FFFFFF')
        Text(desc).fontSize(12).fontColor('#FFFFFF').margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange(onChange)
    }
    .height(64)
    .borderColor('#252525')
    .borderWidth({ bottom: 1 })
  }

  @Builder
  AdvancedEntry(title: string, desc: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title).fontSize(15).fontColor('#FFFFFF')
        Text(desc).fontSize(12).fontColor('#FFFFFF').margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('打开')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor('#2D2D2D')
        .borderRadius(8)
    }
    .height(68)
    .onClick(onClick)
    .borderColor('#252525')
    .borderWidth({ bottom: 1 })
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
                        this.viewModel.connectionStatus === ConnectionStatus.Connecting ||
                        this.viewModel.connectionStatus === ConnectionStatus.StartFailed,
        onNewSession: () => {
          this.newSessionAndOpenChat()
        },
        onOpenChat: () => {
          this.currentView = AppView.Chat
        },
        onOpenSettings: () => {
          this.showSettings = !this.showSettings
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

      // ── Settings 全屏覆盖 (从 Home 齿轮按钮进入) ──
      if (this.showSettings) {
        Column() {
          Row() {
            Text('← 返回')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .padding({ left: 16, top: 12, bottom: 12 })
              .onClick(() => {
                this.showSettings = false
              })
          }
          .width('100%')
          .height(44)
          .backgroundColor('#1A1A1A')

          this.SettingsContent()
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#111111')
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

          // Nav items — 菜单收口,只保留 4 个一级入口
          // Chat / Projects (Files) / AI 配置 (Models) / Settings
          // Home / Provider / Runtime / WebView / Terminal 不再作为一级路由:
          //   - Home 仍是启动页(currentView 默认值,走 FullScreenHome)
          //   - Provider 配置在 PR 2 抽到 AiConfigPage
          //   - Runtime/WebView/Terminal 在 PR 3 移到 Settings → Advanced
          Column() {
            this.NavItem(AppView.Chat, $r('app.media.chat'), 'Chat')
            this.NavItem(AppView.Files, $r('app.media.home'), 'Projects')
            this.NavItem(AppView.Models, $r('app.media.settings'), 'AI 配置')
            this.NavItem(AppView.Settings, $r('app.media.settings'), 'Settings')
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
              .fontColor('#FFFFFF')
              .margin({ left: 8 })
          }
          .width('100%')
          .height(40)
          .padding({ left: 16, right: 16 })
          .alignItems(VerticalAlign.Center)

          // Settings button
          Button() {
            Row() {
              Text('⚙️').fontSize(16)
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
          // 兼容 FullScreenHome 齿轮按钮触发的 overlay 形态
          this.SettingsContent()
        } else if (this.currentView === AppView.Home) {
          this.HomeContent()
        } else if (this.currentView === AppView.Chat) {
          this.ChatContent()
        } else if (this.currentView === AppView.Files) {
          this.FilesContent()
        } else if (this.currentView === AppView.Models) {
          // PR 2:AI 配置页独立为 AiConfigPage,两个 Tab(模型选择 / 供应商配置)
          AiConfigPage()
        } else if (this.currentView === AppView.Settings) {
          // 菜单收口后,Settings 走 NavItem → 路由,不再走 overlay
          this.SettingsContent()
        } else if (this.currentView === AppView.Provider) {
          // 菜单已隐藏 Provider,保留路由入口以便深链接 / 后续 PR 4 清理
          ProviderPage({ activeRunner: null })
        } else if (this.currentView === AppView.WebView) {
          this.WebViewContent()
        } else if (this.currentView === AppView.Terminal) {
          this.TerminalContent()
        } else if (this.currentView === AppView.Runtime) {
          this.RuntimeContent()
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
          .fontColor(['#FFFFFF'])
        Text(label)
          .fontSize(14)
          .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
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
                  .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 8 })

          if (this.viewModel.serverLogs.length > 0) {
            Text(this.viewModel.serverLogs[this.viewModel.serverLogs.length - 1])
              .fontSize(12)
              .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
            .margin({ bottom: 12 })

          Text(this.viewModel.serverStatusMessage.length > 0
            ? this.viewModel.serverStatusMessage
            : '内置 Runtime 无法启动')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .margin({ bottom: 8 })
            .padding({ left: 32, right: 32 })

          if (this.viewModel.serverLogs.length > 0) {
            Text(this.viewModel.serverLogs.slice(-3).join('\n'))
              .fontSize(11)
              .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 6 })
          Text(this.viewModel.serverLogs.slice(-12).join('\n'))
            .fontSize(11)
            .fontColor('#FFFFFF')
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
        Text(this.viewModel.currentSessionId.length > 0 ? `Session ${this.viewModel.serverMode}` : 'New Chat')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
        Blank()
        if (this.viewModel.isGenerating) {
          Button('Stop')
            .fontSize(13)
            .height(32)
            .backgroundColor('#FF5252')
            .fontColor('#FFFFFF')
            .borderRadius(6)
            .onClick(() => { this.viewModel.stopGeneration() })
        }
        Button('New Session')
          .fontSize(13)
          .height(32)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .margin({ left: 8 })
          .onClick(() => { this.viewModel.currentSessionId = '' })
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
              Column() {
                if (msg.isError) {
                // Error message
                Column() {
                  Text('Error')
                    .fontSize(12)
                    .fontColor('#FFFFFF')
                    .fontWeight(FontWeight.Bold)
                    .margin({ bottom: 4 })
                  Text(msg.content)
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                    .fontFamily('monospace')
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#1A0000')
                .borderRadius(8)
                .borderWidth(1)
                .borderColor('#FF525240')
                .margin({ left: 16, right: 16, top: 4, bottom: 4 })
              } else if (msg.role === 'assistant') {
                // Assistant message
                Row() {
                  Column() {
                    Row() {
                      Text('AI')
                        .fontSize(12)
                        .fontColor('#FFFFFF')
                        .margin({ bottom: 4 })
                      if (msg.isStreaming) {
                        Text(' (streaming...)')
                          .fontSize(11)
                          .fontColor('#FFFFFF')
                          .margin({ bottom: 4, left: 4 })
                      }
                    }
                    // Tool calls
                    if (msg.toolCalls.length > 0) {
                      ForEach(msg.toolCalls, (tool: ToolCall) => {
                        Row() {
                          Text(tool.name)
                            .fontSize(12)
                            .fontColor('#FFFFFF')
                            .fontFamily('monospace')
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .backgroundColor('#007DFF15')
                            .borderRadius(4)
                          if (tool.status === 'error') {
                            Text('error')
                              .fontSize(11)
                              .fontColor('#FFFFFF')
                              .margin({ left: 6 })
                          } else if (tool.status === 'complete') {
                            Text('done')
                              .fontSize(11)
                              .fontColor('#FFFFFF')
                              .margin({ left: 6 })
                          }
                        }
                        .margin({ bottom: 4 })
                      }, (tool: ToolCall) => tool.id)
                    }
                    if (msg.content.length > 0) {
                      Text(msg.content)
                        .fontSize(14)
                        .fontColor('#FFFFFF')
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              } else if (msg.role === 'system') {
                // System message
                Text(msg.content)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .fontStyle(FontStyle.Italic)
                  .textAlign(TextAlign.Center)
                  .width('100%')
                  .padding({ left: 32, right: 32, top: 4, bottom: 4 })
              } else {
                // User message
                Blank()
                Column() {
                  Text(msg.content)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .textAlign(TextAlign.End)
                }
                .alignItems(HorizontalAlign.End)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
              }
              } // Column
            } // ListItem
          }, (msg: ChatMessage) => msg.id)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
      }

      // Permission dock — show pending permission requests
      if (this.viewModel.pendingPermissions.length > 0) {
        Column() {
          ForEach(this.viewModel.pendingPermissions, (perm: PendingPermission) => {
            Column() {
              Row() {
                Text('🔒 权限请求')
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
                Blank()
                Text(perm.riskLevel.length > 0 ? perm.riskLevel : 'permission')
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .fontFamily('monospace')
              }
              .width('100%')
              .margin({ bottom: 6 })

              Text(perm.title)
                .fontSize(14)
                .fontColor('#FFFFFF')
                .width('100%')
                .margin({ bottom: 4 })

              if (perm.description.length > 0) {
                Text(perm.description)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .width('100%')
                  .margin({ bottom: 8 })
              }

              Row() {
                Button('允许')
                  .fontSize(13)
                  .height(32)
                  .backgroundColor('#3DDC84')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .onClick(() => { this.viewModel.approvePermission(perm.id, false) })

                Button('永久允许')
                  .fontSize(13)
                  .height(32)
                  .backgroundColor('#2D2D2D')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .margin({ left: 8 })
                  .onClick(() => { this.viewModel.approvePermission(perm.id, true) })

                Button('拒绝')
                  .fontSize(13)
                  .height(32)
                  .backgroundColor('#FF5252')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .margin({ left: 8 })
                  .onClick(() => { this.viewModel.rejectPermission(perm.id) })
              }
              .width('100%')
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#1A1A00')
            .borderRadius(8)
            .borderWidth(1)
            .borderColor('#FFB30040')
            .margin({ left: 16, right: 16, bottom: 8 })
          }, (perm: PendingPermission) => perm.id)
        }
        .width('100%')
      }

      // Question dock — show pending questions
      if (this.viewModel.pendingQuestions.length > 0) {
        Column() {
          ForEach(this.viewModel.pendingQuestions, (q: PendingQuestion) => {
            Column() {
              Row() {
                Text('❓ 问题')
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Bold)
                Blank()
              }
              .width('100%')
              .margin({ bottom: 6 })

              if (q.header.length > 0) {
                Text(q.header)
                  .fontSize(14)
                  .fontColor('#FFFFFF')
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .margin({ bottom: 4 })
              }

              Text(q.question)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .width('100%')
                .margin({ bottom: 8 })

              // Options
              ForEach(q.options, (opt: QuestionOption) => {
                Row() {
                  Button(opt.label)
                    .fontSize(13)
                    .height(32)
                    .backgroundColor('#007DFF')
                    .fontColor('#FFFFFF')
                    .borderRadius(6)
                    .onClick(() => { this.viewModel.replyQuestion(q.id, [opt.id]) })
                  if (opt.description.length > 0) {
                    Text(opt.description)
                      .fontSize(12)
                      .fontColor('#FFFFFF')
                      .margin({ left: 8 })
                  }
                }
                .width('100%')
                .margin({ bottom: 4 })
              }, (opt: QuestionOption) => opt.id)

              // Reject button
              Button('拒绝')
                .fontSize(12)
                .height(28)
                .backgroundColor('#2D2D2D')
                .fontColor('#FFFFFF')
                .borderRadius(6)
                .margin({ top: 4 })
                .onClick(() => { this.viewModel.rejectQuestion(q.id) })
            }
            .width('100%')
            .padding(12)
            .backgroundColor('#001A1A')
            .borderRadius(8)
            .borderWidth(1)
            .borderColor('#007DFF40')
            .margin({ left: 16, right: 16, bottom: 8 })
          }, (q: PendingQuestion) => q.id)
        }
        .width('100%')
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
          .onChange((value: string) => { this.inputText = value })
          .onSubmit(() => { this.sendInput() })
        Button('Send')
          .height(40)
          .width(72)
          .backgroundColor('#007DFF')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .margin({ left: 8 })
          .enabled(!this.viewModel.isGenerating)
          .onClick(() => { this.sendInput() })
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
        .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
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
                      .fontColor('#FFFFFF')
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  Text(provider.connected ? 'connected' : 'not connected')
                    .fontSize(12)
                    .fontColor('#FFFFFF')
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
                    .fontColor('#FFFFFF')
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

  // ── ModelsContent 已迁出到 AiConfigPage 的"模型选择"Tab(PR 2) ──

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

        // PR 3:Settings 收敛,只保留 5 个 Tab
        // 通用 / 外观 / 快捷键 / 权限 / 高级
        // 提供商 / 模型 / 服务器 已迁出:
        //   - 提供商 / 模型 → AI 配置(Tab 供应商配置 / 模型选择)
        //   - 服务器 → 高级
        // Runtime / WebUI / Terminal / Logs 也在 高级
        this.SettingNavItem('通用', 'general')
        this.SettingNavItem('外观', 'appearance')
        this.SettingNavItem('快捷键', 'shortcuts')
        this.SettingNavItem('权限', 'permissions')
        this.SettingNavItem('高级', 'advanced')

        Blank()

        Text('OpenCode Desktop v1.16.2')
          .fontSize(11)
          .fontColor('#FFFFFF')
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
          } else if (this.settingsTab === 'appearance') {
            // 外观:原 桌面 内容(主题 / 字号 / 通知)
            this.SettingsDesktopContent()
          } else if (this.settingsTab === 'shortcuts') {
            this.SettingsShortcutsContent()
          } else if (this.settingsTab === 'permissions') {
            // PR 3:权限策略(占位)
            this.SettingsPermissionsContent()
          } else if (this.settingsTab === 'advanced') {
            // PR 3:高级(Runtime / WebUI / Terminal / Logs / Developer Mode)
            this.SettingsAdvancedContent()
          } else if (this.settingsTab === 'servers_legacy') {
            // PR 3:服务器配置(从 Settings → 高级 跳转过来),内容保留原 servers tab
            this.SettingsServerContent()
          } else {
            // 已迁出的 legacy tabs(providers / models / servers)走兜底:
            // 直接跳到 通用,避免空白页
            this.SettingsGeneralContent()
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
      .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(value)
          .fontSize(13)
          .fontColor('#FFFFFF')
        Text(' ▾')
          .fontSize(12)
          .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text(value)
        .fontSize(13)
        .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#FFFFFF')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row() {
        Text(value)
          .fontSize(13)
          .fontColor('#FFFFFF')
        Text(' ▾')
          .fontSize(12)
          .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
        Text('手动检查更新并在有更新时安装')
          .fontSize(12)
          .fontColor('#FFFFFF')
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
      .fontColor('#FFFFFF')
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

  // ══════════════════════════════════════════════════════════
  //  PR 3:权限 (Permissions) Tab
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsPermissionsContent() {
    Text('权限')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 8 })

    Text('控制 AI 在执行工具调用、读写文件、运行命令时的询问策略。')
      .fontSize(12)
      .fontColor('#999999')
      .margin({ bottom: 20 })

    this.SSection('工具调用')
    this.SNotifRow(
      '文件读取',
      '读取项目内文件时是否需要确认。',
      this.permissionFileRead,
      () => { this.permissionFileRead = !this.permissionFileRead }
    )
    Divider().color('#222222')
    this.SNotifRow(
      '文件写入',
      '写入 / 覆盖项目内文件时是否需要确认。',
      this.permissionFileWrite,
      () => { this.permissionFileWrite = !this.permissionFileWrite }
    )
    Divider().color('#222222')
    this.SNotifRow(
      'Shell 命令',
      '运行 shell 命令时是否需要确认。',
      this.permissionShell,
      () => { this.permissionShell = !this.permissionShell }
    )

    this.SSection('会话')
    this.SNotifRow(
      '自动接受所有权限请求',
      '开启后所有权限请求自动放行(慎用)。',
      this.permissionAutoAccept,
      () => { this.permissionAutoAccept = !this.permissionAutoAccept }
    )
  }

  // ══════════════════════════════════════════════════════════
  //  PR 3:高级 (Advanced) Tab
  //  集中放 Runtime / WebUI / Terminal / Logs / Developer Mode
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsAdvancedContent() {
    Text('高级')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 8 })

    Text('Runtime 状态、Web UI、Terminal、Logs 等开发/调试入口。普通用户可忽略。')
      .fontSize(12)
      .fontColor('#999999')
      .margin({ bottom: 20 })

    this.SSection('Runtime')
    this.AdvancedLinkRow('Runtime 状态', '查看 / 启动 / 停止本地 OpenCode Runtime', () => {
      this.currentView = AppView.Runtime
    })
    Divider().color('#222222')
    this.AdvancedLinkRow('服务器配置', '配置远端 OpenCode Server URL(原"服务器"Tab)', () => {
      // PR 3:服务器配置仍走 Settings 内部 tab(legacy),后续 PR 6 再迁
      this.settingsTab = 'servers_legacy'
    })

    this.SSection('Web & Terminal')
    this.AdvancedLinkRow('Web UI', '内置 OpenCode Web 界面', () => {
      this.currentView = AppView.WebView
    })
    Divider().color('#222222')
    this.AdvancedLinkRow('Terminal', '本地 shell 终端', () => {
      this.currentView = AppView.Terminal
    })

    this.SSection('调试')
    this.AdvancedLinkRow('Logs', '查看 Runtime / App 日志(即将推出)', () => {})
    Divider().color('#222222')
    this.SNotifRow(
      'Developer Mode',
      '开启后显示实验性功能和详细错误日志。',
      this.developerMode,
      () => { this.developerMode = !this.developerMode }
    )
  }

  @Builder
  AdvancedLinkRow(title: string, desc: string, onClick: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontColor('#FFFFFF')
        Text(desc)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(18)
        .fontColor('#999999')
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .onClick(() => onClick())
  }

  @Builder
  ShortcutRow(action: string, keys: string) {
    Row() {
      Text(action)
        .fontSize(14)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
      Text(keys)
        .fontSize(12)
        .fontColor('#FFFFFF')
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
      .margin({ bottom: 12 })

    Text('默认使用本机 OpenCode Runtime。远程连接只是高级模式。')
      .fontSize(12)
      .fontColor('#FFFFFF')
      .margin({ bottom: 16 })

    // ── 模式切换器 ──
    Row() {
      this.RuntimeModePill('dev-pc', '开发电脑 / 局域网')
      this.RuntimeModePill('local', '本机模式')
      this.RuntimeModePill('remote', '远程服务器')
    }
    .backgroundColor('#1E1E1E')
    .borderRadius(8)
    .padding(3)
    .margin({ bottom: 20 })

    // Runtime URL
    Text('Runtime URL')
      .fontSize(14)
      .fontColor('#FFFFFF')
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
      .fontColor('#FFFFFF')
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
      .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
        .margin({ top: 16 })
    }
  }

  // ── Runtime 模式切换 Pill ──
  @Builder
  RuntimeModePill(id: string, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor('#FFFFFF')
      .fontWeight(this.runtimeConnectionMode === id ? FontWeight.Medium : FontWeight.Normal)
      .backgroundColor(this.runtimeConnectionMode === id ? '#007DFF' : Color.Transparent)
      .borderRadius(6)
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .margin({ right: 8 })
      .onClick(() => {
        this.switchRuntimeMode(id)
      })
  }

  private switchRuntimeMode(mode: string): void {
    // Guard: local mode requires native bridge
    if (mode === 'local' && !ProcessBridge.isAvailable) {
      Logger.warn('Cannot switch to local mode: native bridge unavailable')
      return
    }
    this.runtimeConnectionMode = mode;
    localOpenCodeServerManager.loadLastConfig().then((cfg) => {
      cfg.mode = mode;
      if (mode === 'local') {
        cfg.host = '127.0.0.1';
        this.viewModel.serverInfo.url = `http://127.0.0.1:${cfg.port}`;
      } else if (mode === 'dev-pc') {
        // dev-pc: keep previous host if non-empty and not localhost
        if (cfg.host.length === 0 || cfg.host === '127.0.0.1') {
          cfg.host = '';  // 用户需要手动输入局域网 IP
        }
        this.viewModel.serverInfo.url = `http://${cfg.host}:${cfg.port}`;
      }
      localOpenCodeServerManager.saveLastConfig(cfg).catch((e: Error) => {
        Logger.warn(`Failed to save runtime mode: ${errStr(e)}`)
      });
      Logger.info(`Runtime mode switched to: ${mode}, host=${cfg.host}:${cfg.port}`);
    }).catch((e: Error) => {
      Logger.warn(`Failed to load config for mode switch: ${errStr(e)}`)
    });
  }

  // ══════════════════════════════════════════════════════════
  //  提供商 (Providers) — 增 / 改 入口
  // ══════════════════════════════════════════════════════════

  private openAddProviderDialog(): void {
    this.editingProviderId = ''
    this.providerDialogPrefill = null
    this.showProviderDialog = true
  }

  private openEditProviderDialog(p: ProviderInfo): void {
    this.editingProviderId = p.id
    this.providerDialogPrefill = this.buildProviderPrefill(p)
    this.showProviderDialog = true
  }

  private buildProviderPrefill(p: ProviderInfo): ProviderConnectInput | null {
    const cn = providerRegistry.getById(p.id)
    if (cn === undefined) {
      const input = new ProviderConnectInput()
      input.providerId = p.id
      input.displayName = p.name
      input.apiType = 'openai_compatible'
      input.baseURL = ''
      input.apiKey = ''
      for (const id of p.models) {
        const mi = new ProviderModelInput()
        mi.id = id
        mi.name = id
        input.models.push(mi)
      }
      return input
    }
    const input = new ProviderConnectInput()
    input.providerId = cn.id
    input.displayName = cn.name
    input.apiType = this.detectApiTypeFromNpm(cn.npm)
    input.baseURL = cn.baseURL
    input.apiKey = cn.apiKey
    for (const m of cn.models) {
      const mi = new ProviderModelInput()
      mi.id = m.id
      mi.name = m.name
      input.models.push(mi)
    }
    return input
  }

  private detectApiTypeFromNpm(npm: string): string {
    if (npm.includes('anthropic')) return 'anthropic'
    if (npm.includes('aws-bedrock')) return 'bedrock_converse'
    if (npm === '@ai-sdk/openai') return 'openai_responses'
    return 'openai_compatible'
  }

  private async onProviderDialogSubmit(input: ProviderConnectInput): Promise<void> {
    if (this.providerDialogSubmitting) return
    this.providerDialogSubmitting = true
    try {
      // 编辑现有 provider 时保留 providerId(避免与已有 id 冲突校验失败)
      if (this.editingProviderId.length > 0) {
        input.providerId = this.editingProviderId
      }
      const result = await providerConnectionService.connectProvider(input, null)
      this.showProviderDialog = false
      await this.viewModel.loadProviders()
      const message = result.ok
        ? (result.message.length > 0 ? result.message : '提供商已保存')
        : (result.error.length > 0 ? result.error : '保存失败')
      promptAction.showToast({ message, duration: 2500 })
    } catch (e) {
      promptAction.showToast({ message: '保存失败: ' + errStr(e), duration: 3000 })
    } finally {
      this.providerDialogSubmitting = false
    }
  }

  private closeProviderDialog(): void {
    this.showProviderDialog = false
    this.editingProviderId = ''
    this.providerDialogPrefill = null
  }

  @Builder
  SettingsProvidersContent() {
    Row() {
      Text('提供商')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')

      Blank()

      Text('+ 添加提供商')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .height(36)
        .padding({ left: 14, right: 14 })
        .borderRadius(8)
        .backgroundColor('#3B82F6')
        .onClick(() => this.openAddProviderDialog())
    }
    .width('100%')
    .margin({ bottom: 20 })

    if (this.viewModel.providers.length === 0) {
      Column() {
        Text('未检测到任何提供商。请先连接 Runtime。')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ bottom: 12 })
        Text('或点击右上角"添加提供商"手动新增。')
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')
      .padding(24)
      .alignItems(HorizontalAlign.Center)
    } else {
      ForEach(this.viewModel.providers, (p: ProviderInfo) => {
        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(p.connected ? '#00C853' : '#666666')
            .margin({ right: 12 })

          Column() {
            Text(p.name)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
            Text(`${p.id} · ${p.models.length} 个模型`)
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(p.connected ? '已连接' : '未连接')
            .fontSize(12)
            .fontColor(p.connected ? '#00C853' : '#999999')
            .backgroundColor(p.connected ? '#1A3D2A' : '#2A2A2A')
            .borderRadius(4)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })

          Text('编辑')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .height(32)
            .padding({ left: 14, right: 14 })
            .borderRadius(6)
            .backgroundColor('#2D2D2D')
            .margin({ left: 12 })
            .onClick(() => this.openEditProviderDialog(p))
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#1E1E1E')
        .borderRadius(8)
        .margin({ bottom: 8 })
        .onClick(() => this.openEditProviderDialog(p))
      }, (p: ProviderInfo) => p.id)
    }

    Stack() {
      ProviderConnectDialog({
        visible: this.showProviderDialog,
        prefill: this.providerDialogPrefill,
        onCancel: () => this.closeProviderDialog(),
        onSubmit: (input: ProviderConnectInput) => this.onProviderDialogSubmit(input)
      })
    }
    .position({ x: 0, y: 0 })
    .width('100%')
    .height('100%')
  }

  // ══════════════════════════════════════════════════════════
  //  模型 (Models) — 内联模型选择器
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsModelsContent() {
    Text('模型')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 20 })

    Text('当前选中')
      .fontSize(14)
      .fontColor('#FFFFFF')
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

    Button('保存')
      .height(36)
      .backgroundColor('#007DFF')
      .fontColor('#FFFFFF')
      .borderRadius(8)
      .margin({ bottom: 24 })
      .onClick(() => {
        this.viewModel.saveServerConfig()
        this.viewModel.syncModelToRuntime()
      })

    // 按提供商分组显示可用模型
    if (this.viewModel.providers.length > 0) {
      Text('可用模型')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .margin({ bottom: 12 })

      ForEach(this.viewModel.providers, (p: ProviderInfo) => {
        if (p.models.length > 0) {
          Text(p.name)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .margin({ top: 12, bottom: 8 })

          ForEach(p.models, (modelId: string) => {
            Row() {
              Text(`${p.id}/${modelId}`)
                .fontSize(13)
                .fontColor('#FFFFFF')
                .fontFamily('monospace')
                .layoutWeight(1)

              if (this.viewModel.selectedModel === `${p.id}/${modelId}`) {
                Text('✓')
                  .fontSize(14)
                  .fontColor('#FFFFFF')
              }
            }
            .width('100%')
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
            .backgroundColor(this.viewModel.selectedModel === `${p.id}/${modelId}` ? '#1A2A3D' : '#1E1E1E')
            .borderRadius(6)
            .margin({ bottom: 4 })
            .onClick(() => {
              this.viewModel.selectedModel = `${p.id}/${modelId}`
              this.viewModel.saveServerConfig()
              this.viewModel.syncModelToRuntime()
            })
          }, (modelId: string) => `${p.id}/${modelId}`)
        }
      }, (p: ProviderInfo) => p.id)
    }
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
          .fontColor('#FFFFFF')
          .fontFamily('monospace')
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .margin({ bottom: 12 })

        Text(this.viewModel.serverInfo.url.length > 0 ? this.viewModel.serverInfo.url : '未配置')
          .fontSize(13)
          .fontColor('#FFFFFF')
          .fontFamily('monospace')
          .width('100%')

        Row() {
          Circle()
            .width(8)
            .height(8)
            .fill(this.getStatusColor())
          Text(this.getStatusText())
            .fontSize(12)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .margin({ left: 8 })
        }
        .margin({ top: 16 })

        if (this.viewModel.serverStatusMessage.length > 0) {
          Text(this.viewModel.serverStatusMessage)
            .fontSize(12)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .margin({ top: 8 })
        }

        Row() {
          Button('关闭')
            .fontSize(13)
            .height(32)
            .backgroundColor('#1f1f1f')
            .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
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
          .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .width(96)

      Text(desc)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .layoutWeight(1)
    }
    .width('100%')
    .height(28)
    .alignItems(VerticalAlign.Center)
  }
}
