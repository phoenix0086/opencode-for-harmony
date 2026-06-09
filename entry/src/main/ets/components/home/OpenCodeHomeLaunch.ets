import { Runner } from '../../models/Runner'
import { SessionInfo } from '../../models/Event'
import { ProjectEntry } from '../DirectoryPicker'
import { formatRelativeTime } from '../../utils/DateTimeUtil'

/**
 * OpenCodeHomeLaunch
 *
 * Home 全屏布局，移植自 opencode-dev LegacyHome (packages/app/src/pages/home.tsx)。
 *
 * 三段式结构：
 * - TitleBar：macOS 红黄绿按钮 + 布局切换 + 搜索 + 服务器状态
 * - ActivityRail：左侧 0/紫色会话徽章、+、⚙、?（与 opencode 旧版对齐）
 * - CenterPane：居中像素 opencode Logo + Local Server 状态按钮 + 最近项目列表
 *
 * 与 opencode-dev LegacyHome 的对应关系：
 * - 大 Logo  + Local Server  → CenterPane 顶部 Stack
 * - 状态点（绿/灰/红）       → isConnected
 * - "最近项目" + "打开项目"  → 最近项目区
 * - ForEach project 项       → 包含 worktree（~ 简写）+ formatRelativeTime
 * - 空项目状态               → folder-add-left 图标 + 文案 + 打开项目按钮
 * - loading 状态             → 居中转圈
 *
 * 行为映射：
 * - 0 紫色徽章：跳到 chat 工作区（onOpenChat）
 * - 左 +：onNewSession
 * - ⚙：onOpenSettings
 * - ?：onOpenHelp
 * - 顶部搜索：onOpenDirectoryPicker
 * - 服务器图标：onOpenServerStatus
 * - Local Server 按钮：onOpenServerStatus
 * - "打开项目" 按钮：onOpenDirectoryPicker
 * - 单个最近项目：onOpenProject(directory) — 通过 onOpenDirectoryPicker 路由
 */
@Component
export struct OpenCodeHomeLaunch {
  @Link inputText: string
  @Link isSending: boolean

  @Prop activeRunner: Runner | null = null
  @Prop sessions: SessionInfo[] = []
  @Prop projectName: string = ''
  @Prop projectPath: string = ''
  @Prop branchName: string = ''
  @Prop modelName: string = ''
  @Prop isConnected: boolean = false
  @Prop serverVersion: string = ''
  @Prop projects: ProjectEntry[] = []
  @Prop serverName: string = 'Local Server'
  @Prop isServerReady: boolean = false

  onInputChange: (value: string) => void = () => {}
  onSend: () => void = () => {}
  onAbort: () => void = () => {}
  onNewSession: () => void = () => {}
  onOpenChat: () => void = () => {}
  onOpenSettings: () => void = () => {}
  onOpenHelp: () => void = () => {}
  onOpenDirectoryPicker: () => void = () => {}
  onOpenServerStatus: () => void = () => {}
  onOpenRightPanel: () => void = () => {}
  onOpenFiles: () => void = () => {}
  onOpenModels: () => void = () => {}
  onOpenProject: (directory: string) => void = () => {}

  private serverLabel(): string {
    if (this.serverName.length > 0) return this.serverName
    if (this.activeRunner !== null) {
      return `${this.activeRunner.protocol}://${this.activeRunner.host}:${this.activeRunner.port}`
    }
    return 'Local Server'
  }

  private serverDotColor(): string {
    if (!this.isServerReady) return '#5a5a5a'
    if (this.isConnected) return '#3dd24a'
    return '#d24a3d'
  }

  private sessionCount(): string {
    return `${this.sessions.length}`
  }

  // 把 "~" 简写 home 替换前缀，对应 opencode home.tsx 的 worktree.replace(homedir(), "~")
  private shortenPath(path: string): string {
    return path
  }

  private projectRelativeTime(project: ProjectEntry): string {
    if (project.lastOpened.length > 0) {
      const label: string = formatRelativeTime(project.lastOpened)
      if (label.length > 0) return label
    }
    return ''
  }

