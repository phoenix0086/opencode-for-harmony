import { Runner } from '../models/Runner'
import { FileDiff } from '../models/Event'
import { OpenCodeClient } from '../services/OpenCodeClient'

/**
 * Diff 审查页面
 * 展示文件变更列表和行级 Diff
 */
@Component
export struct DiffReviewPage {
  @Prop activeRunner: Runner | null = null
  @Prop sessionId: string = ''
  @State diffs: FileDiff[] = []
  @State selectedFile: string = ''
  @State selectedPatch: string = ''
  @State isLoading: boolean = false
  @State errorMsg: string = ''

  async aboutToAppear(): Promise<void> {
    await this.loadDiffs()
  }

  async loadDiffs(): Promise<void> {
    if (this.activeRunner === null || this.sessionId === '') return
    this.isLoading = true
    try {
      const client = new OpenCodeClient(this.activeRunner!)
      this.diffs = await client.getVcsDiff('git')
      if (this.diffs.length > 0) {
        this.selectedFile = this.diffs[0].path
        this.selectedPatch = this.diffs[0].patch
      }
    } catch (e) {
      this.errorMsg = `加载 Diff 失败: ${String(e)}`
    }
    this.isLoading = false
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('代码变更')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        if (this.diffs.length > 0) {
          Text(`${this.diffs.length} 个文件`)
            .fontSize(13)
            .fontColor('#64748B')
        }
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40).color('#4F46E5')
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else if (this.diffs.length === 0) {
        Column() {
          Text('📋')
            .fontSize(48)
          Text('暂无代码变更')
            .fontSize(14)
            .fontColor('#94A3B8')
            .margin({ top: 12 })
          if (this.errorMsg !== '') {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor('#EF4444')
              .margin({ top: 8 })
          }
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        // 双栏布局：左侧文件列表，右侧 Diff
        Row() {
          // 左侧文件列表
          List() {
            ForEach(this.diffs, (diff: FileDiff) => {
              ListItem() {
                this.FileRow(diff)
              }
            }, (diff: FileDiff) => diff.file)
          }
          .width(280)
          .height('100%')
          .divider({ strokeWidth: 0 })

          // 分割线
          Divider()
            .vertical(true)
            .color('#E2E8F0')
            .width(1)

          // 右侧 Diff 内容
          Column() {
            if (this.selectedFile !== '') {
              Text(this.selectedFile)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1E293B')
                .margin({ bottom: 12 })

              Scroll() {
                Text(this.selectedPatch || '无 patch 数据')
                  .fontSize(12)
                  .fontColor('#334155')
                  .fontFamily('monospace')
                  .width('100%')
                  .padding(12)
                  .backgroundColor('#F8FAFC')
                  .borderRadius(8)
              }
              .layoutWeight(1)
            } else {
              Column() {
                Text('选择一个文件查看变更')
                  .fontSize(14)
                  .fontColor('#94A3B8')
              }
              .justifyContent(FlexAlign.Center)
              .layoutWeight(1)
            }
          }
          .layoutWeight(1)
          .padding({ left: 16 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FileRow(diff: FileDiff) {
    Row() {
      Text(this.getStatusIcon(diff.status))
        .fontSize(14)
        .width(24)

      Column() {
        Text(this.getFileName(diff.file))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedFile === diff.file ? '#4F46E5' : '#1E293B')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Row() {
          if (diff.additions > 0) {
            Text(`+${diff.additions}`)
              .fontSize(11)
              .fontColor('#22C55E')
          }
          if (diff.deletions > 0) {
            Text(`-${diff.deletions}`)
              .fontSize(11)
              .fontColor('#EF4444')
              .margin({ left: 6 })
          }
        }
        .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: 8 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(12)
    .borderRadius(8)
    .backgroundColor(this.selectedFile === diff.file ? '#E0E7FF' : 'transparent')
    .onClick(() => {
      this.selectedFile = diff.file
      this.selectedPatch = diff.patch
    })
  }

  getStatusIcon(status: string): string {
    switch (status) {
      case 'added': return '➕'
      case 'modified': return '✏️'
      case 'deleted': return '❌'
      case 'renamed': return '📝'
      default: return '📄'
    }
  }

  getFileName(path: string): string {
    const parts = path.split('/')
    return parts[parts.length - 1]
  }
}
