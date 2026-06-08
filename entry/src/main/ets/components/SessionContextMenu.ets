import { Theme } from './Theme'

/**
 * Session context menu action model
 */
export class SessionAction {
  label: string = ''
  icon: string = ''
  action: string = '' // 'fork' | 'share' | 'rename' | 'delete'
  danger: boolean = false

  constructor(label: string = '', icon: string = '', action: string = '', danger: boolean = false) {
    this.label = label
    this.icon = icon
    this.action = action
    this.danger = danger
  }
}

/**
 * Session context menu
 * Floating menu for session actions: Fork, Share, Rename, Delete
 */
@Component
export struct SessionContextMenu {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop visible: boolean = false
  @Prop sessionId: string = ''
  @Prop sessionTitle: string = ''
  @Prop positionX: number = 0
  @Prop positionY: number = 0
  onAction: (sessionId: string, action: string) => void = () => {}
  onDismiss: () => void = () => {}

  private menuItems: SessionAction[] = [
    new SessionAction('Fork session', '\u2442', 'fork', false),
    new SessionAction('Share session', '\u2197', 'share', false),
    new SessionAction('Rename', '\u270E', 'rename', false),
    new SessionAction('Delete session', '\u2715', 'delete', true),
  ]

  build() {
    if (this.visible) {
      Stack() {
        // Backdrop to catch taps outside the menu
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#00000000')
          .onClick(() => {
            this.onDismiss()
          })

        // Menu card
        Column() {
          ForEach(this.menuItems, (item: SessionAction, index: number) => {
            if (index === 3) {
              // Divider before the delete action
              Divider()
                .color(Theme.BORDER)
                .strokeWidth(1)
                .margin({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
            }

            Row() {
              Text(item.icon)
                .fontSize(Theme.fs.md)
                .fontColor(item.danger ? Theme.DANGER : Theme.TEXT_SECONDARY)
                .fontFamily(Theme.FONT_MONO)
                .width(24)
                .textAlign(TextAlign.Center)

              Text(item.label)
                .fontSize(Theme.fs.md)
                .fontColor(item.danger ? Theme.DANGER : Theme.TEXT_PRIMARY)
                .margin({ left: Theme.sp.md })
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
            .borderRadius(Theme.rd.sm)
            .onClick(() => {
              this.onAction(this.sessionId, item.action)
              this.onDismiss()
            })
          }, (item: SessionAction, index: number) => item.action + '_' + index)
        }
        .width(180)
        .backgroundColor(Theme.SIDEBAR)
        .borderRadius(Theme.rd.md)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .padding({ top: Theme.sp.xs, bottom: Theme.sp.xs })
        .position({ x: this.positionX, y: this.positionY })
      }
      .width('100%')
      .height('100%')
    }
  }
}
