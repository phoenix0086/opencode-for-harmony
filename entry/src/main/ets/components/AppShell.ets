import { Theme } from './Theme'
import { Runner } from '../models/Runner'
import { SessionInfo, FileDiff, PermissionRequest } from '../models/Event'
import { LeftActivityBar } from './LeftActivityBar'
import { TopStatusBar } from './TopStatusBar'
import { SessionSidebar } from './SessionSidebar'
import { AgentTranscript, TranscriptBlock } from './AgentTranscript'
import { ComposerBar } from './ComposerBar'
import { ToolTimelinePanel, ToolTimelineEntry } from './ToolTimelinePanel'
import { DiffPanel } from './DiffPanel'
import { FilePanel } from './FilePanel'
import { LogsPanel } from './LogsPanel'
import { ProviderPage } from '../pages/ProviderPage'
import { SettingsPage } from '../pages/SettingsPage'

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
  @Prop logEntries: string[] = []

  // ══════════ Callbacks ══════════
  onSelectSession: (id: string) => void = () => {}
  onNewSession: () => void = () => {}
  onSend: () => void = () => {}
  onAbort: () => void = () => {}
  onApprovePermission: (id: string) => void = () => {}
  onRejectPermission: (id: string) => void = () => {}

  @State showRightPanel: boolean = true
  @State rightPanelTab: string = 'tools' // 'tools' | 'diff' | 'logs'

  build() {
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

      // ══════════ Main Content Area ══════════
      Row() {
        // Left: Activity Bar
        LeftActivityBar({
          activeId: this.activeActivity,
          connectionStatus: this.connectionStatus,
          onActivityChange: (id: string) => {
            this.activeActivity = id
          }
        })

        // Left: Sidebar
        SessionSidebar({
          workspaceName: this.projectName.length > 0 ? this.projectName : 'workspace',
          sessions: this.sessions,
          activeSessionId: this.activeSessionId,
          onSelectSession: (id: string) => {
            this.onSelectSession(id)
            this.activeActivity = 'chat'
          },
          onNewSession: () => {
            this.onNewSession()
          }
        })

        // ══════════ Center: Main Content + Composer ══════════
        Column() {
          // Center content area
          if (this.activeActivity === 'chat') {
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
              }
            })
          } else if (this.activeActivity === 'diff') {
            DiffPanel({
              diffs: this.diffs,
              sessionTitle: this.sessionTitle
            })
          } else if (this.activeActivity === 'provider') {
            ProviderPage({ activeRunner: this.activeRunner })
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
            onTextChange: (text: string) => {
              this.inputText = text
            },
            onSend: () => {
              this.onSend()
            },
            onAbort: () => {
              this.onAbort()
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
