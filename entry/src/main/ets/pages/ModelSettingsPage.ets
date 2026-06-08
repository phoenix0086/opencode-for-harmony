import { Theme } from '../components/Theme'
import { Runner } from '../models/Runner'
import { ModelCard } from '../components/model/ModelCard'
import { modelSelectionService, ModelOption, ModelSelectionResult } from '../services/ModelSelectionService'

@Component
export struct ModelSettingsPage {
  @Prop activeRunner: Runner | null = null
  @Prop isConnected: boolean = false

  @State models: ModelOption[] = []
  @State defaultModel: string = ''
  @State smallModel: string = ''
  @State statusMsg: string = ''

  async aboutToAppear(): Promise<void> {
    await this.reload()
  }

  private async reload(): Promise<void> {
    this.models = await modelSelectionService.listAvailableModels()
    this.defaultModel = await modelSelectionService.getDefaultModel()
    this.smallModel = await modelSelectionService.getSmallModel()
  }

  build() {
    Scroll() {
      Column() {
        Text('模型')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ bottom: 28 })

        this.ServerNotice()
        this.CurrentSelection()

        Text('可用模型')
          .fontSize(Theme.fs.lg)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
          .margin({ top: 32, bottom: 14 })

        if (this.models.length === 0) {
          Text('没有可用模型。请先在“提供商”页连接一个 Provider。')
            .fontSize(Theme.fs.md)
            .fontColor(Theme.TEXT_MUTED)
            .padding(24)
            .borderRadius(12)
            .backgroundColor(Theme.SIDEBAR)
            .width('100%')
        } else {
          ForEach(this.models, (m: ModelOption) => {
            ModelCard({
              providerName: m.providerName,
              modelRef: m.modelRef,
              modelName: m.modelName,
              isDefault: this.defaultModel === m.modelRef,
              isSmall: this.smallModel === m.modelRef,
              onSetDefault: () => this.setDefault(m.modelRef),
              onSetSmall: () => this.setSmall(m.modelRef),
              onTest: () => this.testModel(m.modelRef)
            })
          }, (m: ModelOption) => m.modelRef)
        }

        if (this.statusMsg.length > 0) {
          Text(this.statusMsg)
            .fontSize(Theme.fs.sm)
            .fontColor(this.statusMsg.includes('失败') || this.statusMsg.includes('无法') ? Theme.DANGER : Theme.SUCCESS)
            .margin({ top: 20 })
        }
      }
      .padding({ left: 78, right: 78, top: 56, bottom: 60 })
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  @Builder
  ServerNotice() {
    if (!this.isConnected) {
      Text('本地 Runtime 未连接：可以本地选择默认模型，但不能测试模型，也不能同步到 opencode serve。')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.WARNING)
        .padding(14)
        .borderRadius(10)
        .backgroundColor(Theme.WARNING_DIM)
        .width('100%')
        .margin({ bottom: 16 })
    }
  }

  @Builder
  CurrentSelection() {
    Column() {
      Text('默认模型')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
      Text(this.defaultModel.length > 0 ? this.defaultModel : '未设置')
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .margin({ top: 8, bottom: 18 })

      Text('Small Model')
        .fontSize(Theme.fs.sm)
        .fontColor(Theme.TEXT_MUTED)
      Text(this.smallModel.length > 0 ? this.smallModel : '未设置')
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(22)
    .borderRadius(12)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
  }

  private async setDefault(modelRef: string): Promise<void> {
    const result: ModelSelectionResult = await modelSelectionService.setDefaultModel(modelRef, this.isConnected ? this.activeRunner : null)
    this.statusMsg = result.message
    await this.reload()
  }

  private async setSmall(modelRef: string): Promise<void> {
    const result: ModelSelectionResult = await modelSelectionService.setSmallModel(modelRef, this.isConnected ? this.activeRunner : null)
    this.statusMsg = result.message
    await this.reload()
  }

  private async testModel(modelRef: string): Promise<void> {
    this.statusMsg = await modelSelectionService.testModel(modelRef, this.isConnected ? this.activeRunner : null)
  }
}
