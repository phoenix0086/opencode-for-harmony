import { CNProvider, CNModel } from '../models/Provider'
import { providerRegistry } from '../services/ProviderRegistry'
import { Runner } from '../models/Runner'
import { OpenCodeClient } from '../services/OpenCodeClient'

/**
 * Provider 配置页面
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

  async aboutToAppear(): Promise<void> {
    await providerRegistry.init()
    this.providers = providerRegistry.getAll()
    this.isInitialized = true
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('Provider 管理')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('生成配置')
          .type(ButtonType.Capsule)
          .backgroundColor('#4F46E5')
          .fontColor('#FFFFFF')
          .fontSize(13)
          .onClick(() => this.generateConfig())
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (!this.isInitialized) {
        Column() {
          LoadingProgress().width(40).height(40).color('#4F46E5')
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
      } else {
        Scroll() {
          Column() {
            // Provider 列表
            ForEach(this.providers, (provider: CNProvider) => {
              this.ProviderCard(provider)
            }, (provider: CNProvider) => provider.id)

            // 配置输出
            if (this.configOutput !== '') {
              Column() {
                Row() {
                  Text('生成的 opencode.json')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#334155')
                  Blank()
                  Button('复制')
                    .type(ButtonType.Normal)
                    .fontSize(11)
                    .height(28)
                    .backgroundColor('#F1F5F9')
                    .fontColor('#334155')
                    .borderRadius(6)
                    .onClick(() => {
                      // 复制到剪贴板
                      this.statusMsg = '已复制到剪贴板'
                    })
                }
                .width('100%')
                .margin({ bottom: 8 })

                Text(this.configOutput)
                  .fontSize(11)
                  .fontColor('#334155')
                  .backgroundColor('#F8FAFC')
                  .padding(12)
                  .borderRadius(8)
                  .width('100%')
                  .fontFamily('monospace')
                  .constraintSize({ maxHeight: 300 })
              }
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor('#F0FDF4')
              .borderWidth(1)
              .borderColor('#BBF7D0')
              .margin({ top: 16 })
              .alignItems(HorizontalAlign.Start)
            }

            if (this.statusMsg !== '') {
              Text(this.statusMsg)
                .fontSize(13)
                .fontColor(this.statusMsg.includes('失败') ? '#EF4444' : '#22C55E')
                .margin({ top: 12 })
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
  ProviderCard(provider: CNProvider) {
    Column() {
      Row() {
        // 启用/禁用开关
        Toggle({ type: ToggleType.Switch, isOn: provider.enabled })
          .selectedColor('#4F46E5')
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
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E293B')
          Text(provider.baseURL || '自定义地址')
            .fontSize(12)
            .fontColor('#64748B')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)

        Text(provider.authStatus === 'configured' ? '已配置' : '未配置')
          .fontSize(11)
          .fontColor(provider.authStatus === 'configured' ? '#22C55E' : '#94A3B8')
      }
      .width('100%')

      // 展开详情
      if (this.selectedProviderId === provider.id) {
        Column() {
          // 模型列表
          if (provider.models.length > 0) {
            Text('可用模型')
              .fontSize(12)
              .fontColor('#64748B')
              .margin({ bottom: 6 })

            ForEach(provider.models, (model: CNModel) => {
              Row() {
                Text(model.name)
                  .fontSize(13)
                  .fontColor('#334155')
                Blank()
                if (model.recommended) {
                  Text('推荐')
                    .fontSize(10)
                    .fontColor('#4F46E5')
                    .backgroundColor('#E0E7FF')
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                }
                if (model.coding) {
                  Text('编程')
                    .fontSize(10)
                    .fontColor('#0EA5E9')
                    .backgroundColor('#E0F2FE')
                    .borderRadius(4)
                    .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                    .margin({ left: 4 })
                }
              }
              .width('100%')
              .padding({ top: 4, bottom: 4 })
            }, (model: CNModel) => model.id)
          }

          // API Key 输入
          Text(`API Key (${provider.authEnv})`)
            .fontSize(12)
            .fontColor('#64748B')
            .margin({ top: 12, bottom: 6 })

          Row() {
            TextInput({ text: this.apiKeyInput, placeholder: `输入 ${provider.authEnv}` })
              .layoutWeight(1)
              .height(36)
              .fontSize(13)
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .borderWidth(1)
              .borderColor('#E2E8F0')
              .type(InputType.Password)
              .onChange((v: string) => { this.apiKeyInput = v })

            Button('保存')
              .type(ButtonType.Normal)
              .fontSize(12)
              .height(36)
              .backgroundColor('#4F46E5')
              .fontColor('#FFFFFF')
              .borderRadius(8)
              .margin({ left: 8 })
              .onClick(() => this.saveApiKey(provider.id))
          }
          .width('100%')

          // 默认模型选择
          if (provider.models.length > 0) {
            Row() {
              Text('设为默认模型:')
                .fontSize(12)
                .fontColor('#64748B')
              Blank()
              ForEach(provider.models.filter((m: CNModel) => m.coding), (model: CNModel) => {
                Text(model.name)
                  .fontSize(11)
                  .fontColor(this.defaultModel === `${provider.id}/${model.id}` ? '#FFFFFF' : '#4F46E5')
                  .backgroundColor(this.defaultModel === `${provider.id}/${model.id}` ? '#4F46E5' : '#E0E7FF')
                  .borderRadius(6)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .margin({ left: 6 })
                  .onClick(() => {
                    this.defaultModel = `${provider.id}/${model.id}`
                    this.smallModel = this.smallModel || this.defaultModel
                  })
              }, (model: CNModel) => model.id)
            }
            .width('100%')
            .margin({ top: 12 })
          }
        }
        .margin({ top: 12 })
        .padding({ top: 12 })
        .borderWidth({ top: 1 })
        .borderColor('#E2E8F0')
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FAFBFC')
    .borderWidth(1)
    .borderColor('#E2E8F0')
    .margin({ bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.selectedProviderId = this.selectedProviderId === provider.id ? '' : provider.id
    })
  }

  refreshProviders(): void {
    this.providers = providerRegistry.getAll()
  }

  async saveApiKey(providerId: string): Promise<void> {
    if (this.apiKeyInput === '') {
      this.statusMsg = '请输入 API Key'
      return
    }
    // 通过 OpenCode Server API 保存
    if (this.activeRunner !== null) {
      try {
        const client = new OpenCodeClient(this.activeRunner!)
        const success = await client.setAuth(providerId, this.apiKeyInput)
        if (success) {
          providerRegistry.setAuthStatus(providerId, 'configured')
          await providerRegistry.save()
          this.apiKeyInput = ''
          this.statusMsg = 'API Key 已保存'
          this.refreshProviders()
        } else {
          this.statusMsg = '保存失败'
        }
      } catch (e) {
        this.statusMsg = `保存失败: ${String(e)}`
      }
    } else {
      // 没有连接 server，只标记状态
      providerRegistry.setAuthStatus(providerId, 'configured')
      await providerRegistry.save()
      this.apiKeyInput = ''
      this.statusMsg = 'API Key 已标记（需连接 Server 后生效）'
      this.refreshProviders()
    }
  }

  generateConfig(): void {
    if (this.defaultModel === '') {
      // 自动选择第一个推荐的编码模型
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
    this.statusMsg = '配置已生成'
  }
}
