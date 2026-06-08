import { Runner } from '../models/Runner'
import { SessionInfo } from '../models/Event'
import { OpenCodeClient } from '../services/OpenCodeClient'

/**
 * 会话列表页面
 * 显示所有 AI 编程会话，支持新建、继续、删除
 */
@Component
export struct SessionPage {
  @Prop activeRunner: Runner | null = null
  @State sessions: SessionInfo[] = []
  @State isLoading: boolean = false
  @State errorMsg: string = ''
  onSelectSession: (sessionID: string) => void = () => {}

  async aboutToAppear(): Promise<void> {
    await this.loadSessions()
  }

  async loadSessions(): Promise<void> {
    if (this.activeRunner === null) return
    this.isLoading = true
    this.errorMsg = ''
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      this.sessions = await client.listSessions(50)
    } catch (e) {
      this.errorMsg = `加载失败: ${String(e)}`
    }
    this.isLoading = false
  }

  async createNewSession(): Promise<void> {
    if (this.activeRunner === null) return
    this.isLoading = true
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      const session = await client.createSession()
      this.onSelectSession(session.id)
    } catch (e) {
      this.errorMsg = `创建失败: ${String(e)}`
    }
    this.isLoading = false
  }

  async deleteSession(sessionID: string): Promise<void> {
    if (this.activeRunner === null) return
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      await client.deleteSession(sessionID)
      await this.loadSessions()
    } catch (e) {
      this.errorMsg = `删除失败: ${String(e)}`
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('AI 编程会话')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('+ 新建会话')
          .type(ButtonType.Capsule)
          .backgroundColor('#4F46E5')
          .fontColor('#FFFFFF')
          .fontSize(13)
          .enabled(!this.isLoading)
          .onClick(() => this.createNewSession())
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.activeRunner === null) {
        Column() {
          Text('请先连接 OpenCode Server')
            .fontSize(14)
            .fontColor('#94A3B8')
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else if (this.isLoading && this.sessions.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#4F46E5')
          Text('加载中...')
            .fontSize(13)
            .fontColor('#94A3B8')
            .margin({ top: 12 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else if (this.sessions.length === 0) {
        Column() {
          Text('💬')
            .fontSize(48)
          Text('还没有会话')
            .fontSize(14)
            .fontColor('#94A3B8')
            .margin({ top: 12 })
          Text('点击"新建会话"开始 AI 编程')
            .fontSize(13)
            .fontColor('#94A3B8')
            .margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        List() {
          ForEach(this.sessions, (session: SessionInfo) => {
            ListItem() {
              this.SessionCard(session)
            }
          }, (session: SessionInfo) => session.id)
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0 })
      }

      if (this.errorMsg !== '') {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#EF4444')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SessionCard(session: SessionInfo) {
    Row() {
      Column() {
        Row() {
          Text(session.title || '未命名会话')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E293B')
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.getStatusLabel('active'))
            .fontSize(10)
            .fontColor(this.getStatusColor('active'))
            .backgroundColor(this.getStatusBg('active'))
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        }
        .width('100%')

        Row() {
          if (session.model.modelID.length > 0) {
            Text(session.model.modelID)
              .fontSize(11)
              .fontColor('#64748B')
          }
          Blank()
          Text(this.formatTime(session.time.updated > 0 ? session.time.updated : session.time.created))
            .fontSize(11)
            .fontColor('#94A3B8')
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .layoutWeight(1)

      Column() {
        Button('打开')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(32)
          .backgroundColor('#4F46E5')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .onClick(() => this.onSelectSession(session.id))

        Button('删除')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(28)
          .backgroundColor('#FEE2E2')
          .fontColor('#EF4444')
          .borderRadius(8)
          .margin({ top: 6 })
          .onClick(() => this.deleteSession(session.id))
      }
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FAFBFC')
    .borderWidth(1)
    .borderColor('#E2E8F0')
    .margin({ bottom: 8 })
  }

  getStatusLabel(status: string): string {
    switch (status) {
      case 'idle': return '空闲'
      case 'running': return '运行中'
      case 'done': return '完成'
      case 'error': return '错误'
      default: return status
    }
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'running': return '#4F46E5'
      case 'done': return '#22C55E'
      case 'error': return '#EF4444'
      default: return '#64748B'
    }
  }

  getStatusBg(status: string): string {
    switch (status) {
      case 'running': return '#E0E7FF'
      case 'done': return '#DCFCE7'
      case 'error': return '#FEE2E2'
      default: return '#F1F5F9'
    }
  }

  formatTime(timestamp: number): string {
    if (timestamp <= 0) return ''
    try {
      const d = new Date(timestamp * 1000)
      const now = new Date()
      const diff = now.getTime() - d.getTime()
      if (diff < 60000) return 'just now'
      if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`
      if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`
      return `${d.getMonth() + 1}/${d.getDate()}`
    } catch (e) {
      return ''
    }
  }
}
