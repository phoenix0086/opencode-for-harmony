import { common } from '@kit.AbilityKit';
import { MainViewModel, PendingPermission, PendingQuestion, PendingQuestionItem, QuestionOption } from '../viewmodel/MainViewModel';
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
import { toRuntimeMode } from '../services/RuntimeMode';
import { i18n } from '../services/I18nService';

class RemoteFileEntry {
  name: string = ''
  path: string = ''
  type: string = 'file'
  ignored: boolean = false
}

/**
 * Main page of the OpenCode app.
 * Provides the primary navigation shell with a sidebar and content area.
 */
@Entry
@Component
struct Index {
  @State viewModel: MainViewModel = new MainViewModel();
  @State currentView: AppView = AppView.Home;
  // Compact by default so the chat remains usable on HarmonyOS phones.
  // Tablets/laptops can expand it with the visible chevron handle.
  @State sidebarCollapsed: boolean = true;
  @State showSettings: boolean = false;
  @State initialized: boolean = false;

  // ── OpenCodeHomeLaunch 相关状态 ──
  @State homeProjects: ProjectEntry[] = []
  @State showDirectoryPicker: boolean = false
  @State showServerStatusDialog: boolean = false
  @State showHelpDialog: boolean = false
  @State inputText: string = '';
  @State fileDirectory: string = '.'
  @State remoteFiles: RemoteFileEntry[] = []
  @State selectedFilePath: string = ''
  @State selectedFileContent: string = ''
  @State filesLoading: boolean = false
  @State fileError: string = ''
  // S1 fix: Provider 缺 API key 时 home 顶部显示 banner;onPageShow 每次重读
  @State hasMissingApiKey: boolean = false

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
  @State modelSelectionSaving: boolean = false
  @State providerRefreshing: boolean = false

  private context: common.UIAbilityContext = AppStorage.get<Context>('appContext') as common.UIAbilityContext;

  // S1 fix: 每次进入页面都重读 providerRegistry.hasMissingApiKey(),
  // 这样用户从 Provider 页填好 key 回 home,banner 自动消失
  onPageShow(): void {
    this.refreshProviderMissingState()
    this.viewModel.resumeHealthCheck()
  }

  private refreshProviderMissingState(): void {
    try {
      this.hasMissingApiKey = providerRegistry.hasMissingApiKey()
    } catch (e) {
      // providerRegistry.init() 还没跑过,默认 false
      this.hasMissingApiKey = false
    }
  }

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
      this.viewModel.runtimeMode = toRuntimeMode(this.runtimeConnectionMode)

      // After init: fix URL to match current mode (especially after auto-fallback)
      if (autoFallbackDone) {
        const cfg = await localOpenCodeServerManager.loadLastConfig()
        this.viewModel.serverInfo.url = `http://${cfg.host}:${cfg.port}`
        Logger.info(`URL auto-updated to: ${this.viewModel.serverInfo.url}`)
      }

