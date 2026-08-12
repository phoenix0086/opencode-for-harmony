import { Runner } from '../../models/Runner'
import { SessionInfo } from '../../model/AppState'
import { ProjectEntry } from '../DirectoryPicker'
import { formatRelativeTime, formatServerTitle } from '../../utils/DateTimeUtil'

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
  // 输入状态虽然 home 屏不直接用,但保留 props 供未来 Editor 区复用
  @Prop inputText: string = ''
  @Prop isSending: boolean = false

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
  @Prop hasMissingApiKey: boolean = false
  @State searchQuery: string = ''

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
  onOpenProviders: () => void = () => {}
  onConnectComputer: () => void = () => {}
  onOpenLocalRuntime: () => void = () => {}
  onOpenSession: (sessionId: string) => void = () => {}

  // 修复 W2: 删死代码 serverLabel/serverDotColor,CenterPane 不用了,
  // LocalServerButton 也已删。保留 serverName/isServerReady/isConnected
  // props 供未来 Server Status 弹层复用。
  private sessionCount(): string {
    return `${this.sessions.length}`
  }

  // 把 home 目录简写为 "~",例如 "/Users/foo/code" -> "~/code"
  // 修复 W1: 之前是空实现,长路径会溢出
  private shortenPath(path: string): string {
    if (path.length === 0) return ''
    // ArkTS 没有 process.env / os.homedir(),硬编码常见 home 前缀
    const homePrefixes: string[] = ['/Users/', '/home/']
    for (const prefix of homePrefixes) {
      const idx = path.indexOf(prefix)
      if (idx === 0) {
        // 找到下一个 "/" 之后替换为 "~"
        const rest = path.substring(prefix.length)
        const slashIdx = rest.indexOf('/')
        if (slashIdx > 0) {
          return '~' + rest.substring(slashIdx)
        }
        // 整段就是 home 本身
        return '~'
      }
    }
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

  private projectLabel(project: ProjectEntry): string {
    if (project.name.length > 0) return project.name
    const path = project.directory.length > 0 ? project.directory : project.worktree
    const parts = path.split('/')
    return parts.length > 0 ? parts[parts.length - 1] : path
  }

  private sessionLabel(session: SessionInfo): string {
    return session.title.length > 0 ? formatServerTitle(session.title) : '新会话'
  }

  private filteredSessions(): SessionInfo[] {
    if (this.searchQuery.trim().length === 0) return this.sessions
    const query = this.searchQuery.trim().toLowerCase()
    const result: SessionInfo[] = []
    for (let i = 0; i < this.sessions.length; i++) {
      const session = this.sessions[i]
      if (this.sessionLabel(session).toLowerCase().indexOf(query) >= 0) result.push(session)
    }
    return result
  }

  build() {
    Column() {
      this.DesktopTitleBar()
      Row() {
        this.ProjectSidebar()
        this.SessionHome()
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#101010')
  }

  @Builder
  DesktopTitleBar() {
    Row() {
      Row() {
        Circle().width(20).height(20).fill('#FF4D5A').margin({ right: 14 })
        Circle().width(20).height(20).fill('#FFBE2E').margin({ right: 14 })
        Circle().width(20).height(20).fill('#28C840')
      }
      .margin({ left: 18 })

      Button('▦')
        .width(52)
        .height(38)
        .fontSize(22)
        .fontColor('#FFFFFF')
        .backgroundColor('#2B2B2B')
        .borderRadius(8)
        .margin({ left: 28 })
        .onClick(() => this.onOpenDirectoryPicker())

      Button('+')
        .width(42)
        .height(38)
        .fontSize(24)
        .fontColor('#BEBEBE')
        .backgroundColor(Color.Transparent)
        .margin({ left: 8 })
        .onClick(() => this.onNewSession())

      Blank()

      Row() {
        Circle()
          .width(8)
          .height(8)
          .fill(this.isConnected ? '#42D77D' : '#777777')
        Text(this.isConnected ? '已连接电脑' : '未连接电脑')
          .fontSize(12)
          .fontColor('#A8A8A8')
          .margin({ left: 8 })
      }
      .margin({ right: 24 })
    }
    .width('100%')
    .height(60)
    .backgroundColor('#0D0D0D')
    .borderWidth({ bottom: 1 })
    .borderColor('#272727')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  ProjectSidebar() {
    Column() {
      Row() {
        Text('项目')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
        Button('+')
          .width(34)
          .height(30)
          .fontSize(20)
          .fontColor('#A7A7A7')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onOpenDirectoryPicker())
      }
      .width('100%')
      .padding({ left: 22, right: 16, top: 24, bottom: 12 })

      if (this.projects.length === 0) {
        Column() {
          Text(this.isConnected ? '电脑端暂无项目' : '连接电脑后显示项目')
            .fontSize(13)
            .fontColor('#8D8D8D')
            .textAlign(TextAlign.Center)
          if (!this.isConnected) {
            Button('连接电脑')
              .height(34)
              .fontSize(12)
              .fontColor('#FFFFFF')
              .backgroundColor('#2B2B2B')
              .borderRadius(7)
              .margin({ top: 14 })
              .onClick(() => this.onConnectComputer())
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 30 })
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.recentProjects(), (project: ProjectEntry) => {
              Row() {
                Text(this.projectLabel(project).substring(0, 1).toUpperCase())
                  .width(24)
                  .height(24)
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .textAlign(TextAlign.Center)
                  .backgroundColor(project.isActive ? '#5B4AA8' : '#5A5A5A')
                  .borderRadius(5)
                Text(this.projectLabel(project))
                  .fontSize(14)
                  .fontColor('#D8D8D8')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 10 })
              }
              .width('100%')
              .height(42)
              .padding({ left: 10, right: 10 })
              .backgroundColor(project.isActive ? '#3B3B3B' : Color.Transparent)
              .borderRadius(7)
              .onClick(() => this.onOpenProject(project.directory))
            }, (project: ProjectEntry) => project.directory)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
      }

      Column() {
        Button('⚙  设置')
          .width('100%')
          .height(40)
          .fontSize(14)
          .fontColor('#A8A8A8')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onOpenSettings())
        Button('?  帮助')
          .width('100%')
          .height(40)
          .fontSize(14)
          .fontColor('#A8A8A8')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onOpenHelp())
      }
      .width('100%')
      .padding({ left: 18, right: 18, bottom: 20 })
    }
    .width('22%')
    .constraintSize({ minWidth: 260, maxWidth: 520 })
    .height('100%')
    .backgroundColor('#151515')
    .borderWidth({ right: 1 })
    .borderColor('#292929')
  }

  @Builder
  SessionHome() {
    Column() {
      TextInput({ placeholder: '搜索会话', text: this.searchQuery })
        .width('72%')
        .height(42)
        .fontSize(14)
        .fontColor('#D7D7D7')
        .placeholderColor('#777777')
        .backgroundColor('#252525')
        .borderRadius(7)
        .onChange((value: string) => { this.searchQuery = value })
        .margin({ top: 56, bottom: 34 })

      Row() {
        Text('最近会话')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
        Button('✎  新建会话')
          .height(36)
          .fontSize(14)
          .fontColor('#D0D0D0')
          .backgroundColor(Color.Transparent)
          .onClick(() => this.onNewSession())
      }
      .width('78%')
      .margin({ bottom: 16 })

      if (!this.isConnected) {
        Column() {
          Text('连接电脑后显示最近会话')
            .fontSize(14)
            .fontColor('#8D8D8D')
          Button('连接电脑')
            .height(36)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .backgroundColor('#2B2B2B')
            .borderRadius(7)
            .margin({ top: 16 })
            .onClick(() => this.onConnectComputer())
        }
        .width('78%')
        .padding({ top: 60 })
        .alignItems(HorizontalAlign.Center)
      } else if (this.filteredSessions().length === 0) {
        Text('暂无会话')
          .fontSize(14)
          .fontColor('#777777')
          .width('78%')
          .padding({ top: 30 })
          .textAlign(TextAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredSessions(), (session: SessionInfo) => {
              Row() {
                Text(this.sessionLabel(session).substring(0, 1))
                  .width(26)
                  .height(26)
                  .fontSize(13)
                  .fontColor('#FFFFFF')
                  .textAlign(TextAlign.Center)
                  .backgroundColor('#5A5A5A')
                  .borderRadius(5)
                Text(this.sessionLabel(session))
                  .fontSize(15)
                  .fontColor('#E0E0E0')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 12 })
              }
              .width('78%')
              .height(52)
              .padding({ left: 12, right: 12 })
              .borderRadius(7)
              .onClick(() => this.onOpenSession(session.id))
            }, (session: SessionInfo) => session.id)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('78%')
        .scrollBar(BarState.Auto)
      }
      Blank()
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor('#151515')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  TitleBar() {
    // 顶部细条:左上一个 "打开历史项目" 按钮 (双竖线 split view 图标),
    // 用户要求 — 不再有 macOS 三个红黄绿圆点,也不再有 search/右栏图标
    Row() {
      // ── 打开历史项目 按钮 (双竖线图标) ──
      this.OpenHistoryButton()
      Blank()
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .backgroundColor('#101010')
    .borderWidth({ bottom: 1 })
    .borderColor('#292929')
  }

  @Builder
  OpenHistoryButton() {
    // 双竖线 split view 图标 (用户在图中给的样式:两个矩形描边 + 间隙)
    Row() {
      Row() {
        Rect()
          .width(7)
          .height(14)
          .fill('transparent')
          .stroke('#8a8a8a')
          .strokeWidth(1)

        Blank().width(3)

        Rect()
          .width(7)
          .height(14)
          .fill('transparent')
          .stroke('#8a8a8a')
          .strokeWidth(1)
      }
      .width(20)
      .height(14)

      Text('打开历史项目')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .margin({ left: 10 })
    }
    .height(32)
    .padding({ left: 10, right: 10 })
    .borderRadius(6)
    .backgroundColor('#1a1a1a')
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.onOpenDirectoryPicker())
  }

  @Builder
  ActivityRail() {
    // 用户要求:移除 ? 按钮;只剩 + (新建会话) + ⚙ (设置)
    Column() {
      Text(this.sessionCount())
        .fontSize(24)
        .fontColor('#FFFFFF')
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
        .fontColor('#FFFFFF')
        .width(52)
        .height(52)
        .textAlign(TextAlign.Center)
        .margin({ top: 18 })
        .onClick(() => this.onNewSession())

      Blank()

      Text('⚙')
        .fontSize(24)
        .fontColor('#FFFFFF')
        .width(52)
        .height(42)
        .textAlign(TextAlign.Center)
        .margin({ bottom: 20 })
        .onClick(() => this.onOpenSettings())
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
      // S1 fix: 缺 API key 时显示顶部 banner,引导用户去 Provider 设置
      if (this.hasMissingApiKey) {
        this.MissingApiKeyBanner()
      }

      // 上半部:居中 Logo (用户要求移除 Local Server 状态按钮)
      Column() {
        this.OpenCodeLogo()
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 两种工作方式。当前优先完成电脑端 OpenCode 连接；
      // 本地运行保留清晰入口，但不进入尚未完成的流程。
      this.WorkModeChoices()

      // 下半部:连接电脑后显示最近项目
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

  // 修复 W2: 删 LocalServerButton,CenterPane 顶部只留 Logo

  @Builder
  WorkModeChoices() {
    Column() {
      Text('选择使用方式')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .width('100%')
        .margin({ bottom: 10 })

      Row() {
        Column() {
          Row() {
            Text('连接电脑')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .layoutWeight(1)
            Text('当前主功能')
              .fontSize(10)
              .fontColor('#101010')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#78D98B')
              .borderRadius(10)
          }
          .width('100%')

          Text('连接电脑上的 OpenCode Server，在电脑端读取项目、运行命令和编译代码。')
            .fontSize(12)
            .fontColor('#B8B8B8')
            .lineHeight(18)
            .width('100%')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('›')
          .fontSize(24)
          .fontColor('#FFFFFF')
          .margin({ left: 14 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#1D2A22')
      .borderRadius(10)
      .borderWidth(1)
      .borderColor('#315E3B')
      .onClick(() => this.onConnectComputer())

      Row() {
        Column() {
          Row() {
            Text('本地运行')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor('#FFFFFF')
              .layoutWeight(1)
            Text('开发中')
              .fontSize(10)
              .fontColor('#D0D0D0')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#333333')
              .borderRadius(10)
          }
          .width('100%')

          Text('直接调用第三方模型 API，并在设备上管理项目和执行本地编译。后续版本开放。')
            .fontSize(12)
            .fontColor('#8F8F8F')
            .lineHeight(18)
            .width('100%')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .margin({ top: 10 })
      .backgroundColor('#181818')
      .borderRadius(10)
      .borderWidth(1)
      .borderColor('#2A2A2A')
      .opacity(0.82)
      .onClick(() => this.onOpenLocalRuntime())
    }
    .width('100%')
    .constraintSize({ maxWidth: 680 })
    .padding({ left: 24, right: 24, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  MissingApiKeyBanner() {
    // 顶部醒目 banner:警告色 + 简短说明 + "去配置" 按钮
    // 仅在 hasMissingApiKey === true 时由 CenterPane 渲染
    Row() {
      Text('⚠')
        .fontSize(16)
        .fontColor('#FFB454')
        .margin({ right: 10 })

      Text('默认 Provider 尚未配置 API key,无法发送消息')
        .fontSize(13)
        .fontColor('#FFFFFF')
        .layoutWeight(1)

      Text('去配置')
        .fontSize(12)
        .fontColor('#101010')
        .fontWeight(FontWeight.Medium)
        .height(28)
        .padding({ left: 12, right: 12 })
        .borderRadius(6)
        .backgroundColor('#FFB454')
        .onClick(() => this.onOpenProviders())
    }
    .width('100%')
    .height(44)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#2a1f0e')
    .borderWidth({ bottom: 1 })
    .borderColor('#3d2e15')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  OpenCodeLogo() {
    // 像素 opencode logo — 对应 opencode-dev 的 <Logo /> 组件
    //
    // 设计意图:
    //   - 用 monospace 字体 (像 'Major Mono Display' / 'Share Tech Mono') 渲染
    //   - 大字号 + Bold + 紧凑 letterSpacing,营造"块状/LED"质感
    //   - 用 #e8e4de (米白) + 0.12 opacity 模拟"水印/背景"效果
    //   - 居中显示
    //
    // ArkTS 没有自定义字体文件,所以我们用系统 monospace + 调字号
    // 接近 opencode 官方 logo 视觉效果。高级方案是把 logo SVG
    // 转成 Image 资源 (entry/src/main/resources/base/media/opencode_logo.svg)
    // 然后用 Image 渲染,这里先走纯文本方案。
    Text('opencode')
      .fontSize(96)
      .fontWeight(FontWeight.Bold)
      .fontFamily('monospace')
      .fontColor('#FFFFFF')
      .opacity(0.12)
      .letterSpacing(2)
      .textAlign(TextAlign.Center)
      .height(120)
      .width('100%')
  }

  @Builder
  RecentProjectsSection() {
    Column() {
      if (!this.isConnected) {
        // 工作模式入口已承担未连接引导，避免重复出现第二组操作按钮。
      } else if (this.projects.length > 0) {
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
        .fontColor('#FFFFFF')
        .layoutWeight(1)

      Row() {
        Text('+')
          .fontSize(16)
          .fontColor('#FFFFFF')
          .margin({ right: 6 })

        Text('打开项目')
          .fontSize(13)
          .fontColor('#FFFFFF')
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
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.projectRelativeTime(project))
            .fontSize(12)
            .fontColor('#FFFFFF')
            .margin({ left: 12 })
        }
        .width('100%')
        .height(40)
        .padding({ left: 12, right: 12 })
        .borderRadius(6)
        .backgroundColor(index === 0 ? '#1a1a1a' : 'transparent')
        .onClick(() => this.onOpenProject(project.directory))
      // 修复 S1: 单一稳定的 key (project.directory),不再用 id+index 复合 key,
      // 避免顺序变化时触发不必要的重渲染。fallback 到 index 防止空 id 崩溃
      }, (project: ProjectEntry, index: number) => {
        if (project.directory.length > 0) return project.directory
        return `idx_${index}`
      })
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
        .fontColor('#FFFFFF')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ConnectionRequiredState() {
    Column() {
      Text('尚未连接电脑')
        .fontSize(16)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)

      Text('先填写电脑上 OpenCode Server 的局域网地址')
        .fontSize(12)
        .fontColor('#FFFFFF')
        .margin({ top: 8 })

      Button('打开服务器设置')
        .height(36)
        .fontSize(13)
        .fontColor('#FFFFFF')
        .backgroundColor('#1f1f1f')
        .borderRadius(6)
        .margin({ top: 16 })
        .onClick(() => this.onOpenSettings())
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
        .fontColor('#FFFFFF')
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .borderRadius(22)
        .borderWidth(1)
        .borderColor('#2d2d2d')

      Text('打开一个项目开始使用')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .margin({ top: 14 })

      Text('选择电脑上已由 OpenCode 识别的项目')
        .fontSize(12)
        .fontColor('#FFFFFF')
        .margin({ top: 6 })

      Row() {
        Text('+')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .margin({ right: 6 })

        Text('打开项目')
          .fontSize(13)
          .fontColor('#FFFFFF')
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
