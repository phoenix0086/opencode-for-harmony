import { Runner } from '../../models/Runner'
import { SessionInfo } from '../../model/AppState'
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

      // 下半部:最近项目
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

      Text('选择一个本地目录作为工作区')
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
