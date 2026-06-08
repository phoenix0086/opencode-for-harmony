import { CNProvider, CNModel } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { Runner } from '../models/Runner'
import { OpenCodeClient } from '../services/OpenCodeClient'
import { Theme } from '../components/Theme'

/**
 * Provider 配置页面 (Dark Theme)
 * 管理国内大模型供应商：启用/禁用、API Key、模型选择
 */
@Component
export struct ProviderPage {
  @Prop activeRunner: Runner | null = null
  @State providers: CNProvider[] = []
  @State selectedProviderId: string = ''
  @State apiKeyInput: string = ''
  @State defaultModel: string = ''
  @State smallModel: string = ''
  @State configOutput: string = ''
  @State statusMsg: string = ''
  @State isInitialized: boolean = false
  private codingModelsMap: Map<string, CNModel[]> = new Map()

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
    this.buildCodingModelsMap()
    this.isInitialized = true
  }

  private buildCodingModelsMap(): void {
    this.codingModelsMap = new Map()
    for (const provider of this.providers) {
      const codingList: CNModel[] = []
      for (const m of provider.models) {
        if (m.coding) {
          codingList.push(m)
        }
      }
      this.codingModelsMap.set(provider.id, codingList)
    }
  }

  build() {
    Column() {
      // Title bar
      Row() {
        Text('PROVIDER')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)

        Blank()

        Text('generate config')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.ACCENT)
          .fontFamily(Theme.FONT_MONO)
          .fontWeight(FontWeight.Bold)
          .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.sm, bottom: Theme.sp.sm })
          .borderRadius(Theme.rd.md)
          .backgroundColor(Theme.ACCENT_DIM)
          .onClick(() => this.generateConfig())
      }
      .width('100%')
      .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.lg, bottom: Theme.sp.md })

      if (!this.isInitialized) {
        Column() {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(Theme.ACCENT)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            // Provider list
            ForEach(this.providers, (provider: CNProvider) => {
              this.ProviderCard(provider)
            }, (provider: CNProvider) => provider.id)

            // Config output
            if (this.configOutput.length > 0) {
              Column() {
                Row() {
                  Text('opencode.json')
                    .fontSize(Theme.fs.sm)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Theme.TEXT_PRIMARY)
                    .fontFamily(Theme.FONT_MONO)

                  Blank()

                  Text('copy')
                    .fontSize(Theme.fs.xs)
                    .fontColor(Theme.ACCENT)
                    .fontFamily(Theme.FONT_MONO)
                    .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
                    .borderRadius(Theme.rd.sm)
                    .backgroundColor(Theme.ACTIVE_BG)
                    .onClick(() => {
                      this.statusMsg = 'copied to clipboard'
                    })
                }
                .width('100%')
                .margin({ bottom: Theme.sp.md })

                Text(this.configOutput)
                  .fontSize(Theme.fs.code)
                  .fontColor(Theme.TEXT_PRIMARY)
                  .backgroundColor(Theme.PANEL)
                  .padding(Theme.sp.lg)
                  .borderRadius(Theme.rd.lg)
                  .width('100%')
                  .fontFamily(Theme.FONT_MONO)
                  .constraintSize({ maxHeight: 300 })
              }
              .width('100%')
              .padding(Theme.sp.xl)
              .borderRadius(Theme.rd.lg)
              .backgroundColor(Theme.SUCCESS_DIM)
              .borderWidth(1)
              .borderColor(Theme.SUCCESS)
              .margin({ top: Theme.sp.xl })
              .alignItems(HorizontalAlign.Start)
            }

            if (this.statusMsg.length > 0) {
              Text(this.statusMsg)
                .fontSize(Theme.fs.sm)
                .fontColor(this.statusMsg.includes('failed') || this.statusMsg.includes('失败') ? Theme.DANGER : Theme.SUCCESS)
                .fontFamily(Theme.FONT_MONO)
                .margin({ top: Theme.sp.lg })
            }
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(Theme.BG)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProviderCard(provider: CNProvider) {
    Column() {
      Row() {
        // Enable/disable toggle
        Toggle({ type: ToggleType.Switch, isOn: provider.enabled })
          .selectedColor(Theme.ACCENT)
          .onChange((isOn: boolean) => {
            if (isOn) {
              providerRegistry.enable(provider.id)
            } else {
              providerRegistry.disable(provider.id)
            }
            this.refreshProviders()
          })

        Column() {
          Text(provider.name)
            .fontSize(Theme.fs.lg)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.TEXT_PRIMARY)
          Text(provider.baseURL.length > 0 ? provider.baseURL : 'custom endpoint')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
        }
        .layoutWeight(1)
        .margin({ left: Theme.sp.lg })
        .alignItems(HorizontalAlign.Start)

        Text(provider.authStatus === 'configured' ? 'configured' : 'not set')
          .fontSize(Theme.fs.xs)
          .fontColor(provider.authStatus === 'configured' ? Theme.SUCCESS : Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
      }
      .width('100%')

      // Expanded details
      if (this.selectedProviderId === provider.id) {
        Column() {
          // Model list
          if (provider.models.length > 0) {
            Text('MODELS')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_MUTED)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1)
              .margin({ bottom: Theme.sp.md })

            ForEach(provider.models, (model: CNModel) => {
              Row() {
                Text(model.name)
                  .fontSize(Theme.fs.sm)
                  .fontColor(Theme.TEXT_PRIMARY)
                  .fontFamily(Theme.FONT_MONO)

                Blank()

                if (model.recommended) {
                  Text('rec')
                    .fontSize(9)
                    .fontColor(Theme.ACCENT)
                    .fontFamily(Theme.FONT_MONO)
                    .backgroundColor(Theme.ACCENT_DIM)
                    .borderRadius(Theme.rd.sm)
                    .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 1, bottom: 1 })
                }
                if (model.coding) {
                  Text('code')
                    .fontSize(9)
                    .fontColor(Theme.INFO)
                    .fontFamily(Theme.FONT_MONO)
                    .backgroundColor(Theme.ACCENT_DIM)
                    .borderRadius(Theme.rd.sm)
                    .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: 1, bottom: 1 })
                    .margin({ left: Theme.sp.sm })
                }
              }
              .width('100%')
              .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
            }, (model: CNModel) => model.id)
          }

          // API Key input
          Text(provider.authEnv)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xl, bottom: Theme.sp.md })

          Row() {
            TextInput({ text: this.apiKeyInput, placeholder: provider.authEnv })
              .layoutWeight(1)
              .height(36)
              .fontSize(Theme.fs.sm)
              .backgroundColor(Theme.INPUT_BG)
              .borderRadius(Theme.rd.lg)
              .borderWidth(1)
              .borderColor(Theme.BORDER)
              .fontColor(Theme.TEXT_PRIMARY)
              .type(InputType.Password)
              .onChange((v: string) => { this.apiKeyInput = v })

            Text('save')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_INVERSE)
              .fontFamily(Theme.FONT_MONO)
              .fontWeight(FontWeight.Bold)
              .backgroundColor(Theme.ACCENT)
              .borderRadius(Theme.rd.lg)
              .padding({ left: Theme.sp.xl, right: Theme.sp.xl, top: Theme.sp.md, bottom: Theme.sp.md })
              .margin({ left: Theme.sp.md })
              .onClick(() => this.saveApiKey(provider.id))
          }
          .width('100%')

          // Default model selection
          if (this.codingModelsMap.has(provider.id)) {
            Row() {
              Text('default')
                .fontSize(Theme.fs.xs)
                .fontColor(Theme.TEXT_MUTED)
                .fontFamily(Theme.FONT_MONO)

              Blank()

              ForEach(this.codingModelsMap.get(provider.id) as CNModel[], (cm: CNModel) => {
                Text(cm.name)
                  .fontSize(Theme.fs.xs)
                  .fontColor(this.defaultModel === `${provider.id}/${cm.id}` ? Theme.TEXT_INVERSE : Theme.ACCENT)
                  .fontFamily(Theme.FONT_MONO)
                  .backgroundColor(this.defaultModel === `${provider.id}/${cm.id}` ? Theme.ACCENT : Theme.ACCENT_DIM)
                  .borderRadius(Theme.rd.md)
                  .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
                  .margin({ left: Theme.sp.md })
                  .onClick(() => {
                    this.defaultModel = `${provider.id}/${cm.id}`
                    if (this.smallModel.length === 0) {
                      this.smallModel = this.defaultModel
                    }
                  })
              }, (cm: CNModel) => cm.id)
            }
            .width('100%')
            .margin({ top: Theme.sp.xl })
          }
        }
        .margin({ top: Theme.sp.lg })
        .padding({ top: Theme.sp.lg })
        .borderWidth({ top: 1 })
        .borderColor(Theme.BORDER)
      }
    }
    .width('100%')
    .padding(Theme.sp.xl)
    .borderRadius(Theme.rd.lg)
    .backgroundColor(Theme.SIDEBAR)
    .borderWidth(1)
    .borderColor(Theme.BORDER)
    .margin({ bottom: Theme.sp.md, left: Theme.sp.xl, right: Theme.sp.xl })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.selectedProviderId = this.selectedProviderId === provider.id ? '' : provider.id
    })
  }

  refreshProviders(): void {
    this.providers = providerRegistry.getAll()
    this.buildCodingModelsMap()
  }

  async saveApiKey(providerId: string): Promise<void> {
    if (this.apiKeyInput.length === 0) {
      this.statusMsg = 'enter API key first'
      return
    }
    if (this.activeRunner !== null) {
      try {
        const client = new OpenCodeClient(this.activeRunner)
        const success = await client.setAuth(providerId, this.apiKeyInput)
        if (success) {
          providerRegistry.setAuthStatus(providerId, 'configured')
          await providerRegistry.save()
          this.apiKeyInput = ''
          this.statusMsg = 'API key saved'
          this.refreshProviders()
        } else {
          this.statusMsg = 'save failed'
        }
      } catch (e) {
        this.statusMsg = `save failed: ${String(e)}`
      }
    } else {
      providerRegistry.setAuthStatus(providerId, 'configured')
      await providerRegistry.save()
      this.apiKeyInput = ''
      this.statusMsg = 'marked as configured (server required)'
      this.refreshProviders()
    }
  }

  generateConfig(): void {
    if (this.defaultModel.length === 0) {
      for (const p of this.providers) {
        if (p.enabled) {
          const rec = providerRegistry.getRecommendedModel(p.id)
          if (rec) {
            this.defaultModel = rec
            this.smallModel = rec
            break
          }
        }
      }
    }
    this.configOutput = providerRegistry.generateFullConfig(this.defaultModel, this.smallModel)
    this.statusMsg = 'config generated'
  }
}
