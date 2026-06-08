import { OpenCodeClient } from '../services/OpenCodeClient'
import { Runner, createRunner, RunnerConfig } from '../models/Runner'
import { storageService } from '../services/StorageService'
import { HealthResult } from '../services/OpenCodeClient'

/**
 * 工作台页面
 * 显示连接状态、快速操作入口、最近工作区
 */
@Component
export struct WorkspacePage {
  @Prop activeRunner: Runner | null = null
  @Prop connectionStatus: string = ''
  @Prop recentWorkspaces: string[] = []
  onNavigate: (page: string) => void = () => {}

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('工作台')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        if (this.activeRunner !== null) {
          Row() {
            Circle({ width: 8, height: 8 })
              .fill(this.activeRunner!.status === 'online' ? '#22C55E' : '#EF4444')
            Text(this.activeRunner!.name)
              .fontSize(13)
              .fontColor('#64748B')
              .margin({ left: 6 })
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(16)
          .backgroundColor('#F1F5F9')
        }
      }
      .width('100%')
      .margin({ bottom: 24 })

      if (this.activeRunner === null) {
        // 未连接状态
        Column() {
          Text('🖥')
            .fontSize(48)
          Text('还没有连接 OpenCode Server')
            .fontSize(16)
            .fontColor('#64748B')
            .margin({ top: 12 })
          Text('连接 Server 后即可开始 AI 编程')
            .fontSize(13)
            .fontColor('#94A3B8')
            .margin({ top: 8 })
          Button('配置服务器')
            .type(ButtonType.Capsule)
            .backgroundColor('#4F46E5')
            .fontColor('#FFFFFF')
            .margin({ top: 20 })
            .onClick(() => { this.onNavigate('server') })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        // 已连接状态
        Scroll() {
          Column() {
            // 快速操作卡片
            Text('快速开始')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#334155')
              .margin({ bottom: 16 })

            Row() {
              this.QuickCard('新建会话', '创建 AI 编程会话', '#4F46E5', 'sessions')
              this.QuickCard('Provider', '配置 AI 模型', '#0EA5E9', 'provider')
              this.QuickCard('代码变更', '查看文件 Diff', '#F59E0B', 'diff')
            }
            .width('100%')

            // 服务器信息
            Text('服务器信息')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#334155')
              .margin({ top: 32, bottom: 16 })

            Column() {
              this.InfoRow('名称', this.activeRunner!.name)
              this.InfoRow('地址', `${this.activeRunner!.protocol}://${this.activeRunner!.host}:${this.activeRunner!.port}`)
              this.InfoRow('状态', this.activeRunner!.status === 'online' ? '已连接' : '未连接')
              if (this.activeRunner!.version) {
                this.InfoRow('版本', this.activeRunner!.version)
              }
            }
            .width('100%')
            .padding(16)
            .borderRadius(12)
            .backgroundColor('#F8FAFC')
            .borderWidth(1)
            .borderColor('#E2E8F0')

            // 最近工作区
            if (this.recentWorkspaces.length > 0) {
              Text('最近工作区')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#334155')
                .margin({ top: 32, bottom: 16 })

              ForEach(this.recentWorkspaces, (path: string) => {
                Row() {
                  Text('📁')
                    .fontSize(16)
                  Text(path)
                    .fontSize(13)
                    .fontColor('#334155')
                    .margin({ left: 8 })
                    .layoutWeight(1)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding(12)
                .borderRadius(8)
                .backgroundColor('#F8FAFC')
                .margin({ bottom: 4 })
              }, (path: string) => path)
            }

            if (this.connectionStatus !== '') {
              Text(this.connectionStatus)
                .fontSize(13)
                .fontColor(this.connectionStatus.includes('成功') || this.connectionStatus.includes('已') ? '#22C55E' : '#EF4444')
                .margin({ top: 16 })
            }
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  QuickCard(title: string, desc: string, color: string, targetPage: string) {
    Column() {
      Text(title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1E293B')
      Text(desc)
        .fontSize(12)
        .fontColor('#64748B')
        .margin({ top: 4 })
    }
    .layoutWeight(1)
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#F8FAFC')
    .borderWidth(1)
    .borderColor('#E2E8F0')
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.onNavigate(targetPage) })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#64748B')
        .width(80)
      Text(value)
        .fontSize(13)
        .fontColor('#1E293B')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }
}
