import { Theme } from './Theme'
import { SessionInfo } from '../models/Event'

/**
 * 会话侧边栏
 * 左侧面板：显示会话列表 + 工作区信息
 */

class SidebarSession {
  id: string = ''
  title: string = ''
  status: string = ''
  updatedAt: string = ''
  isActive: boolean = false
}

@Component
export struct SessionSidebar {
  @Prop workspaceName: string = 'Workspace'
  @Prop sessions: SessionInfo[] = []
  @Prop activeSessionId: string = ''
  onSelectSession: (id: string) => void = () => {}
  onNewSession: () => void = () => {}

  build() {
    Column() {
      // Header
      Row() {
        Text('SESSIONS')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        // New session button
        Text('+')
          .fontSize(Theme.fs.lg)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .onClick(() => {
            this.onNewSession()
          })
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.lg, bottom: Theme.sp.md })

      // Workspace label
      Row() {
        Text('~/')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
        Text(this.workspaceName)
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_SECONDARY)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.xs })
          .maxLines(1)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, bottom: Theme.sp.lg })

      // Divider
      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      // Session list
      List() {
        ForEach(this.sessions, (session: SessionInfo) => {
          ListItem() {
            Row() {
              // Active indicator
              Column()
                .width(2)
                .height(24)
                .backgroundColor(this.activeSessionId === session.id ? Theme.ACCENT : 'transparent')
                .borderRadius(1)
                .margin({ right: Theme.sp.md })

              Column() {
                Text(session.title.length > 0 ? session.title : 'untitled')
                  .fontSize(Theme.fs.md)
                  .fontColor(this.activeSessionId === session.id ? Theme.TEXT_PRIMARY : Theme.TEXT_SECONDARY)
                  .fontWeight(this.activeSessionId === session.id ? FontWeight.Medium : FontWeight.Normal)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Row() {
                  // Status badge
                  Text(session.status)
                    .fontSize(Theme.fs.xs)
                    .fontColor(this.getStatusColor(session.status))
                    .fontFamily(Theme.FONT_MONO)

                  if (session.time.updated.length > 0) {
                    Text(session.time.updated)
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.TEXT_MUTED)
                      .margin({ left: Theme.sp.md })
                  }
                }
                .margin({ top: Theme.sp.xs })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
            .backgroundColor(this.activeSessionId === session.id ? Theme.ACTIVE_BG : 'transparent')
            .borderRadius(Theme.rd.md)
            .onClick(() => {
              this.onSelectSession(session.id)
            })
          }
        }, (session: SessionInfo) => session.id)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0 })
      .scrollBar(BarState.Off)
      .backgroundColor('transparent')

      // Bottom: Quick actions
      Column() {
        Divider()
          .color(Theme.BORDER)
          .strokeWidth(1)
          .margin({ bottom: Theme.sp.md })

        Row() {
          Text('[N] New')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Blank()
          Text('[/] Search')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
        }
        .width('100%')
        .padding({ left: Theme.sp.lg, right: Theme.sp.lg, bottom: Theme.sp.lg })
      }
    }
    .width(Theme.SIDEBAR_W)
    .height('100%')
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth({ right: 1 })
    .borderColor(Theme.BORDER)
  }

  private getStatusColor(status: string): string {
    if (status === 'running' || status === 'active') return Theme.SUCCESS
    if (status === 'error') return Theme.DANGER
    if (status === 'idle') return Theme.TEXT_MUTED
    return Theme.TEXT_MUTED
  }
}
