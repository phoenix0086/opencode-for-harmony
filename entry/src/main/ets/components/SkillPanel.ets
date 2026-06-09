import { Theme } from './Theme'
import { SkillInfo } from '../models/Event'

/**
 * SkillPanel - v2 技能列表面板
 * 显示 OpenCode Server 注册的 skills
 */
@Component
export struct SkillPanel {
  @Prop skills: SkillInfo[] = []
  @Prop isLoading: boolean = false
  @Prop unsupported: boolean = false
  @Prop errorMessage: string = ''
  onRefresh: () => void = () => {}

  build() {
    Column() {
      // Header
      Row() {
        Text('skills')
          .fontSize(Theme.fs.md)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .fontFamily(Theme.FONT_MONO)

        Blank()

        if (!this.unsupported) {
          Text('refresh')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.ACCENT)
            .fontFamily(Theme.FONT_MONO)
            .onClick(() => { this.onRefresh() })
        }
      }
      .width('100%')
      .padding({ bottom: Theme.sp.md })

      if (this.unsupported) {
        this.UnsupportedBanner()
      } else if (this.errorMessage.length > 0) {
        this.ErrorBanner()
      } else if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color(Theme.ACCENT)
          Text('loading...')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: Theme.sp.sm })
        }
        .width('100%')
        .padding({ top: Theme.sp.xl })
        .alignItems(HorizontalAlign.Center)
      } else if (this.skills.length === 0) {
        Column() {
          Text('S')
            .fontSize(24)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('no skills registered')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .margin({ top: Theme.sp.sm })
        }
        .width('100%')
        .padding({ top: Theme.sp.xl })
        .alignItems(HorizontalAlign.Center)
      } else {
        // Skill list
        List() {
          ForEach(this.skills, (skill: SkillInfo) => {
            ListItem() {
              Column() {
                Row() {
                  Text(skill.name)
                    .fontSize(Theme.fs.sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.ACCENT)
                    .fontFamily(Theme.FONT_MONO)

                  if (!skill.enabled) {
                    Text('disabled')
                      .fontSize(Theme.fs.xs)
                      .fontColor(Theme.DANGER)
                      .fontFamily(Theme.FONT_MONO)
                      .margin({ left: Theme.sp.sm })
                  }

                  Blank()
                }
                .width('100%')

                if (skill.description.length > 0) {
                  Text(skill.description)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.TEXT_SECONDARY)
                    .margin({ top: Theme.sp.xs })
                    .maxLines(3)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }

                if (skill.path.length > 0) {
                  Text(skill.path)
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.TEXT_MUTED)
                    .fontFamily(Theme.FONT_MONO)
                    .margin({ top: Theme.sp.xs })
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .padding({ top: Theme.sp.md, bottom: Theme.sp.md, left: Theme.sp.lg, right: Theme.sp.lg })
              .backgroundColor(Theme.SURFACE)
              .borderRadius(Theme.rd.md)
              .margin({ bottom: Theme.sp.sm })
            }
          }, (skill: SkillInfo) => skill.id)
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .padding(Theme.sp.lg)
    .backgroundColor(Theme.BG)
  }

  @Builder
  UnsupportedBanner() {
    Column() {
      Text('S')
        .fontSize(24)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
      Text('skills not supported')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.WARNING)
        .margin({ top: Theme.sp.sm })
      Text('requires OpenCode Server v2')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .margin({ top: Theme.sp.xs })
    }
    .width('100%')
    .padding({ top: Theme.sp.xl })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ErrorBanner() {
    Column() {
      Text('error: ' + this.errorMessage)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.DANGER)
        .fontFamily(Theme.FONT_MONO)
    }
    .width('100%')
    .padding({ top: Theme.sp.xl })
    .alignItems(HorizontalAlign.Center)
  }
}
