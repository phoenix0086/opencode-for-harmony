import { CNProvider, CNModel } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { Theme } from '../components/Theme'

/**
 * Standalone model selector page, matching OpenCode Desktop's model settings panel.
 * It can be wired into SettingsPage or AppShell later. ProviderPage already embeds
 * the same model management flow.
 */
@Component
export struct ModelPage {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @State providers: CNProvider[] = []
  @State searchText: string = ''
  @State selectedModel: string = ''
  @State statusMsg: string = ''

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
  }

  build() {
    Column() {
      Row() {
        Text('模型')
          .fontSize(Theme.fs.xl)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT_PRIMARY)
        Blank()
        Text(this.selectedModel.length > 0 ? this.selectedModel : '未选择模型')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 22, bottom: 12 })

      TextInput({ text: this.searchText, placeholder: '搜索模型' })
        .height(42)
        .fontSize(Theme.fs.md)
        .fontColor(Theme.TEXT_PRIMARY)
        .backgroundColor(Theme.INPUT_BG)
        .borderRadius(8)
        .borderWidth(1)
        .borderColor(Theme.BORDER)
        .margin({ left: 24, right: 24, bottom: 16 })
        .onChange((v: string) => { this.searchText = v })

      Scroll() {
        Column() {
          ForEach(this.providers, (p: CNProvider) => {
            if (p.enabled) this.ProviderModels(p)
          }, (p: CNProvider) => p.id)
        }
        .padding({ left: 24, right: 24, bottom: 24 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }

  @Builder
  ProviderModels(p: CNProvider) {
    Column() {
      Text(p.name)
        .fontSize(Theme.fs.sm)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.TEXT_SECONDARY)
        .margin({ bottom: 8, top: 8 })
      ForEach(p.models, (m: CNModel) => {
        if (this.searchText.length === 0 || m.id.includes(this.searchText) || m.name.includes(this.searchText)) {
          Row() {
            Column() {
              Text(m.name.length > 0 ? m.name : m.id)
                .fontSize(Theme.fs.sm)
                .fontColor(Theme.TEXT_PRIMARY)
              Text(`${p.id}/${m.id}`)
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)
                .margin({ top: 3 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text(this.selectedModel === `${p.id}/${m.id}` ? '已选择' : '选择')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.ACCENT)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(6)
              .backgroundColor(Theme.ACTIVE_BG)
              .onClick(() => {
                this.selectedModel = `${p.id}/${m.id}`
                this.statusMsg = 'model selected'
              })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(Theme.SIDEBAR)
          .borderWidth(1)
          .borderColor(Theme.BORDER)
          .borderRadius(8)
          .margin({ bottom: 8 })
        }
      }, (m: CNModel) => m.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
