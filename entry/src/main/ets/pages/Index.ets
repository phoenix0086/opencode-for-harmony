import { Runner, createRunner, RunnerConfig } from '../models/Runner'
import { OpenCodeClient, HealthResult } from '../services/OpenCodeClient'
import { storageService } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'
import { WorkspacePage } from './WorkspacePage'
import { ServerConnectionPage } from './ServerConnectionPage'
import { SessionPage } from './SessionPage'
import { ChatAgentPage } from './ChatAgentPage'
import { DiffReviewPage } from './DiffReviewPage'
import { ProviderPage } from './ProviderPage'
import { SettingsPage } from './SettingsPage'

/**
 * 导航项
 */
class NavItem {
  label: string = ''
  icon: string = ''
  page: string = ''
}

/**
 * 主页面 - 导航中枢
 * 左侧导航栏 + 右侧内容区，集成所有子页面
 */
@Entry
@Component
struct Index {
  @State currentPage: string = 'home'
  @State runners: Runner[] = []
  @State activeRunner: Runner | null = null
  @State connectionStatus: string = ''
  @State isInitialized: boolean = false
  @State recentWorkspaces: string[] = []
  @State currentSessionId: string = ''
  @State currentDiffSessionId: string = ''

  private navItems: NavItem[] = []

  async aboutToAppear(): Promise<void> {
    // 初始化导航
    const item1 = new NavItem()
    item1.label = '工作台'; item1.icon = '🏠'; item1.page = 'home'
    const item2 = new NavItem()
    item2.label = '服务器'; item2.icon = '🖥'; item2.page = 'server'
    const item3 = new NavItem()
    item3.label = '会话'; item3.icon = '💬'; item3.page = 'sessions'
    const item4 = new NavItem()
    item4.label = 'Provider'; item4.icon = '🤖'; item4.page = 'provider'
    const item5 = new NavItem()
    item5.label = 'Diff'; item5.icon = '📋'; item5.page = 'diff'
    const item6 = new NavItem()
    item6.label = '设置'; item6.icon = '⚙'; item6.page = 'settings'
    this.navItems = [item1, item2, item3, item4, item5, item6]

    // 加载数据
    await this.loadData()
  }

  async loadData(): Promise<void> {
    try {
      await storageService.init(getContext(this) as Context)
      this.runners = await storageService.loadRunners()
      this.recentWorkspaces = await storageService.getRecentWorkspaces()

      const activeId = await storageService.getActiveRunnerId()
      if (activeId) {
        for (const r of this.runners) {
          if (r.id === activeId) {
            this.activeRunner = r
            break
          }
        }
      }

      // 初始化 Provider 注册表
      await providerRegistry.init()
    } catch (e) {
      this.connectionStatus = `初始化失败: ${String(e)}`
    }
    this.isInitialized = true
  }

  build() {
    if (!this.isInitialized) {
      // 加载中
      Column() {
        LoadingProgress()
          .width(48)
          .height(48)
          .color('#4F46E5')
        Text('OpenCode Harmony Native')
          .fontSize(16)
          .fontColor('#64748B')
          .margin({ top: 16 })
        Text('加载中...')
          .fontSize(13)
          .fontColor('#94A3B8')
          .margin({ top: 8 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Row() {
        // ══════════ 左侧导航栏 ══════════
        Column() {
          // Logo
          Column() {
            Text('OpenCode')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#4F46E5')
            Text('Harmony')
              .fontSize(11)
              .fontColor('#94A3B8')
              .margin({ top: 2 })
          }
          .margin({ top: 16, bottom: 24 })

          // 导航项
          ForEach(this.navItems, (item: NavItem) => {
            Column() {
              Text(item.icon)
                .fontSize(20)
              Text(item.label)
                .fontSize(10)
                .margin({ top: 4 })
                .fontColor(this.currentPage === item.page ? '#4F46E5' : '#64748B')
            }
            .width(64)
            .padding({ top: 10, bottom: 10 })
            .borderRadius(12)
            .backgroundColor(this.currentPage === item.page ? '#E0E7FF' : 'transparent')
            .onClick(() => {
              this.currentPage = item.page
            })
            .margin({ bottom: 4 })
          }, (item: NavItem) => item.page)

          Blank()

          // 底部状态指示
          if (this.activeRunner !== null) {
            Column() {
              Circle({ width: 8, height: 8 })
                .fill(this.activeRunner!.status === 'online' ? '#22C55E' : '#EF4444')
              Text(this.activeRunner!.name)
                .fontSize(9)
                .fontColor('#64748B')
                .maxLines(1)
                .constraintSize({ maxWidth: 60 })
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ top: 4 })
            }
            .margin({ bottom: 16 })
          }
        }
        .width(80)
        .height('100%')
        .backgroundColor('#F8FAFC')
        .alignItems(HorizontalAlign.Center)
        .borderWidth({ right: 1 })
        .borderColor('#E2E8F0')

        // ══════════ 右侧内容区 ══════════
        Column() {
          if (this.currentPage === 'home') {
            WorkspacePage({
              activeRunner: this.activeRunner,
              connectionStatus: this.connectionStatus,
              recentWorkspaces: this.recentWorkspaces,
              onNavigate: (page: string) => {
                this.currentPage = page
              }
            })
          } else if (this.currentPage === 'server') {
            ServerConnectionPage({
              runners: $runners,
              activeRunner: $activeRunner
            })
          } else if (this.currentPage === 'sessions') {
            SessionPage({
              activeRunner: this.activeRunner,
              onSelectSession: (sessionID: string) => {
                this.currentSessionId = sessionID
                this.currentPage = 'chat'
              }
            })
          } else if (this.currentPage === 'chat') {
            ChatAgentPage({
              activeRunner: this.activeRunner,
              sessionId: this.currentSessionId
            })
          } else if (this.currentPage === 'diff') {
            DiffReviewPage({
              activeRunner: this.activeRunner,
              sessionId: this.currentDiffSessionId || this.currentSessionId
            })
          } else if (this.currentPage === 'provider') {
            ProviderPage({
              activeRunner: this.activeRunner
            })
          } else if (this.currentPage === 'settings') {
            SettingsPage()
          }
        }
        .layoutWeight(1)
        .height('100%')
        .padding(20)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
    }
  }
}
