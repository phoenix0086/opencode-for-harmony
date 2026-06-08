import { storageService, AppSettings } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'

/**
 * 设置页面
 * 应用设置：默认模型、审批策略、字号、主题等
 */
@Component
export struct SettingsPage {
  @State settings: AppSettings = new AppSettings()
  @State statusMsg: string = ''
  @State showClearConfirm: boolean = false

  async aboutToAppear(): Promise<void> {
    this.settings = await storageService.loadSettings()
  }

  build() {
    Column() {
      Text('设置')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1E293B')
        .margin({ bottom: 24 })

      Scroll() {
        Column() {
          // 基本信息
          this.SectionHeader('关于')
          Column() {
            this.InfoRow('应用名称', 'OpenCode Harmony Native')
            this.InfoRow('版本', 'v0.1.0')
            this.InfoRow('阶段', '第一阶段 — 技术验证版')
            this.InfoRow('运行时', 'HarmonyOS ArkTS')
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#F8FAFC')
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .margin({ bottom: 20 })

          // 显示设置
          this.SectionHeader('显示')
          Column() {
            Row() {
              Text('字号')
                .fontSize(14)
                .fontColor('#334155')
                .layoutWeight(1)
              Text(`${this.settings.fontSize}`)
                .fontSize(14)
                .fontColor('#64748B')
              Slider({
                value: this.settings.fontSize,
                min: 10,
                max: 22,
                step: 1
              })
                .width(150)
                .margin({ left: 12 })
                .onChange((value: number) => {
                  this.settings.fontSize = Math.round(value)
                })
            }
            .width('100%')
            .padding({ bottom: 12 })

            Row() {
              Text('深色模式')
                .fontSize(14)
                .fontColor('#334155')
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.settings.darkMode })
                .selectedColor('#4F46E5')
                .onChange((isOn: boolean) => {
                  this.settings.darkMode = isOn
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#F8FAFC')
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .margin({ bottom: 20 })
          .alignItems(HorizontalAlign.Start)

          // 默认设置
          this.SectionHeader('默认配置')
          Column() {
            this.SettingField('默认 Agent', this.settings.defaultAgent, (v: string) => {
              this.settings.defaultAgent = v
            })
            this.SettingField('默认模型', this.settings.defaultModel, (v: string) => {
              this.settings.defaultModel = v
            })
            this.SettingField('默认小模型', this.settings.defaultSmallModel, (v: string) => {
              this.settings.defaultSmallModel = v
            })
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#F8FAFC')
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .margin({ bottom: 20 })
          .alignItems(HorizontalAlign.Start)

          // 审批策略
          this.SectionHeader('审批策略')
          Column() {
            this.PolicyRow('bash (命令执行)', 'ask')
            this.PolicyRow('edit (文件编辑)', 'ask')
            this.PolicyRow('write (文件写入)', 'ask')
            this.PolicyRow('webfetch (网络获取)', 'allow')
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#F8FAFC')
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .margin({ bottom: 20 })
          .alignItems(HorizontalAlign.Start)

          // 安全
          this.SectionHeader('安全')
          Column() {
            Row() {
              Text('Server 默认连接本机')
                .fontSize(14)
                .fontColor('#334155')
                .layoutWeight(1)
              Text('127.0.0.1')
                .fontSize(13)
                .fontColor('#64748B')
            }
            .width('100%')
            .padding({ bottom: 8 })

            Row() {
              Text('API Key 脱敏')
                .fontSize(14)
                .fontColor('#334155')
                .layoutWeight(1)
              Text('已启用')
                .fontSize(13)
                .fontColor('#22C55E')
            }
            .width('100%')
            .padding({ bottom: 8 })

            if (this.showClearConfirm) {
              Row() {
                Text('确定清除所有本地数据？')
                  .fontSize(13)
                  .fontColor('#EF4444')
                  .layoutWeight(1)
                Button('取消')
                  .type(ButtonType.Normal)
                  .fontSize(12)
                  .height(28)
                  .backgroundColor('#F1F5F9')
                  .fontColor('#334155')
                  .borderRadius(6)
                  .onClick(() => { this.showClearConfirm = false })
                Button('确认清除')
                  .type(ButtonType.Normal)
                  .fontSize(12)
                  .height(28)
                  .backgroundColor('#EF4444')
                  .fontColor('#FFFFFF')
                  .borderRadius(6)
                  .margin({ left: 8 })
                  .onClick(async () => {
                    await storageService.clearAll()
                    this.showClearConfirm = false
                    this.statusMsg = '本地数据已清除'
                  })
              }
              .width('100%')
              .padding({ top: 8 })
            } else {
              Button('清除本地数据')
                .type(ButtonType.Normal)
                .fontSize(13)
                .backgroundColor('#FEE2E2')
                .fontColor('#EF4444')
                .borderRadius(8)
                .width('100%')
                .margin({ top: 8 })
                .onClick(() => { this.showClearConfirm = true })
            }
          }
          .width('100%')
          .padding(16)
          .borderRadius(12)
          .backgroundColor('#F8FAFC')
          .borderWidth(1)
          .borderColor('#E2E8F0')
          .margin({ bottom: 20 })
          .alignItems(HorizontalAlign.Start)

          // 保存按钮
          Button('保存设置')
            .type(ButtonType.Capsule)
            .backgroundColor('#4F46E5')
            .fontColor('#FFFFFF')
            .width('100%')
            .height(44)
            .onClick(async () => {
              await storageService.saveSettings(this.settings)
              this.statusMsg = '设置已保存'
            })

          if (this.statusMsg !== '') {
            Text(this.statusMsg)
              .fontSize(13)
              .fontColor('#22C55E')
              .margin({ top: 12 })
          }
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor('#334155')
      .margin({ bottom: 12 })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#64748B')
        .width(100)
      Text(value)
        .fontSize(13)
        .fontColor('#1E293B')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  SettingField(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#64748B')
        .margin({ bottom: 6 })
      TextInput({ text: value, placeholder: `请输入${label}` })
        .width('100%')
        .height(36)
        .fontSize(13)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .borderWidth(1)
        .borderColor('#E2E8F0')
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  PolicyRow(label: string, policy: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#334155')
        .layoutWeight(1)
      Text(policy === 'ask' ? '需要审批' : '自动允许')
        .fontSize(12)
        .fontColor(policy === 'ask' ? '#F59E0B' : '#22C55E')
        .backgroundColor(policy === 'ask' ? '#FEF3C7' : '#DCFCE7')
        .borderRadius(4)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    }
    .width('100%')
    .padding({ bottom: 8 })
  }
}
