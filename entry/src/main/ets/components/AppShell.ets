import { Theme } from './Theme'
import { Runner } from '../models/Runner'
import { SessionInfo, FileDiff, LogEntry } from '../models/Event'
import { LeftActivityBar } from './LeftActivityBar'
import { TopStatusBar } from './TopStatusBar'
import { SessionSidebar } from './SessionSidebar'
import { AgentTranscript, TranscriptBlock } from './AgentTranscript'
import { ComposerBar } from './ComposerBar'
import { ToolTimelinePanel, ToolTimelineEntry } from './ToolTimelinePanel'
import { DiffPanel } from './DiffPanel'
import { FilePanel } from './FilePanel'
import { LogsPanel } from './LogsPanel'
import { ProviderSettingsPage } from '../pages/ProviderSettingsPage'
import { ModelSettingsPage } from '../pages/ModelSettingsPage'
import { SettingsPage } from '../pages/SettingsPage'
import { SessionTabs, SessionTab } from './SessionTabs'
import { SessionContextMenu } from './SessionContextMenu'
import { ToastContainer, ToastData, ToastManager } from './ToastNotification'
import { StatusPopover } from './StatusPopover'
import { DirectoryPicker, ProjectEntry } from './DirectoryPicker'
import { OpenCodeHomeLaunch } from './home/OpenCodeHomeLaunch'
import { ServerSettingsPage } from '../pages/ServerSettingsPage'
import { RuntimePage } from '../pages/RuntimePage'
import { formatServerTitle } from '../utils/DateTimeUtil'

/**
 * AppShell - OpenCode IDE 三栏布局
 * 替代原有 Index.ets 的 emoji 导航布局
 */
@Component
export struct AppShell {
  // ══════════ Global State ══════════
  @Link activeActivity: string
  @Link activeSessionId: string
  @Link inputText: string
  @Link isSending: boolean
  @Prop activeRunner: Runner | null = null
  @Prop sessions: SessionInfo[] = []
  @Prop transcriptBlocks: TranscriptBlock[] = []
  @Prop toolEntries: ToolTimelineEntry[] = []
  @Prop diffs: FileDiff[] = []
  @Prop isStreaming: boolean = false
  @Prop projectName: string = ''
  @Prop branchName: string = ''
  @Prop modelName: string = ''
  @Prop serverUrl: string = ''
  @Prop serverVersion: string = ''
  @Prop tokenCost: string = '0 tokens'
  @Prop isConnected: boolean = false
  @Prop connectionStatus: string = 'disconnected'
  @Prop sessionTitle: string = ''
  @Prop logEntries: LogEntry[] = []
  @Prop agentMode: string = 'build'
  @Prop tokensUsed: number = 0
  @Prop tokensMax: number = 128000

  // ══════════ Callbacks ══════════
  onSelectSession: (id: string) => void = () => {}
  onNewSession: () => void = () => {}
  onSend: () => void = () => {}
  onAbort: () => void = () => {}
  onApprovePermission: (id: string) => void = () => {}
  onAlwaysApprovePermission: (id: string) => void = () => {}
  onAnswerQuestion: (id: string, optionIds: string[]) => void = () => {}
  onModeChange: (mode: string) => void = () => {}
  @Prop mcpServers: MCPServer[] = []
  @Prop lspServers: LspServer[] = []
  @Prop formatterList: FormatterEntry[] = []
  onRefreshMcp: () => void = () => {}
  onRefreshLsp: () => void = () => {}
  onRefreshFormatters: () => void = () => {}
  onModelClick: () => void = () => {}
  onRejectPermission: (id: string) => void = () => {}
  onSessionAction: (sessionId: string, action: string) => void = () => {}
  onLongPressSession: (id: string, x: number, y: number) => void = () => {}
  onCloseTab: (id: string) => void = () => {}
  onNewTab: () => void = () => {}
  onReconnect: () => void = () => {}
  onRunnerActivated: (runner: Runner) => void = () => {}
  @State showContextMenu: boolean = false
  @State contextMenuSessionId: string = ''
  @State contextMenuX: number = 0
  @State contextMenuY: number = 0

  @State showRightPanel: boolean = true
  @State rightPanelTab: string = 'tools' // 'tools' | 'diff' | 'logs'
  @State toasts: ToastData[] = []
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @State showStatusPopover: boolean = false
  @State showDirectoryPicker: boolean = false
  @Prop projects: ProjectEntry[] = []

