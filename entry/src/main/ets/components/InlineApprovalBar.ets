import { Theme } from './Theme'

/**
 * 内联审批条
 * 替代红色大警告卡片，以 compact inline bar 展示权限审批
 */
@Component
export struct InlineApprovalBar {
  @Prop permId: string = ''
  @Prop permType: string = ''
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop riskLevel: string = 'low'
  @Prop status: string = 'pending' // 'pending' | 'approved' | 'rejected'
  onApprove: (id: string) => void = () => {}
  onReject: (id: string) => void = () => {}

  build() {
    Row() {
      // Risk indicator bar
      Column()
        .width(3)
        .height('100%')
        .backgroundColor(this.getRiskColor())
        .borderRadius({ topLeft: Theme.rd.md, bottomLeft: Theme.rd.md })

      // Info section
      Column() {
        Row() {
          Text(this.getTypeIcon())
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)

          Text(this.permType)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .backgroundColor(Theme.CODE_BG)
            .borderRadius(Theme.rd.sm)
            .padding({ left: Theme.sp.sm, right: Theme.sp.sm })
            .margin({ left: Theme.sp.sm })

          Text(this.title)
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_PRIMARY)
            .margin({ left: Theme.sp.md })
            .maxLines(1)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')

        if (this.description.length > 0) {
          Text(this.description)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_SECONDARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .padding({ left: Theme.sp.md, right: Theme.sp.md })

      // Action buttons (only when pending)
      if (this.status === 'pending') {
        Row() {
          Text('allow')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.SUCCESS)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.SUCCESS_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .onClick(() => {
              this.onApprove(this.permId)
            })

          Text('deny')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(Theme.DANGER_DIM)
            .borderRadius(Theme.rd.md)
            .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
            .margin({ left: Theme.sp.md })
            .onClick(() => {
              this.onReject(this.permId)
            })
        }
        .padding({ right: Theme.sp.lg })
      } else {
        Text(this.status)
          .fontSize(Theme.fs.xs)
          .fontColor(this.status === 'approved' ? Theme.SUCCESS : Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
          .padding({ right: Theme.sp.lg })
      }
    }
    .width('100%')
    .height(this.description.length > 0 ? 56 : 36)
    .backgroundColor(Theme.TOOL_BG)
    .borderRadius(Theme.rd.md)
    .borderWidth(1)
    .borderColor(Theme.TOOL_BORDER)
    .alignItems(VerticalAlign.Center)
  }

  private getRiskColor(): string {
    if (this.riskLevel === 'high') return Theme.DANGER
    if (this.riskLevel === 'medium') return Theme.WARNING
    return Theme.SUCCESS
  }

  private getTypeIcon(): string {
    if (this.permType === 'bash') return '$'
    if (this.permType === 'edit') return 'E'
    if (this.permType === 'write') return 'W'
    if (this.permType === 'delete') return 'X'
    if (this.permType === 'webfetch') return 'G'
    return '?'
  }
}