  // 按最近打开时间排序（最近的在最上），取前 5 条
  private recentProjects(): ProjectEntry[] {
    const list: ProjectEntry[] = []
    for (const p of this.projects) {
      list.push(p)
    }
    list.sort((a: ProjectEntry, b: ProjectEntry) => {
      const at: number = a.lastOpened.length > 0 ? Date.parse(a.lastOpened) : 0
      const bt: number = b.lastOpened.length > 0 ? Date.parse(b.lastOpened) : 0
      return bt - at
    })
    if (list.length > 5) {
      return list.slice(0, 5)
    }
    return list
  }

  build() {
    Column() {
      this.TitleBar()

      Row() {
        this.ActivityRail()
        this.CenterPane()
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#101010')
  }

  @Builder
  TitleBar() {
    Row() {
      Row() {
        Circle().width(14).height(14).fill('#ff5f57')
        Circle().width(14).height(14).fill('#ffbd2e').margin({ left: 10 })
        Circle().width(14).height(14).fill('#28c840').margin({ left: 10 })
      }
      .width(120)
      .padding({ left: 14 })

      Row() {
        Text('▥')
          .fontSize(20)
          .fontColor('#8a8a8a')
          .width(36)
          .textAlign(TextAlign.Center)

        Text('✎')
          .fontSize(18)
          .fontColor('#d0d0d0')
          .width(36)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2b2b2b')
          .borderRadius(7)
          .onClick(() => this.onOpenChat())

        Text('‹')
          .fontSize(28)
          .fontColor('#777')
          .width(28)
          .textAlign(TextAlign.Center)

        Text('›')
          .fontSize(28)
          .fontColor('#444')
          .width(28)
          .textAlign(TextAlign.Center)
      }
      .width(150)

      Row() {
        Text(`搜索 ${this.projectName.length > 0 ? this.projectName : 'workspace'}`)
          .fontSize(14)
          .fontColor('#666')
          .layoutWeight(1)

        Text('⌘K')
          .fontSize(12)
          .fontColor('#555')
      }
      .width(310)
      .height(31)
      .padding({ left: 12, right: 12 })
      .borderRadius(8)
      .borderWidth(1)
      .borderColor('#292929')
      .backgroundColor('#0c0c0c')
      .onClick(() => this.onOpenDirectoryPicker())

      Blank()

      Row() {
        Stack() {
          Text('▤')
            .fontSize(20)
            .fontColor('#8a8a8a')
            .width(36)
            .textAlign(TextAlign.Center)

          if (this.isConnected) {
            Circle()
              .width(8)
              .height(8)
              .fill('#3dd24a')
              .position({ x: 26, y: 2 })
          }
        }
        .width(36)
        .height(30)
        .onClick(() => this.onOpenServerStatus())

        Text('▥')
          .fontSize(20)
          .fontColor('#d0d0d0')
          .width(36)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor('#2b2b2b')
          .borderRadius(7)
          .margin({ left: 10 })
          .onClick(() => this.onOpenRightPanel())
      }
      .padding({ right: 14 })
    }
    .width('100%')
    .height(52)
    .borderWidth({ bottom: 1 })
    .borderColor('#292929')
    .backgroundColor('#101010')
  }

  @Builder
  ActivityRail() {
    Column() {
      Text(this.sessionCount())
        .fontSize(24)
        .fontColor('#d8b8ff')
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .backgroundColor('#4b2170')
        .borderRadius(10)
        .borderWidth(3)
        .borderColor('#dedede')
        .margin({ top: 16 })
        .onClick(() => this.onOpenChat())

      Text('+')
        .fontSize(34)
        .fontColor('#8d8d8d')
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })
        .onClick(() => this.onNewSession())

      Blank()

      Text('⚙')
        .fontSize(24)
        .fontColor('#8d8d8d')
        .width(52)
        .height(42)
        .textAlign(TextAlign.Center)
        .onClick(() => this.onOpenSettings())

      Text('?')
        .fontSize(22)
        .fontColor('#8d8d8d')
        .width(52)
        .height(42)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })
        .onClick(() => this.onOpenHelp())
    }
    .width(82)
    .height('100%')
    .backgroundColor('#111111')
    .borderWidth({ right: 1 })
    .borderColor('#292929')
  }

  @Builder
  CenterPane() {
    Column() {
      // 上半部：居中 Logo + Local Server 状态
      Column() {
        this.OpenCodeLogo()
        this.LocalServerButton()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 下半部：最近项目
      Column() {
        this.RecentProjectsSection()
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 24 })
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor('#111111')
  }

  @Builder
  OpenCodeLogo() {
    // 像素 opencode logo (低透明度，居中显示)
    // 对应 opencode-dev <Logo class="md:w-xl opacity-12" />
    Stack() {
      Rect()
        .width(280)
        .height(96)
        .fill('#e8e4de')
        .opacity(0.12)
        .borderRadius(6)

      Rect()
        .width(60)
        .height(60)
        .fill('#111111')
        .margin({ top: 18 })
    }
    .width(280)
    .height(96)
  }

  @Builder
  LocalServerButton() {
    Row() {
      Circle()
        .width(8)
        .height(8)
        .fill(this.serverDotColor())

      Text(this.serverLabel())
        .fontSize(14)
        .fontColor('#a8a8a8')
        .margin({ left: 10 })
    }
    .height(36)
    .padding({ left: 14, right: 14 })
    .borderRadius(18)
    .backgroundColor('#1a1a1a')
    .margin({ top: 24 })
    .onClick(() => this.onOpenServerStatus())
  }

  @Builder
  RecentProjectsSection() {
    Column() {
      if (this.projects.length > 0) {
        this.RecentProjectsHeader()
        this.RecentProjectsList()
      } else if (!this.isServerReady) {
        this.LoadingState()
      } else {
        this.EmptyState()
      }
    }
    .width('100%')
  }

  @Builder
  RecentProjectsHeader() {
    Row() {
      Text('最近项目')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#e8e2dd')
        .layoutWeight(1)

      Row() {
        Text('+')
          .fontSize(16)
          .fontColor('#a8a8a8')
          .margin({ right: 6 })

        Text('打开项目')
          .fontSize(13)
          .fontColor('#a8a8a8')
      }
      .height(32)
      .padding({ left: 12, right: 12 })
      .borderRadius(6)
      .backgroundColor('#1a1a1a')
      .onClick(() => this.onOpenDirectoryPicker())
    }
    .width('100%')
    .height(36)
    .padding({ left: 12, right: 8 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  RecentProjectsList() {
    Column() {
      ForEach(this.recentProjects(), (project: ProjectEntry, index: number) => {
        Row() {
          Text(this.shortenPath(project.directory.length > 0 ? project.directory : project.worktree))
            .fontSize(13)
            .fontColor('#c8c8c8')
            .fontFamily('monospace')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.projectRelativeTime(project))
            .fontSize(12)
            .fontColor('#7a7a7a')
            .margin({ left: 12 })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(6)
        .backgroundColor(index === 0 ? '#1a1a1a' : 'transparent')
        .onClick(() => this.onOpenProject(project.directory))
      }, (project: ProjectEntry, index: number) => project.id + '_' + index)
    }
    .width('100%')
    .margin({ top: 8 })
  }

  @Builder
  LoadingState() {
    Column() {
      LoadingProgress()
        .width(24)
        .height(24)
        .color('#7a7a7a')

      Text('加载中…')
        .fontSize(12)
        .fontColor('#7a7a7a')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EmptyState() {
    Column() {
      Text('+')
        .fontSize(28)
        .fontColor('#5a5a5a')
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(22)
        .borderWidth(1)
        .borderColor('#2d2d2d')

      Text('打开一个项目开始使用')
        .fontSize(14)
        .fontColor('#cfcfcf')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 14 })

      Text('选择一个本地目录作为工作区')
        .fontSize(12)
        .fontColor('#7a7a7a')
        .margin({ top: 6 })

      Row() {
        Text('+')
          .fontSize(14)
          .fontColor('#cfcfcf')
          .margin({ right: 6 })

        Text('打开项目')
          .fontSize(13)
          .fontColor('#cfcfcf')
      }
      .height(34)
      .padding({ left: 14, right: 14 })
      .borderRadius(6)
      .backgroundColor('#1f1f1f')
      .margin({ top: 16 })
      .onClick(() => this.onOpenDirectoryPicker())
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }
}