  aboutToAppear(): void {
    ToastManager.setOnChange(() => {
      this.toasts = ToastManager.getToasts()
    })
  }

  private computeTabs(): SessionTab[] {
    const tabs: SessionTab[] = []
    for (const s of this.sessions) {
      const tab = new SessionTab()
      tab.id = s.id
      tab.title = s.title.length > 0 ? s.title : 'untitled'
      tab.isActive = s.id === this.activeSessionId
      tabs.push(tab)
    }
    return tabs
  }

  build() {
    Stack() {
      if (this.activeActivity === 'chat' && this.activeSessionId.length === 0 && this.transcriptBlocks.length === 0) {
        // ══════════ Home 全屏接管 ══════════
        Stack({ alignContent: Alignment.TopStart }) {
        OpenCodeHomeLaunch({
          inputText: $inputText,
          isSending: $isSending,
          activeRunner: this.activeRunner,
          sessions: this.sessions,
          projectName: this.projectName.length > 0 ? this.projectName : '构建任何东西',
          projectPath: this.projectName.length > 0 ? this.projectName : '',
          branchName: this.branchName,
          modelName: this.modelName,
          isConnected: this.isConnected,
          serverVersion: this.serverVersion,
          serverName: this.activeRunner !== null ? `${this.activeRunner.host}:${this.activeRunner.port}` : 'Local Server',
          isServerReady: this.activeRunner !== null,
          projects: this.projects,
          onInputChange: (value: string) => {
            this.inputText = value
          },
          onSend: () => {
            this.onSend()
          },
          onAbort: () => {
            this.onAbort()
          },
          onNewSession: () => {
            this.onNewSession()
          },
          onOpenChat: () => {
            this.activeActivity = 'chat'
          },
          onOpenSettings: () => {
            this.activeActivity = 'settings'
          },
          onOpenHelp: () => {
            // 首页模式下没有右面板，先创建 session 进入工作区再打开日志
            this.onNewSession()
            this.rightPanelTab = 'logs'
            this.showRightPanel = true
          },
          onOpenDirectoryPicker: () => {
            this.showDirectoryPicker = true
          },
          onOpenServerStatus: () => {
            this.showStatusPopover = true
          },
          onOpenRightPanel: () => {
            this.showRightPanel = !this.showRightPanel
          },
          onOpenFiles: () => {
            this.activeActivity = 'files'
          },
          onOpenModels: () => {
            this.activeActivity = 'models'
          },
          onOpenProject: (directory: string) => {
            // 点击最近项目：把目录写回当前项目名，进入 chat 工作区
            if (directory.length > 0) {
              this.projectName = directory
            }
            this.showDirectoryPicker = true
          }
        })

        StatusPopover({
          visible: this.showStatusPopover,
          isConnected: this.isConnected,
          serverUrl: this.serverUrl,
          serverVersion: this.serverVersion,
          projectName: this.projectName,
          branchName: this.branchName,
          sessionCount: this.sessions.length,
          tokensUsed: this.tokensUsed,
          tokensMax: this.tokensMax,
          agentMode: this.agentMode,
          onDismiss: () => {
            this.showStatusPopover = false
          },
          onReconnect: () => {
            this.showStatusPopover = false
            this.onReconnect()
          }
        })

        DirectoryPicker({
          visible: this.showDirectoryPicker,
          projects: this.projects,
          currentDirectory: this.projectName,
          onSelect: (directory: string) => {
            this.showDirectoryPicker = false
          },
          onDismiss: () => {
            this.showDirectoryPicker = false
          }
        })

        ToastContainer({
          toasts: this.toasts,
          onDismiss: (id: string) => {
            ToastManager.dismiss(id)
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#101010')
    }

    // ══════════ 正常 AppShell 工作区 ══════════
    Stack({ alignContent: Alignment.TopStart }) {
    Column() {
      // ══════════ Top Status Bar ══════════
      TopStatusBar({
        projectName: this.projectName,
        branchName: this.branchName,
        modelName: this.modelName,
        serverUrl: this.serverUrl,
        serverVersion: this.serverVersion,
        tokenCost: this.tokenCost,
        isConnected: this.isConnected
      })
        .onClick(() => {
          this.showStatusPopover = !this.showStatusPopover
        })

      // ══════════ Main Content Area ══════════
      Row() {
        // Left: Activity Bar
        LeftActivityBar({
          activeId: this.activeActivity,
          connectionStatus: this.connectionStatus,
          onActivityChange: (id: string) => {
            this.activeActivity = id
          },
          onOpenDirectoryPicker: () => {
            this.showDirectoryPicker = true
          }
        })

        // Left: Sidebar
        SessionSidebar({
          workspaceName: this.projectName && this.projectName.length > 0 ? this.projectName : 'workspace',
          sessions: this.sessions,
          activeSessionId: this.activeSessionId,
          onSelectSession: (id: string) => {
            this.onSelectSession(id)
            this.activeActivity = 'chat'
          },
          onNewSession: () => {
            this.onNewSession()
          },
          onLongPressSession: (id: string, x: number, y: number) => {
            this.contextMenuSessionId = id
            this.contextMenuX = x
            this.contextMenuY = y
            this.showContextMenu = true
          }
        })

        // ══════════ Center: Main Content + Composer ══════════
        Column() {
          // Center content area
          if (this.activeActivity === 'chat') {
            // Session tabs
            if (this.sessions.length > 0) {
              SessionTabs({
                tabs: this.computeTabs(),
                activeTabId: this.activeSessionId,
                onSelectTab: (id: string) => {
                  this.onSelectSession(id)
                },
                onCloseTab: (id: string) => {
                  this.onCloseTab(id)
                },
                onNewTab: () => {
                  this.onNewTab()
                }
              })
            }
            // Session header
            this.SessionHeader()
            // Transcript
            AgentTranscript({
              blocks: this.transcriptBlocks,
              isStreaming: this.isStreaming,
              onApprovePermission: (id: string) => {
                this.onApprovePermission(id)
              },
              onRejectPermission: (id: string) => {
                this.onRejectPermission(id)
              },
              onAlwaysApprovePermission: (id: string) => {
                this.onAlwaysApprovePermission(id)
              },
              onAnswerQuestion: (id: string, optionIds: string[]) => {
                if (this.onAnswerQuestion) {
                  this.onAnswerQuestion(id, optionIds)
                }
              }
            })
          } else if (this.activeActivity === 'diff') {
            DiffPanel({
              diffs: this.diffs,
              sessionTitle: this.sessionTitle
            })
          } else if (this.activeActivity === 'provider') {
            ProviderSettingsPage({
              activeRunner: this.activeRunner,
              onOpenModels: () => {
                this.activeActivity = 'models'
              }
            })
          } else if (this.activeActivity === 'models') {
            ModelSettingsPage({
              activeRunner: this.activeRunner,
              isConnected: this.isConnected
            })
          } else if (this.activeActivity === 'server') {
            ServerSettingsPage({
              activeRunner: this.activeRunner,
              isConnected: this.isConnected,
              onRunnerActivated: (runner: Runner) => {
                this.onRunnerActivated(runner)
              },
              onReconnect: () => {
                this.onReconnect()
              }
            })
          } else if (this.activeActivity === 'runtime') {
            RuntimePage({
              activeRunner: this.activeRunner,
              isConnected: this.isConnected,
              onRunnerActivated: (runner: Runner) => {
                this.onRunnerActivated(runner)
              },
              onReconnect: () => {
                this.onReconnect()
              }
            })
          } else if (this.activeActivity === 'files') {
            FilePanel({
              projectName: this.projectName,
              branchName: this.branchName,
              activeRunner: this.activeRunner
            })
          } else if (this.activeActivity === 'settings') {
            SettingsPage()
          }

          // Composer (always visible at bottom of center)
          ComposerBar({
            inputText: this.inputText,
            isSending: this.isSending,
            modelLabel: this.modelName,
            sessionTitle: this.sessionTitle,
            agentMode: this.agentMode,
            tokensUsed: this.tokensUsed,
            tokensMax: this.tokensMax,
            onTextChange: (text: string) => {
              this.inputText = text
            },
            onSend: () => {
              this.onSend()
            },
            onAbort: () => {
              this.onAbort()
            },
            onModeChange: (mode: string) => {
              this.onModeChange(mode)
            },
            onModelClick: () => {
              this.onModelClick()
            }
          })
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(Theme.BG)

        // ══════════ Right Panel ══════════
        if (this.showRightPanel) {
          Column() {
            // Tab bar
            Row() {
              Text('tools')
                .fontSize(Theme.fs.xs)
                .fontColor(this.rightPanelTab === 'tools' ? Theme.ACCENT : Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(this.rightPanelTab === 'tools' ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
                .borderWidth({ bottom: 2 })
                .borderColor(this.rightPanelTab === 'tools' ? Theme.ACCENT : 'transparent')
                .onClick(() => { this.rightPanelTab = 'tools' })

              Text('diff')
                .fontSize(Theme.fs.xs)
                .fontColor(this.rightPanelTab === 'diff' ? Theme.ACCENT : Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(this.rightPanelTab === 'diff' ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
                .borderWidth({ bottom: 2 })
                .borderColor(this.rightPanelTab === 'diff' ? Theme.ACCENT : 'transparent')
                .onClick(() => { this.rightPanelTab = 'diff' })

              Text('logs')
                .fontSize(Theme.fs.xs)
                .fontColor(this.rightPanelTab === 'logs' ? Theme.ACCENT : Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(this.rightPanelTab === 'logs' ? FontWeight.Bold : FontWeight.Normal)
                .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
                .borderWidth({ bottom: 2 })
                .borderColor(this.rightPanelTab === 'logs' ? Theme.ACCENT : 'transparent')
                .onClick(() => { this.rightPanelTab = 'logs' })

              Blank()

              Text('x')
                .fontSize(Theme.fs.md)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .padding(Theme.sp.md)
                .onClick(() => { this.showRightPanel = false })
            }
            .width('100%')
            .borderWidth({ bottom: 1 })
            .borderColor(Theme.BORDER)

            // Panel content
            if (this.rightPanelTab === 'tools') {
              ToolTimelinePanel({
                entries: this.toolEntries
              })
            } else if (this.rightPanelTab === 'diff') {
              DiffPanel({
                diffs: this.diffs,
                sessionTitle: this.sessionTitle
              })
            } else {
              LogsPanel({
                entries: this.logEntries
              })
            }
          }
          .width(Theme.RIGHT_PANEL_W)
          .height('100%')
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth({ left: 1 })
          .borderColor(Theme.BORDER)
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)

    // Context menu overlay
    SessionContextMenu({
      visible: this.showContextMenu,
      sessionId: this.contextMenuSessionId,
      sessionTitle: '',
      positionX: this.contextMenuX,
      positionY: this.contextMenuY,
      onAction: (sid: string, action: string) => {
        this.onSessionAction(sid, action)
        this.showContextMenu = false
      },
      onDismiss: () => {
        this.showContextMenu = false
      }
    })

    // Toast notifications overlay
    ToastContainer({
      toasts: this.toasts,
      onDismiss: (id: string) => {
        ToastManager.dismiss(id)
      }
    })

    // Status popover overlay
    StatusPopover({
      visible: this.showStatusPopover,
      isConnected: this.isConnected,
      serverUrl: this.serverUrl,
      serverVersion: this.serverVersion,
      projectName: this.projectName,
      branchName: this.branchName,
      sessionCount: this.sessions.length,
      tokensUsed: this.tokensUsed,
      tokensMax: this.tokensMax,
      agentMode: this.agentMode,
      onDismiss: () => {
        this.showStatusPopover = false
      },
      onReconnect: () => {
        this.showStatusPopover = false
        this.onReconnect()
      }
    })

    // Directory picker overlay
    DirectoryPicker({
      visible: this.showDirectoryPicker,
      projects: this.projects,
      currentDirectory: this.projectName,
      onSelect: (directory: string) => {
        this.showDirectoryPicker = false
      },
      onDismiss: () => {
        this.showDirectoryPicker = false
      }
    })
    } // inner Stack
    } // outer Stack
  }

  // ══════════ Session Header (inside center column) ══════════
  @Builder
  SessionHeader() {
    Row() {
      Text('session')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)

      if (this.sessionTitle.length > 0) {
        Text('/')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .margin({ left: Theme.sp.sm, right: Theme.sp.sm })

        Text(this.sessionTitle)
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text('no session selected')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.sm })
      }

      Blank()

      if (this.isSending) {
        Row() {
          Circle({ width: 5, height: 5 })
            .fill(Theme.ACCENT)
            .margin({ right: Theme.sp.sm })
          Text('running')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
        }
      }

      // Toggle right panel
      if (!this.showRightPanel) {
        Text('[]')
          .fontSize(Theme.fs.sm)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.lg })
          .onClick(() => { this.showRightPanel = true })
      }
    }
    .width('100%')
    .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.md, bottom: Theme.sp.md })
    .borderWidth({ bottom: 1 })
    .borderColor(Theme.BORDER)
  }

}
