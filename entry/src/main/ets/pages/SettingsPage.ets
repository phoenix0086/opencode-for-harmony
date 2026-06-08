import { storageService, AppSettings } from '../services/StorageService'
import { providerRegistry } from '../services/ProviderRegistry'
import { Theme } from '../components/Theme'

/**
 * Settings Page (Dark Theme)
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
      Text('SETTINGS')
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1)
        .padding({ left: Theme.sp.xl, top: Theme.sp.lg, bottom: Theme.sp.md })

      Scroll() {
        Column() {
          // About
          this.SectionHeader('ABOUT')
          Column() {
            this.InfoRow('app', 'OpenCode Harmony Native')
            this.InfoRow('version', 'v0.1.0')
            this.InfoRow('stage', 'phase 1 — tech preview')
            this.InfoRow('runtime', 'HarmonyOS ArkTS')
          }
          .width('100%')
          .padding(Theme.sp.xl)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ bottom: Theme.sp.xxl })

          // Display
          this.SectionHeader('DISPLAY')
          Column() {
            Row() {
              Text('font size')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_SECONDARY)
                .fontFamily(Theme.FONT_MONO)
                .layoutWeight(1)
              Text(`${this.settings.fontSize}`)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
              Slider({
                value: this.settings.fontSize,
                min: 10,
                max: 22,
                step: 1
              })
                .width(120)
                .margin({ left: Theme.sp.lg })
                .onChange((value: number) => {
                  this.settings.fontSize = Math.round(value)
                })
            }
            .width('100%')
            .padding({ bottom: Theme.sp.lg })

            Row() {
              Text('dark mode')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_SECONDARY)
                .fontFamily(Theme.FONT_MONO)
                .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.settings.darkMode })
                .selectedColor(Theme.ACCENT)
                .onChange((isOn: boolean) => {
                  this.settings.darkMode = isOn
                })
            }
            .width('100%')
          }
          .width('100%')
          .padding(Theme.sp.xl)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ bottom: Theme.sp.xxl })
          .alignItems(HorizontalAlign.Start)

          // Default config
          this.SectionHeader('DEFAULTS')
          Column() {
            this.SettingField('default agent', this.settings.defaultAgent, (v: string) => {
              this.settings.defaultAgent = v
            })
            this.SettingField('default model', this.settings.defaultModel, (v: string) => {
              this.settings.defaultModel = v
            })
            this.SettingField('small model', this.settings.defaultSmallModel, (v: string) => {
              this.settings.defaultSmallModel = v
            })
          }
          .width('100%')
          .padding(Theme.sp.xl)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ bottom: Theme.sp.xxl })
          .alignItems(HorizontalAlign.Start)

          // Approval policies
          this.SectionHeader('APPROVAL POLICY')
          Column() {
            this.PolicyRow('bash (execute)', 'ask')
            this.PolicyRow('edit (file edit)', 'ask')
            this.PolicyRow('write (file write)', 'ask')
            this.PolicyRow('webfetch (fetch)', 'allow')
          }
          .width('100%')
          .padding(Theme.sp.xl)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ bottom: Theme.sp.xxl })
          .alignItems(HorizontalAlign.Start)

          // Security
          this.SectionHeader('SECURITY')
          Column() {
            Row() {
              Text('server default host')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_SECONDARY)
                .fontFamily(Theme.FONT_MONO)
                .layoutWeight(1)
              Text('127.0.0.1')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
            }
            .width('100%')
            .padding({ bottom: Theme.sp.md })

            Row() {
              Text('API key masking')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_SECONDARY)
                .fontFamily(Theme.FONT_MONO)
                .layoutWeight(1)
              Text('enabled')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.SUCCESS)
                .fontFamily(Theme.FONT_MONO)
                .backgroundColor(Theme.SUCCESS_DIM)
                .borderRadius(Theme.rd.sm)
                .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
            }
            .width('100%')
            .padding({ bottom: Theme.sp.md })

            if (this.showClearConfirm) {
              Row() {
                Text('clear all local data?')
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.DANGER)
                  .fontFamily(Theme.FONT_MONO)
                  .layoutWeight(1)
                Text('cancel')
                  .fontSize(Theme.fs.xs)
                  .fontColor(Theme.TEXT_SECONDARY)
                  .fontFamily(Theme.FONT_MONO)
                  .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
                  .borderRadius(Theme.rd.md)
                  .backgroundColor(Theme.ACTIVE_BG)
                  .onClick(() => { this.showClearConfirm = false })
                Text('confirm')
                  .fontSize(Theme.fs.xs)
                  .fontColor(Theme.TEXT_INVERSE)
                  .fontFamily(Theme.FONT_MONO)
                  .fontWeight(FontWeight.Bold)
                  .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.md, bottom: Theme.sp.md })
                  .borderRadius(Theme.rd.md)
                  .backgroundColor(Theme.DANGER)
                  .margin({ left: Theme.sp.md })
                  .onClick(async () => {
                    await storageService.clearAll()
                    this.showClearConfirm = false
                    this.statusMsg = 'local data cleared'
                  })
              }
              .width('100%')
              .padding({ top: Theme.sp.md })
            } else {
              Text('clear local data')
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.DANGER)
                .fontFamily(Theme.FONT_MONO)
                .fontWeight(FontWeight.Medium)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(Theme.sp.lg)
                .borderRadius(Theme.rd.lg)
                .backgroundColor(Theme.DANGER_DIM)
                .borderWidth(1)
                .borderColor(Theme.DANGER)
                .margin({ top: Theme.sp.md })
                .onClick(() => { this.showClearConfirm = true })
            }
          }
          .width('100%')
          .padding(Theme.sp.xl)
          .borderRadius(Theme.rd.lg)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .margin({ bottom: Theme.sp.xxl })
          .alignItems(HorizontalAlign.Start)

          // Save button
          Text('save settings')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_INVERSE)
            .fontFamily(Theme.FONT_MONO)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding(Theme.sp.lg)
            .borderRadius(Theme.rd.lg)
            .backgroundColor(Theme.ACCENT)
            .onClick(async () => {
              await storageService.saveSettings(this.settings)
              this.statusMsg = 'settings saved'
            })

          if (this.statusMsg.length > 0) {
            Text(this.statusMsg)
              .fontSize(Theme.fs.sm)
              .fontColor(Theme.SUCCESS)
              .fontFamily(Theme.FONT_MONO)
              .margin({ top: Theme.sp.lg })
          }
        }
        .padding({ left: Theme.sp.xl, right: Theme.sp.xl, bottom: Theme.sp.xxl })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Theme.BG)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  SectionHeader(title: string) {
    Text(title)
      .fontSize(Theme.fs.xs)
      .fontWeight(FontWeight.Bold)
      .fontColor(Theme.TEXT_MUTED)
      .fontFamily(Theme.FONT_MONO)
      .letterSpacing(1)
      .margin({ bottom: Theme.sp.lg })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .width(100)
      Text(value)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: Theme.sp.md })
  }

  @Builder
  SettingField(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(Theme.fs.xs)
        .fontColor(Theme.TEXT_MUTED)
        .fontFamily(Theme.FONT_MONO)
        .margin({ bottom: Theme.sp.sm })
      TextInput({ text: value, placeholder: label })
        .width('100%')
        .height(36)
        .fontSize(Theme.fs.sm)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(Theme.rd.lg)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .fontColor(Theme.TEXT_PRIMARY)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .margin({ bottom: Theme.sp.lg })
  }

  @Builder
  PolicyRow(label: string, policy: string) {
    Row() {
      Text(label)
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_SECONDARY)
        .fontFamily(Theme.FONT_MONO)
        .layoutWeight(1)
      Text(policy === 'ask' ? 'ask' : 'allow')
        .fontSize(Theme.fs.xs)
        .fontColor(policy === 'ask' ? Theme.WARNING : Theme.SUCCESS)
        .fontFamily(Theme.FONT_MONO)
        .backgroundColor(policy === 'ask' ? Theme.WARNING_DIM : Theme.SUCCESS_DIM)
        .borderRadius(Theme.rd.sm)
        .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
    }
    .width('100%')
    .padding({ bottom: Theme.sp.md })
  }
}
