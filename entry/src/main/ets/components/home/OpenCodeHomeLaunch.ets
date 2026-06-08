import { Runner } from '../../models/Runner'
import { SessionInfo } from '../../models/Event'
import { ProjectEntry } from '../DirectoryPicker'

/**
 * OpenCodeHomeLaunch
 *
 * Functional home screen based on the original OpenCode Desktop layout.
 *
 * Mapping to real app behavior:
 * - Left purple session badge: shows session count and opens chat area.
 * - Left plus: creates a new OpenCode session through onNewSession().
 * - Gear: opens settings through onOpenSettings().
 * - Help: opens logs/help area through onOpenHelp().
 * - Top search: opens project/directory picker through onOpenDirectoryPicker().
 * - Server icon: opens server/status panel through onOpenServerStatus().
 * - Center project title/path/branch: bound to projectName/projectPath/branchName.
 * - Composer text: bound to Index.inputText.
 * - Send: calls Index.sendMessage(); Index patch auto-creates session if needed.
 * - Model picker: opens model settings through onOpenModels().
 * - Right pane plus/empty state: opens files area through onOpenFiles().
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

  private displayProjectName(): string {
    if (this.projectName.length > 0) return this.projectName
    return '构建任何东西'
  }

  private displayProjectPath(): string {
    if (this.projectPath.length > 0) return this.projectPath
    if (this.activeRunner !== null) return `${this.activeRunner.protocol}://${this.activeRunner.host}:${this.activeRunner.port}`
    return '未连接 OpenCode Server'
  }

  private displayBranch(): string {
    if (this.branchName.length > 0) return this.branchName
    return '未加载分支'
  }

  private displayModel(): string {
    if (this.modelName.length > 0) return this.modelName
    return '选择模型'
  }

  private sessionCount(): string {
    return `${this.sessions.length}`
  }

  build() {
    Column() {
      this.TitleBar()

      Row() {
        this.ActivityRail()
        this.CenterPane()
        this.RightPane()
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
    Stack() {
      Column() {
        this.OpenCodeLogo(false)

        Text(this.displayProjectName())
          .fontSize(27)
          .fontWeight(FontWeight.Bold)
          .fontColor('#e8e2dd')
          .margin({ top: 32 })

        Text(this.displayProjectPath())
          .fontSize(18)
          .fontColor('#858585')
          .margin({ top: 24 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          Text('⌘')
            .fontSize(16)
            .fontColor('#777')

          Text(this.displayBranch())
            .fontSize(16)
            .fontColor('#777')
            .margin({ left: 10 })
        }
        .margin({ top: 28 })
      }
      .alignItems(HorizontalAlign.Center)
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)

      this.Composer()
    }
    .layoutWeight(1)
    .height('100%')
    .backgroundColor('#111111')
    .borderWidth({ right: 1 })
    .borderColor('#292929')
  }

  @Builder
  Composer() {
    Column() {
      Stack() {
        TextArea({ text: this.inputText, placeholder: '随便问点什么... “重构这个函数，让它更易读”' })
          .width('100%')
          .height(116)
          .fontSize(16)
          .fontColor('#e8e2dd')
          .placeholderColor('#757575')
          .backgroundColor('#111111')
          .padding({ left: 18, right: 64, top: 18, bottom: 18 })
          .onChange((v: string) => {
            this.onInputChange(v)
          })

        Text('+')
          .fontSize(34)
          .fontColor('#8a8a8a')
          .position({ x: 20, y: 70 })

        if (this.isSending) {
          Text('×')
            .fontSize(23)
            .fontColor('#eeeeee')
            .width(44)
            .height(42)
            .textAlign(TextAlign.Center)
            .borderRadius(7)
            .backgroundColor('#7a2f3a')
            .position({ x: 690, y: 64 })
            .onClick(() => this.onAbort())
        } else {
          Text('↑')
            .fontSize(23)
            .fontColor('#171717')
            .width(44)
            .height(42)
            .textAlign(TextAlign.Center)
            .borderRadius(7)
            .backgroundColor(this.inputText.trim().length > 0 ? '#8d8d8d' : '#606060')
            .position({ x: 690, y: 64 })
            .onClick(() => {
              if (this.inputText.trim().length > 0) {
                this.onSend()
              }
            })
        }
      }
      .height(116)
      .borderWidth({ bottom: 1 })
      .borderColor('#292929')

      Row() {
        Text('⌄')
          .fontSize(16)
          .fontColor('#666')

        Text(this.displayModel())
          .fontSize(16)
          .fontColor('#8e8e8e')
          .margin({ left: 22 })

        Text('⌄')
          .fontSize(16)
          .fontColor('#666')
          .margin({ left: 22 })
      }
      .height(58)
      .width('100%')
      .padding({ left: 36 })
      .backgroundColor('#111111')
      .onClick(() => this.onOpenModels())
    }
    .width(746)
    .height(175)
    .margin({ left: 0, bottom: 14 })
    .borderRadius(14)
    .borderWidth(1)
    .borderColor('#2d2d2d')
    .backgroundColor('#111111')
  }

  @Builder
  RightPane() {
    Column() {
      Row() {
        Text('+')
          .fontSize(32)
          .fontColor('#8d8d8d')
          .width(64)
          .height(62)
          .textAlign(TextAlign.Center)
          .borderWidth({ right: 1 })
          .borderColor('#292929')
          .onClick(() => this.onOpenFiles())
      }
      .width('100%')
      .height(62)
      .borderWidth({ bottom: 1 })
      .borderColor('#292929')

      Column() {
        this.OpenCodeLogo(true)

        Text('选择要打开的文件')
          .fontSize(18)
          .fontColor('#6d6d6d')
          .margin({ top: 34 })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => this.onOpenFiles())
    }
    .layoutWeight(0.95)
    .height('100%')
    .backgroundColor('#111111')
  }

  @Builder
  OpenCodeLogo(dim: boolean) {
    Stack() {
      Rect()
        .width(dim ? 74 : 54)
        .height(dim ? 90 : 66)
        .fill(dim ? '#282828' : '#e8e4de')

      Rect()
        .width(dim ? 36 : 26)
        .height(dim ? 54 : 38)
        .fill('#111111')
    }
  }
}