      this.initialized = true;
      Logger.info('Index page initialized, starting auto-connect...');
      // S1 fix: 加载 provider 后立刻同步 banner 状态,首屏就能看到
      this.refreshProviderMissingState();
      // 修复 W6: autoStartAndConnect 和 loadRecentProjects 互不依赖,
      // 改为 Promise.allSettled 并行,首屏更流畅。
      // 使用 allSettled 而非 all，确保一个失败不影响另一个完成。
      await Promise.allSettled([
        this.viewModel.autoStartAndConnect(),
        this.loadRecentProjects()
      ])
      // The first project load races intentionally with connection startup.
      // Refresh once connected so remote OpenCode workspaces replace the
      // storage-only fallback list.
      await this.loadRecentProjects()
    }
  }

  aboutToDisappear(): void {
    // BUG-01 修复: 页面销毁时清理健康检查定时器, 防止 setInterval 泄漏。
    // 注意: 仅清理定时器, 不关闭 Runtime (Runtime 生命周期由用户/应用退出统一处理)。
    this.viewModel.stopHealthCheck()
    // 不要在页面消失时自动关闭 Runtime。
    // 页面切换、预览刷新、生命周期变化都可能触发 aboutToDisappear(),
    // 切到设置页或弹模态都会杀 Runtime,导致 Chat 残影和未连接状态。
    // Runtime 应该由用户明确点击"停止 Runtime"按钮,或应用真正退出时统一处理。
    Logger.info('Index page disappeared; health timer stopped, Runtime kept alive (no shutdown)');
  }

  /**
   * 从 storage 加载最近项目列表 (与 opencode-dev 的 recentProjects 对齐)
   * 数据源: StorageService.recents key,JSON 数组 [{id,directory,lastOpened,worktree}]
   */
  async loadRecentProjects(): Promise<void> {
    try {
      if (this.viewModel.connectionStatus === ConnectionStatus.Connected &&
          this.viewModel.runtimeMode !== 'local-embedded') {
        const remote = await this.viewModel.listProjects()
        const remoteProjects: ProjectEntry[] = []
        for (let i = 0; i < remote.length; i++) {
          const item = remote[i] as Record<string, Object>
          const directory = (item['worktree'] as string) ?? (item['directory'] as string) ?? ''
          if (directory.length === 0 || directory === '/') continue
          const project = new ProjectEntry()
          project.id = (item['id'] as string) ?? directory
          project.name = directory.split('/').pop() ?? directory
          project.directory = directory
          project.worktree = directory
          const time = item['time'] as Record<string, Object>
          const updated = time ? ((time['updated'] as number) ?? 0) : 0
          project.lastOpened = updated > 0 ? new Date(updated).toISOString() : ''
          project.isActive = directory === this.viewModel.serverInfo.projectPath
          remoteProjects.push(project)
        }
        if (remoteProjects.length > 0) {
          this.homeProjects = remoteProjects
          return
        }
      }

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
      const selected = await this.viewModel.selectProject(directory)
      if (!selected) {
        this.showToast('项目切换失败，请检查电脑端目录是否仍存在')
        return
      }
      await storageSingleton.saveWorkspacePath(directory)
      await storageSingleton.addRecentWorkspace(directory)

      await this.loadRecentProjects()
      this.currentView = AppView.Chat
    } catch (err) {
      Logger.error(`openProject failed: ${errStr(err)}`)
    }
  }

  async loadRemoteFiles(directory: string = '.'): Promise<void> {
    if (this.viewModel.connectionStatus !== ConnectionStatus.Connected) {
      this.fileError = '请先连接电脑上的 OpenCode Server'
      return
    }
    this.filesLoading = true
    this.fileError = ''
    try {
      const raw = await this.viewModel.listWorkspaceDirectory(directory)
      const entries: RemoteFileEntry[] = []
      for (const value of raw) {
        if (!value || typeof value !== 'object') continue
        const record = value as Record<string, Object>
        const entry = new RemoteFileEntry()
        entry.path = (record['path'] as string) || ''
        entry.name = (record['name'] as string) || this.fileName(entry.path)
        entry.type = (record['type'] as string) || (entry.path.endsWith('/') ? 'directory' : 'file')
        entry.ignored = record['ignored'] === true
        if (entry.path.length > 0) entries.push(entry)
      }
      this.fileDirectory = directory.length > 0 ? directory : '.'
      this.remoteFiles = entries
      this.selectedFilePath = ''
      this.selectedFileContent = ''
    } catch (e) {
      this.fileError = errStr(e)
    } finally {
      this.filesLoading = false
    }
  }

  async openRemoteFile(entry: RemoteFileEntry): Promise<void> {
    if (entry.type === 'directory' || entry.path.endsWith('/')) {
      await this.loadRemoteFiles(entry.path)
      return
    }
    this.filesLoading = true
    this.fileError = ''
    try {
      const result = await this.viewModel.readWorkspaceFile(entry.path)
      const type = (result['type'] as string) || 'text'
      this.selectedFilePath = entry.path
      this.selectedFileContent = type === 'text'
        ? ((result['content'] as string) || '')
        : '这是二进制文件，暂不提供文本预览。'
    } catch (e) {
      this.fileError = `打开文件失败: ${errStr(e)}`
    } finally {
      this.filesLoading = false
    }
  }

  private fileName(path: string): string {
    const normalized = path.endsWith('/') ? path.substring(0, path.length - 1) : path
    return normalized.split('/').pop() || normalized
  }

  private parentFileDirectory(): string {
    if (this.fileDirectory === '.' || this.fileDirectory.length === 0) return '.'
    const normalized = this.fileDirectory.endsWith('/')
      ? this.fileDirectory.substring(0, this.fileDirectory.length - 1)
      : this.fileDirectory
    const index = normalized.lastIndexOf('/')
    return index > 0 ? normalized.substring(0, index + 1) : '.'
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
        projectName: this.viewModel.serverInfo.projectPath.split('/').pop() ?? '',
        projectPath: this.viewModel.serverInfo.projectPath,
        branchName: this.viewModel.currentBranch,
        modelName: this.viewModel.selectedModel,
        isConnected: this.viewModel.connectionStatus === ConnectionStatus.Connected,
        serverVersion: this.viewModel.serverInfo.url,
        projects: this.homeProjects,
        serverName: this.viewModel.serverInfo.displayName.length > 0 ? this.viewModel.serverInfo.displayName : 'Local Server',
        isServerReady: this.viewModel.connectionStatus === ConnectionStatus.Connected ||
                        this.viewModel.connectionStatus === ConnectionStatus.AutoStarting ||
                        this.viewModel.connectionStatus === ConnectionStatus.Connecting ||
                        this.viewModel.connectionStatus === ConnectionStatus.StartFailed,
        // S1 fix: 缺 API key 时 home 顶部显示 banner
        hasMissingApiKey: this.hasMissingApiKey,
        onNewSession: () => {
          this.newSessionAndOpenChat()
        },
        onOpenChat: () => {
          this.currentView = AppView.Chat
        },
        onOpenSettings: () => {
          this.settingsTab = 'general'
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
        },
        onOpenProviders: () => {
          // 直接跳到 Settings 的 providers tab,不用先开 Settings 再切 tab
          this.settingsTab = 'providers'
          this.showSettings = true
          this.refreshProviderData()
        }
      })

      // ── DirectoryPicker 弹层 ──
      DirectoryPicker({
        visible: this.showDirectoryPicker,
        projects: this.homeProjects,
        currentDirectory: this.viewModel.serverInfo.projectPath,
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
    Stack({ alignContent: Alignment.Start }) {
      Row() {
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
            .onClick(() => { this.sidebarCollapsed = false })
          }
          .width(48)
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#111111')
        }

        this.MainWorkspaceContent()
      }
      .width('100%')
      .height('100%')

      if (!this.sidebarCollapsed) {
        Button() {}
          .width('100%')
          .height('100%')
          .backgroundColor('#00000066')
          .borderRadius(0)
          .onClick(() => { this.sidebarCollapsed = true })

        this.SidebarDrawer()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  MainWorkspaceContent() {
    Column() {
      if (this.currentView === AppView.Home) {
        this.HomeContent()
      } else if (this.currentView === AppView.Chat) {
        this.ChatContent()
      } else if (this.currentView === AppView.Files) {
        this.FilesContent()
      } else if (this.currentView === AppView.Settings) {
        this.HomeContent()
      } else if (this.currentView === AppView.Provider) {
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

  @Builder
  SidebarDrawer() {
    Column() {
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
        .onClick(() => { this.sidebarCollapsed = true })
      }
      .width('100%')
      .height(Constants.TITLE_BAR_HEIGHT)
      .padding({ left: 8, right: 8 })
      .alignItems(VerticalAlign.Center)

      Divider().color('#404040').width('100%')

      Column() {
        this.NavItem(AppView.Chat, $r('app.media.chat'), i18n.t('sidebar.chat'))
        this.NavItem(AppView.Files, $r('app.media.home'), i18n.t('sidebar.projects'))
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      Text(i18n.t('sidebar.sessions'))
        .fontSize(11)
        .fontColor('#8A8A8A')
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 6 })

      List() {
        ForEach(this.viewModel.sessions.slice(0, 20), (session: SessionInfo) => {
          ListItem() {
            Text(session.title.length > 0 ? session.title : i18n.t('session.untitled'))
              .fontSize(12)
              .fontColor('#FFFFFF')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
              .padding({ left: 16, right: 12 })
          }
          .height(38)
          .width('100%')
          .backgroundColor(this.viewModel.currentSessionId === session.id ? '#2A2A2A' : Color.Transparent)
          .onClick(() => { this.openSessionFromDrawer(session.id) })
        }, (session: SessionInfo) => session.id)
      }
      .width('100%')
      .layoutWeight(1)

      Divider().color('#404040').width('100%')

      Row() {
        Circle().width(8).height(8).fill(this.getStatusColor())
        Text(this.getStatusText())
          .fontSize(12)
          .fontColor('#FFFFFF')
          .margin({ left: 8 })
      }
      .width('100%')
      .height(40)
      .padding({ left: 16, right: 16 })
      .alignItems(VerticalAlign.Center)

      Button() {
        Row() {
          Text('⚙️').fontSize(16).fontColor('#FFFFFF')
          Text(i18n.t('sidebar.settings')).fontSize(14).fontColor('#FFFFFF').margin({ left: 12 })
        }
      }
      .width('100%')
      .height(44)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.sidebarCollapsed = true
        this.settingsTab = 'general'
        this.showSettings = true
      })
    }
    .width(Constants.SIDEBAR_WIDTH)
    .height('100%')
    .backgroundColor('#1A1A1A')
    .shadow({ radius: 18, color: '#00000099', offsetX: 6, offsetY: 0 })
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
      this.sidebarCollapsed = true;
      if (view === AppView.Files) this.loadRemoteFiles('.')
    })
  }

  private async openSessionFromDrawer(sessionId: string): Promise<void> {
    this.sidebarCollapsed = true
    this.currentView = AppView.Chat
    await this.viewModel.selectSession(sessionId)
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
            // S5 fix: 给用户即时反馈,让"按下去有事发生"这件事可见
            this.showToast('正在重启 Runtime...', 1500)
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
        Text(this.currentSessionTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.viewModel.isGenerating) {
          Button(i18n.t('composer.stop'))
            .fontSize(13)
            .height(32)
            .backgroundColor('#FF5252')
            .fontColor('#FFFFFF')
            .borderRadius(6)
            .onClick(() => { this.viewModel.stopGeneration() })
        }
        Button(i18n.t('session.new'))
          .fontSize(13)
          .height(32)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(6)
          .margin({ left: 8 })
          .enabled(!this.viewModel.isGenerating)
          .opacity(this.viewModel.isGenerating ? 0.45 : 1)
          .onClick(() => {
            this.inputText = ''
            this.viewModel.beginNewSession()
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

              ForEach(q.questions, (question: PendingQuestionItem, questionIndex: number) => {
                Column() {
                  if (question.header.length > 0) {
                    Text(question.header)
                      .fontSize(14)
                      .fontColor('#FFFFFF')
                      .fontWeight(FontWeight.Medium)
                      .width('100%')
                      .margin({ bottom: 4 })
                  }

                  Text(question.question)
                    .fontSize(13)
                    .fontColor('#FFFFFF')
                    .width('100%')
                    .margin({ bottom: 8 })

                  ForEach(question.options, (opt: QuestionOption) => {
                    Row() {
                      Button(`${this.viewModel.isQuestionOptionSelected(q.id, questionIndex, opt.label) ? '✓ ' : ''}${opt.label}`)
                        .fontSize(13)
                        .height(32)
                        .backgroundColor(this.viewModel.isQuestionOptionSelected(q.id, questionIndex, opt.label) ? '#3DDC84' : '#007DFF')
                        .fontColor('#FFFFFF')
                        .borderRadius(6)
                        .onClick(() => { this.viewModel.selectQuestionOption(q.id, questionIndex, opt.label) })
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
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 8 })
              }, (_question: PendingQuestionItem, questionIndex: number) => `${q.id}-${questionIndex}`)

              Row() {
                Button('提交回答')
                  .fontSize(12)
                  .height(30)
                  .enabled(this.viewModel.canSubmitQuestion(q.id))
                  .backgroundColor(this.viewModel.canSubmitQuestion(q.id) ? '#3DDC84' : '#555555')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .onClick(() => { this.viewModel.replyQuestion(q.id) })
                Button('拒绝')
                  .fontSize(12)
                  .height(30)
                  .backgroundColor('#2D2D2D')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .margin({ left: 8 })
                  .onClick(() => { this.viewModel.rejectQuestion(q.id) })
              }
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
        TextInput({ placeholder: i18n.t('composer.placeholder'), text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#2D2D2D')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .placeholderColor('#666666')
          .onChange((value: string) => { this.inputText = value })
          .onSubmit(() => { this.sendInput() })
        Button(i18n.t('composer.send'))
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
      // W3 fix: 显式 toast,用户按 Send 后立刻看到反馈,
      // RuntimeDisconnectedCard 已经在显示了,但那是被动反馈,toast 是主动反馈
      this.showToast('本地 Runtime 未连接,请先启动或连接', 2000)
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
      Row() {
        if (this.fileDirectory !== '.') {
          Button('‹ 返回')
            .height(34)
            .fontSize(13)
            .backgroundColor('#2D2D2D')
            .fontColor('#FFFFFF')
            .borderRadius(7)
            .onClick(() => { this.loadRemoteFiles(this.parentFileDirectory()) })
        }
        Column() {
          Text('电脑端项目文件')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(this.fileDirectory)
            .fontSize(11)
            .fontColor('#999999')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: this.fileDirectory !== '.' ? 10 : 0 })
        Button('刷新')
          .height(34)
          .fontSize(13)
          .backgroundColor('#2D2D2D')
          .fontColor('#FFFFFF')
          .borderRadius(7)
          .onClick(() => { this.loadRemoteFiles(this.fileDirectory) })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 12 })

      Divider().color('#2D2D2D').width('100%')

      if (this.filesLoading) {
        Column() {
          LoadingProgress().width(30).height(30).color('#007DFF')
          Text('正在读取电脑端项目…').fontSize(13).fontColor('#999999').margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.fileError.length > 0) {
        Column() {
          Text(this.fileError).fontSize(14).fontColor('#FF6B6B').textAlign(TextAlign.Center)
          Button('重试')
            .margin({ top: 14 })
            .onClick(() => { this.loadRemoteFiles(this.fileDirectory) })
        }
        .layoutWeight(1)
        .width('100%')
        .padding(24)
        .justifyContent(FlexAlign.Center)
      } else if (this.selectedFilePath.length > 0) {
        Column() {
          Row() {
            Button('‹ 文件列表')
              .height(32)
              .fontSize(12)
              .backgroundColor('#2D2D2D')
              .fontColor('#FFFFFF')
              .onClick(() => {
                this.selectedFilePath = ''
                this.selectedFileContent = ''
              })
            Text(this.selectedFilePath)
              .layoutWeight(1)
              .fontSize(12)
              .fontColor('#CCCCCC')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ left: 10 })
          }
          .width('100%')
          .margin({ bottom: 10 })
          Scroll() {
            Text(this.selectedFileContent)
              .fontSize(12)
              .fontFamily('monospace')
              .fontColor('#E6E6E6')
              .width('100%')
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#171717')
          .padding(12)
        }
        .layoutWeight(1)
        .width('100%')
        .padding(14)
      } else {
        List() {
          ForEach(this.remoteFiles, (entry: RemoteFileEntry) => {
            ListItem() {
              Row() {
                Text(entry.type === 'directory' || entry.path.endsWith('/') ? '📁' : '📄')
                  .fontSize(18)
                Column() {
                  Text(entry.name)
                    .fontSize(14)
                    .fontColor(entry.ignored ? '#777777' : '#FFFFFF')
                    .maxLines(1)
                  Text(entry.path)
                    .fontSize(10)
                    .fontColor('#777777')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 10 })
                Text('›').fontSize(18).fontColor('#777777')
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 11, bottom: 11 })
              .onClick(() => { this.openRemoteFile(entry) })
            }
          }, (entry: RemoteFileEntry) => entry.path)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 1, color: '#242424', startMargin: 44 })
      }
    }
    .width('100%')
    .height('100%')
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

  // ── Settings 弹窗: 与桌面版一致,覆盖在当前页面上方而不是替换主内容 ──

  @Builder
  SettingsModal() {
    Stack({ alignContent: Alignment.Center }) {
      Rect()
        .fill('#00000099')
        .width('100%')
        .height('100%')
        .onClick(() => {
          if (!this.providerDialogSubmitting) {
            this.showSettings = false
            this.closeProviderDialog()
          }
        })

      Stack({ alignContent: Alignment.TopEnd }) {
        this.SettingsContent()

        if (this.showProviderDialog) {
          ProviderConnectDialog({
            visible: this.showProviderDialog,
            prefill: this.providerDialogPrefill,
            submitting: this.providerDialogSubmitting,
            onCancel: () => this.closeProviderDialog(),
            onSubmit: (input: ProviderConnectInput) => this.onProviderDialogSubmit(input)
          })
        }

        if (!this.showProviderDialog) {
          Text('\u00d7')
            .fontSize(24)
            .fontColor('#A3A3A3')
            .width(40)
            .height(40)
            .textAlign(TextAlign.Center)
            .borderRadius(8)
            .margin({ top: 10, right: 10 })
            .zIndex(2)
            .onClick(() => {
              this.showSettings = false
              this.closeProviderDialog()
            })
        }
      }
      .width('96%')
      .height('92%')
      .constraintSize({ maxWidth: 1180, maxHeight: 860 })
      .borderRadius(12)
      .clip(true)
      .borderWidth(1)
      .borderColor('#2A2A2A')
      .shadow({ radius: 28, color: '#66000000', offsetX: 0, offsetY: 14 })
    }
    .width('100%')
    .height('100%')
    .zIndex(1000)
  }

  @Builder
  SettingsContent() {
    Row() {
      // ── Settings sidebar ──
      Column() {
        Text('OHOpenCode')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 16 })

        Text('应用')
          .fontSize(13)
          .fontColor('#777777')
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 20, top: 8, bottom: 6 })
        this.SettingNavItem('通用', 'general')

        Text('OpenCode')
          .fontSize(13)
          .fontColor('#777777')
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 20, top: 18, bottom: 6 })
        this.SettingNavItem('服务器', 'servers')
        this.SettingNavItem('提供商', 'providers')
        this.SettingNavItem('模型', 'models')

        Blank()

        Text('HarmonyOS 客户端')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 20, bottom: 16 })
      }
      .width(124)
      .height('100%')
      .backgroundColor('#1A1A1A')

      // ── Settings content ──
      Scroll() {
        Column() {
          if (this.settingsTab === 'general') {
            this.SettingsAppOverviewContent()
          } else if (this.settingsTab === 'servers') {
            this.SettingsServerContent()
          } else if (this.settingsTab === 'providers') {
            this.SettingsProvidersContent()
          } else if (this.settingsTab === 'models') {
            this.SettingsModelsContent()
          } else {
            this.SettingsAppOverviewContent()
          }
        }
        .padding({ left: 16, right: 16, top: 20, bottom: 36 })
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#111111')
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
        if (tab === 'providers' || tab === 'models') {
          this.refreshProviderData()
        }
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

  @Builder
  SettingsAppOverviewContent() {
    Text('通用')
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor('#FFFFFF')
      .margin({ bottom: 8 })

    Text('这台鸿蒙设备作为客户端，所有代码执行都由电脑上的 OpenCode 完成。')
      .fontSize(13)
      .fontColor('#AAAAAA')
      .margin({ bottom: 22 })

    this.SettingsRowText('连接状态', '电脑端 OpenCode Server', this.getStatusText())
    Divider().color('#222222')
    this.SettingsRowText('当前项目', '电脑端工作目录', this.viewModel.serverInfo.projectPath.length > 0 ? this.viewModel.serverInfo.projectPath : '尚未选择')
    Divider().color('#222222')
    this.SettingsRowText('当前模型', '消息将发送给这个模型', this.viewModel.selectedModel.length > 0 ? this.viewModel.selectedModel : '尚未选择')
    Divider().color('#222222')
    this.SettingsRowText('接口模式', '由客户端自动探测', this.viewModel.serverMode === 'api-v2' ? 'OpenCode API v2' : this.viewModel.serverMode)

    Row() {
      Button('重新连接')
        .height(38)
        .layoutWeight(1)
        .backgroundColor('#007DFF')
        .fontColor('#FFFFFF')
        .borderRadius(7)
        .onClick(() => { this.viewModel.connect() })
      Button('刷新项目')
        .height(38)
        .layoutWeight(1)
        .backgroundColor('#2D2D2D')
        .fontColor('#FFFFFF')
        .borderRadius(7)
        .margin({ left: 10 })
        .onClick(() => { this.loadRecentProjects() })
    }
    .width('100%')
    .margin({ top: 24 })
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

    Text('填写电脑上 OpenCode Server 的局域网地址。手机只作为控制端，不在本机运行代码。')
      .fontSize(12)
      .fontColor('#FFFFFF')
      .margin({ bottom: 16 })

    // ── 模式切换器 ──
    Row() {
      this.RuntimeModePill('dev-pc', '局域网电脑')
      this.RuntimeModePill('remote', '远程地址')
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

    if (this.isInsecureRemoteServer()) {
      Row() {
        Text('⚠').fontSize(14).fontColor('#FFB454')
        Text('当前为未加密的 HTTP 局域网连接。账号和消息可能被同一网络中的设备看到；在不可信网络上请使用 HTTPS 或 VPN。')
          .fontSize(11)
          .fontColor('#FFCC80')
          .layoutWeight(1)
          .margin({ left: 8 })
      }
      .width('100%')
      .padding(10)
      .margin({ top: 10 })
      .backgroundColor('#2A1F0E')
      .borderRadius(7)
    }

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
    this.viewModel.runtimeMode = toRuntimeMode(mode)
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
      if (!result.ok) {
        const error = result.error.length > 0 ? result.error : (result.message.length > 0 ? result.message : '保存失败')
        this.showToast(error, 3000)
        return
      }
      await localRuntimeService.syncFromProviderRegistry()
      this.showProviderDialog = false
      await this.viewModel.loadProviders()
      this.refreshProviderMissingState()
      const message = result.message.length > 0 ? result.message : '提供商已保存'
      this.showToast(message, 2500)
    } catch (e) {
      this.showToast('保存失败: ' + errStr(e), 3000)
    } finally {
      this.providerDialogSubmitting = false
    }
  }

  private closeProviderDialog(): void {
    if (this.providerDialogSubmitting) return
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

      Text(this.providerRefreshing ? '刷新中...' : '刷新')
        .fontSize(13)
        .fontColor(this.providerRefreshing ? '#777777' : '#D4D4D4')
        .height(36)
        .padding({ left: 14, right: 14 })
        .borderRadius(8)
        .backgroundColor('#2A2A2A')
        .margin({ left: 8 })
        .enabled(!this.providerRefreshing)
        .onClick(() => this.refreshProviderData())
    }
    .width('100%')
    .margin({ bottom: 20 })

    if (this.providerRefreshing && this.viewModel.providers.length === 0) {
      Column() {
        LoadingProgress()
          .width(28)
          .height(28)
          .color('#3B82F6')
        Text('正在读取提供商...')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(32)
    } else if (this.viewModel.providers.length === 0) {
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

  }

  // ══════════════════════════════════════════════════════════
  //  模型 (Models) — 内联模型选择器
  // ══════════════════════════════════════════════════════════
  @Builder
  SettingsModelsContent() {
    Row() {
      Text('模型')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
      Blank()
      Text(this.providerRefreshing ? '刷新中...' : '刷新')
        .fontSize(13)
        .fontColor(this.providerRefreshing ? '#777777' : '#D4D4D4')
        .height(36)
        .padding({ left: 14, right: 14 })
        .borderRadius(8)
        .backgroundColor('#2A2A2A')
        .enabled(!this.providerRefreshing)
        .onClick(() => this.refreshProviderData())
    }
    .width('100%')
    .margin({ bottom: 20 })

    TextInput({ placeholder: '搜索模型', text: this.settingsModelSearch })
      .width('100%')
      .height(44)
      .backgroundColor('#1A1A1A')
      .borderRadius(10)
      .fontColor('#FFFFFF')
      .margin({ bottom: 22 })
      .onChange((value: string) => {
        this.settingsModelSearch = value
      })

    if (this.providerRefreshing && this.viewModel.providers.length === 0) {
      Column() {
        LoadingProgress()
          .width(28)
          .height(28)
          .color('#3B82F6')
        Text('正在读取模型...')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      }
      .width('100%')
      .padding(32)
    } else if (this.viewModel.providers.length > 0) {
      ForEach(this.viewModel.providers, (p: ProviderInfo) => {
        if (p.models.length > 0) {
          Row() {
            Text(p.name.length > 0 ? p.name : p.id)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
            Text(p.connected ? '已连接' : '未连接')
              .fontSize(11)
              .fontColor(p.connected ? '#00C853' : '#999999')
              .backgroundColor(p.connected ? '#14351F' : '#2A2A2A')
              .borderRadius(4)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .margin({ left: 10 })
          }
          .width('100%')
          .margin({ top: 20, bottom: 10 })

          Column() {
            ForEach(p.models, (modelId: string) => {
              if (this.modelVisible(p.id, modelId)) {
                Row() {
                  Text(this.modelDisplayName(modelId))
                    .fontSize(15)
                    .fontColor('#FFFFFF')
                    .layoutWeight(1)

                  Toggle({
                    type: ToggleType.Switch,
                    isOn: this.viewModel.selectedModel === `${p.id}/${modelId}`
                  })
                    .selectedColor('#FFFFFF')
                    .onChange((isOn: boolean) => {
                      if (!isOn) return
                      this.selectSettingsModel(`${p.id}/${modelId}`, this.modelDisplayName(modelId))
                    })
                }
                .width('100%')
                .height(58)
                .padding({ left: 16, right: 16 })
                .borderColor('#2A2A2A')
                .borderWidth({ bottom: 1 })
                .onClick(() => {
                  this.selectSettingsModel(`${p.id}/${modelId}`, this.modelDisplayName(modelId))
                })
              }
            }, (modelId: string) => `${p.id}/${modelId}`)
          }
          .width('100%')
          .backgroundColor('#171717')
          .borderRadius(10)
        }
      }, (p: ProviderInfo) => p.id)
    } else {
      Text('未读取到模型。请先在提供商页添加或连接供应商。')
        .fontSize(13)
        .fontColor('#999999')
        .padding(18)
        .backgroundColor('#171717')
        .borderRadius(10)
    }
  }

  private modelVisible(providerId: string, modelId: string): boolean {
    const q = this.settingsModelSearch.trim().toLowerCase()
    if (q.length === 0) return true
    return providerId.toLowerCase().includes(q) || modelId.toLowerCase().includes(q)
  }

  private async selectSettingsModel(modelRef: string, displayName: string): Promise<void> {
    if (this.modelSelectionSaving || this.viewModel.selectedModel === modelRef) return
    const previous = this.viewModel.selectedModel
    this.modelSelectionSaving = true
    this.viewModel.selectedModel = modelRef
    try {
      await this.viewModel.saveServerConfig()
      await this.viewModel.syncModelToRuntime()
      this.showToast(`已选择 ${displayName}`)
    } catch (e) {
      this.viewModel.selectedModel = previous
      this.showToast('模型保存失败: ' + errStr(e))
    } finally {
      this.modelSelectionSaving = false
    }
  }

  private async refreshProviderData(): Promise<void> {
    if (this.providerRefreshing) return
    if (this.viewModel.connectionStatus !== ConnectionStatus.Connected) {
      this.showToast('Runtime 未连接，暂时无法刷新提供商和模型')
      return
    }
    this.providerRefreshing = true
    try {
      await this.viewModel.loadProviders()
      this.refreshProviderMissingState()
    } catch (e) {
      Logger.warn(`refreshProviderData failed: ${errStr(e)}`)
      this.showToast('刷新提供商失败: ' + errStr(e))
    } finally {
      this.providerRefreshing = false
    }
  }

  private showToast(message: string, duration: number = 2000): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message, duration })
    } catch (e) {
      Logger.warn(`showToast failed: ${errStr(e)}`)
    }
  }

  private modelDisplayName(modelId: string): string {
    const parts = modelId.split('-')
    const names: string[] = []
    for (const part of parts) {
      if (part.length === 0) continue
      names.push(part.charAt(0).toUpperCase() + part.slice(1))
    }
    return names.length > 0 ? names.join(' ') : modelId
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
        return i18n.t('status.connected');
      case ConnectionStatus.AutoStarting:
        return i18n.t('status.connecting');
      case ConnectionStatus.Connecting:
        return i18n.t('status.connecting');
      case ConnectionStatus.StartFailed:
        return i18n.t('status.error');
      case ConnectionStatus.Error:
        return i18n.t('status.error');
      default:
        return i18n.t('status.disconnected');
    }
  }

  private currentSessionTitle(): string {
    if (this.viewModel.currentSessionId.length === 0) return i18n.t('session.new')
    const current = this.viewModel.sessions.find((session: SessionInfo) => {
      return session.id === this.viewModel.currentSessionId
    })
    if (current && current.title.length > 0) return current.title
    return i18n.t('session.title')
  }

  private isInsecureRemoteServer(): boolean {
    const url = this.viewModel.serverInfo.url.trim().toLowerCase()
    if (!url.startsWith('http://')) return false
    return !url.startsWith('http://127.0.0.1') &&
      !url.startsWith('http://localhost') &&
      !url.startsWith('http://[::1]')
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
