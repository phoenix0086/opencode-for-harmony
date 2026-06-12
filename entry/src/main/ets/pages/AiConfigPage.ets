import { ProviderPage } from './ProviderPage'
import { MainViewModel } from '../viewmodel/MainViewModel'
import { localRuntimeService } from '../services/LocalRuntimeService'
import { LocalProviderConfig, LocalModelConfig } from '../services/LocalRuntimeTypes'
import { Logger } from '../utils/Logger'
import { errStr } from '../utils/ErrorUtil'

/**
 * AI 配置页 — PR 2:从 Index.ets 抽出来,变成独立页面,两个 Tab
 *
 * Tab 1: 模型选择
 *   - 当前模型(读 MainViewModel.selectedModel)
 *   - 常用模型 chips
 *   - 保存模型 / 测试模型
 *
 * Tab 2: 供应商配置
 *   - 嵌入 ProviderPage(增删改 Provider,Base URL / API Key)
 */
@Component
export struct AiConfigPage {
  @StorageLink('viewModel') viewModel: MainViewModel = new MainViewModel()
  @State currentTab: number = 0
  @State modelInput: string = ''
  @State testResult: string = ''
  @State testing: boolean = false
  @State saving: boolean = false
  @State runtimeOk: boolean = false
  @State runtimeProviders: LocalProviderConfig[] = []

  aboutToAppear(): void {
    this.modelInput = this.viewModel.selectedModel
    this.refreshRuntimeState()
  }

  onPageShow(): void {
    // 切回本页 / 切到 Tab 1 时刷新 Runtime 数据
    this.refreshRuntimeState()
  }

  private refreshRuntimeState(): void {
    const h = localRuntimeService.health()
    this.runtimeOk = h.ok
    this.runtimeProviders = h.ok ? localRuntimeService.listProviders().all : []
  }

  build() {
    Column() {
      // ── Page title ──
      Text('AI 配置')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .width('100%')
        .padding({ left: 24, top: 20, bottom: 12 })

      // ── Tabs ──
      Tabs({ barPosition: BarPosition.Start, index: this.currentTab }) {
        TabContent() {
          this.ModelSelectionTab()
        }
        .tabBar(this.TabBarBuilder('模型选择', 0))

        TabContent() {
          ProviderPage({ activeRunner: null })
        }
        .tabBar(this.TabBarBuilder('供应商配置', 1))
      }
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .barHeight(44)
      .width('100%')
      .layoutWeight(1)
      .onChange((index: number) => {
        this.currentTab = index
        if (index === 0) {
          this.refreshRuntimeState()
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#121212')
  }

  @Builder
  TabBarBuilder(label: string, index: number) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(this.currentTab === index ? '#007DFF' : '#CCCCCC')
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Normal)
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    }
    .alignItems(VerticalAlign.Center)
  }

  // ── Tab 1: 模型选择 ──
  @Builder
  ModelSelectionTab() {
    Scroll() {
      Column() {
        Text('当前模型')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .margin({ bottom: 8 })

        TextInput({ placeholder: 'providerId/modelId', text: this.modelInput })
          .width('100%')
          .height(40)
          .backgroundColor('#2D2D2D')
          .borderRadius(8)
          .fontColor('#FFFFFF')
          .onChange((value: string) => {
            this.modelInput = value
          })

        Row() {
          Button(this.saving ? '保存中...' : '保存模型')
            .height(40)
            .layoutWeight(1)
            .backgroundColor('#007DFF')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .margin({ top: 16, right: 6 })
            .enabled(!this.saving)
            .onClick(async () => {
              this.saving = true
              try {
                this.viewModel.selectedModel = this.modelInput
                await this.viewModel.saveServerConfig()
                await this.viewModel.syncModelToRuntime()
              } catch (e) {
                Logger.warn(`saveModel failed: ${errStr(e)}`)
              } finally {
                this.saving = false
              }
            })

          Button(this.testing ? '测试中...' : '测试模型')
            .height(40)
            .layoutWeight(1)
            .backgroundColor('#2D2D2D')
            .fontColor('#FFFFFF')
            .borderRadius(8)
            .margin({ top: 16, left: 6 })
            .enabled(!this.testing)
            .onClick(async () => {
              this.testing = true
              this.testResult = ''
              try {
                this.viewModel.selectedModel = this.modelInput
                await this.viewModel.syncModelToRuntime()
                this.testResult = await this.viewModel.testModel()
              } catch (e) {
                this.testResult = `测试出错: ${errStr(e)}`
              } finally {
                this.testing = false
              }
            })
        }
        .width('100%')

        if (this.testResult.length > 0) {
          Text(this.testResult)
            .fontSize(13)
            .fontColor('#FFFFFF')
            .margin({ top: 16 })
            .padding(12)
            .backgroundColor('#1E1E1E')
            .borderRadius(8)
            .width('100%')
        }

        Text('Runtime Providers')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .margin({ top: 28, bottom: 12 })

        this.RuntimeProvidersList()
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: 40 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Auto)
  }

  // ── Runtime providers list(从 LocalRuntimeService 拉) ──
  @Builder
  RuntimeProvidersList() {
    Column() {
      if (!this.runtimeOk) {
        Text('Runtime 未启动。请先在 Chat 页连接本地 Runtime。')
          .fontSize(13)
          .fontColor('#999999')
          .padding(12)
          .backgroundColor('#1E1E1E')
          .borderRadius(8)
          .width('100%')
      } else if (this.runtimeProviders.length === 0) {
        Text('暂无 Provider。请在"供应商配置"Tab 添加。')
          .fontSize(13)
          .fontColor('#999999')
          .padding(12)
          .backgroundColor('#1E1E1E')
          .borderRadius(8)
          .width('100%')
      } else {
        ForEach(this.runtimeProviders, (provider: LocalProviderConfig) => {
          this.ProviderCard(provider)
        }, (provider: LocalProviderConfig) => provider.id)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ProviderCard(provider: LocalProviderConfig) {
    Column() {
      Text(provider.name + (provider.enabled ? '' : ' (已禁用)'))
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)

      if (provider.models && provider.models.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(provider.models, (model: LocalModelConfig) => {
            Text(model.id)
              .fontSize(12)
              .fontColor(this.modelInput === `${provider.id}/${model.id}` ? '#FFFFFF' : '#CCCCCC')
              .backgroundColor(this.modelInput === `${provider.id}/${model.id}` ? '#007DFF' : '#2D2D2D')
              .padding({ left: 10, right: 10, top: 5, bottom: 5 })
              .borderRadius(12)
              .margin({ right: 6, bottom: 6 })
              .onClick(() => {
                const fullId = `${provider.id}/${model.id}`
                this.modelInput = fullId
                this.viewModel.selectedModel = fullId
              })
          }, (model: LocalModelConfig) => model.id)
        }
        .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#1E1E1E')
    .borderRadius(8)
    .margin({ bottom: 8 })
    .alignItems(HorizontalAlign.Start)
  }
}
