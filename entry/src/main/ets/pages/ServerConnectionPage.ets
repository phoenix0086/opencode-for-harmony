import { Runner, createRunner, RunnerConfig } from '../models/Runner'
import { OpenCodeClient, HealthResult } from '../services/OpenCodeClient'
import { storageService } from '../services/StorageService'

/**
 * Server 连接管理页面
 * 配置 OpenCode Server 地址、测试连接、管理 Runner
 */
@Component
export struct ServerConnectionPage {
  @Link runners: Runner[]
  @Link activeRunner: Runner | null
  @State showForm: boolean = false
  @State formName: string = ''
  @State formHost: string = '127.0.0.1'
  @State formPort: string = '4096'
  @State formToken: string = ''
  @State formProtocol: string = 'http'
  @State connectionStatus: string = ''
  @State isTesting: boolean = false

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('服务器管理')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E293B')
        Blank()
        Button('+ 添加')
          .type(ButtonType.Capsule)
          .backgroundColor('#4F46E5')
          .fontColor('#FFFFFF')
          .fontSize(13)
          .onClick(() => {
            this.resetForm()
            this.showForm = true
          })
      }
      .width('100%')
      .margin({ bottom: 20 })

      Scroll() {
        Column() {
          // 添加/编辑表单
          if (this.showForm) {
            this.FormBuilder()
          }

          // Runner 列表
          if (this.runners.length === 0 && !this.showForm) {
            Column() {
              Text('🖥')
                .fontSize(48)
              Text('还没有配置服务器')
                .fontSize(14)
                .fontColor('#94A3B8')
                .margin({ top: 12 })
              Text('点击右上角按钮添加 OpenCode Server')
                .fontSize(13)
                .fontColor('#94A3B8')
                .margin({ top: 8 })
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: 60, bottom: 60 })
          } else {
            ForEach(this.runners, (runner: Runner) => {
              this.RunnerCard(runner)
            }, (runner: Runner) => runner.id)
          }

          // 连接状态
          if (this.connectionStatus !== '') {
            Text(this.connectionStatus)
              .fontSize(13)
              .fontColor(this.connectionStatus.includes('成功') || this.connectionStatus.includes('已') ? '#22C55E' : '#EF4444')
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
  FormBuilder() {
    Column() {
      Text('添加 OpenCode Server')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1E293B')
        .margin({ bottom: 16 })

      this.FormField('名称', this.formName, (v: string) => { this.formName = v })
      this.FormField('地址', this.formHost, (v: string) => { this.formHost = v })
      this.FormField('端口', this.formPort, (v: string) => { this.formPort = v })
      this.FormField('密码 (可选)', this.formToken, (v: string) => { this.formToken = v })

      Row() {
        Button('取消')
          .type(ButtonType.Normal)
          .backgroundColor('#F1F5F9')
          .fontColor('#334155')
          .borderRadius(8)
          .onClick(() => { this.showForm = false })

        Button('保存')
          .type(ButtonType.Normal)
          .backgroundColor('#4F46E5')
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 12 })
          .onClick(() => this.saveRunner())
      }
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(20)
    .borderRadius(12)
    .backgroundColor('#F8FAFC')
    .borderWidth(1)
    .borderColor('#E2E8F0')
    .margin({ bottom: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  FormField(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label)
        .fontSize(13)
        .fontColor('#64748B')
        .margin({ bottom: 6 })
      TextInput({ text: value, placeholder: `请输入${label}` })
        .width('100%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .borderRadius(8)
        .borderWidth(1)
        .borderColor('#E2E8F0')
        .type(label.includes('密码') ? InputType.Password : InputType.Normal)
        .onChange((v: string) => onChange(v))
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  RunnerCard(runner: Runner) {
    Row() {
      Circle({ width: 10, height: 10 })
        .fill(runner.status === 'online' ? '#22C55E' :
          runner.status === 'offline' ? '#EF4444' : '#94A3B8')

      Column() {
        Row() {
          Text(runner.name)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E293B')
          if (this.activeRunner !== null && this.activeRunner!.id === runner.id) {
            Text('当前')
              .fontSize(10)
              .fontColor('#4F46E5')
              .backgroundColor('#E0E7FF')
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .margin({ left: 8 })
          }
        }
        Text(`${runner.protocol}://${runner.host}:${runner.port}`)
          .fontSize(12)
          .fontColor('#64748B')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: 12 })
      .alignItems(HorizontalAlign.Start)

      Button('测试')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(32)
        .backgroundColor('#F1F5F9')
        .fontColor('#334155')
        .borderRadius(8)
        .onClick(() => this.testConnection(runner))

      Button('使用')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(32)
        .backgroundColor('#4F46E5')
        .fontColor('#FFFFFF')
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => this.setActive(runner))

      Button('删除')
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(32)
        .backgroundColor('#FEE2E2')
        .fontColor('#EF4444')
        .borderRadius(8)
        .margin({ left: 8 })
        .onClick(() => this.deleteRunner(runner))
    }
    .width('100%')
    .padding(16)
    .borderRadius(12)
    .backgroundColor('#FAFBFC')
    .borderWidth(1)
    .borderColor('#E2E8F0')
    .margin({ bottom: 8 })
    .alignItems(VerticalAlign.Center)
  }

  // ══════════ 业务方法 ══════════

  resetForm(): void {
    this.formName = ''
    this.formHost = '127.0.0.1'
    this.formPort = '4096'
    this.formToken = ''
    this.formProtocol = 'http'
  }

  async saveRunner(): Promise<void> {
    if (this.formHost === '' || this.formPort === '') {
      this.connectionStatus = '请填写地址和端口'
      return
    }
    const config = new RunnerConfig()
    config.name = this.formName !== '' ? this.formName : `${this.formHost}:${this.formPort}`
    config.host = this.formHost
    config.port = parseInt(this.formPort)
    config.protocol = this.formProtocol as 'http' | 'https'
    config.token = this.formToken
    const runner = createRunner(config)
    const newList: Runner[] = []
    for (const r of this.runners) { newList.push(r) }
    newList.push(runner)
    this.runners = newList
    await storageService.saveRunners(this.runners)
    this.showForm = false
    this.connectionStatus = '服务器已添加，点击"测试"验证连接'
  }

  async testConnection(runner: Runner): Promise<void> {
    this.connectionStatus = '正在测试连接...'
    this.isTesting = true
    const client = new OpenCodeClient(runner)
    const result = await client.health()
    const newList: Runner[] = []
    for (const r of this.runners) {
      if (r.id === runner.id) {
        const updated = new Runner()
        updated.id = r.id
        updated.name = r.name
        updated.host = r.host
        updated.port = r.port
        updated.protocol = r.protocol
        updated.token = r.token
        updated.status = result.ok ? 'online' : 'offline'
        updated.version = result.version
        updated.lastConnectedAt = Date.now()
        updated.createdAt = r.createdAt
        updated.updatedAt = Date.now()
        newList.push(updated)
      } else {
        newList.push(r)
      }
    }
    this.runners = newList
    await storageService.saveRunners(this.runners)
    if (this.activeRunner !== null && this.activeRunner!.id === runner.id) {
      for (const r of this.runners) {
        if (r.id === runner.id) {
          this.activeRunner = r
          break
        }
      }
    }
    this.connectionStatus = result.ok ? `连接成功！版本: ${result.version}` : `连接失败: ${result.error}`
    this.isTesting = false
  }

  async setActive(runner: Runner): Promise<void> {
    this.activeRunner = runner
    await storageService.setActiveRunnerId(runner.id)
    this.connectionStatus = `已切换到 ${runner.name}`
  }

  async deleteRunner(runner: Runner): Promise<void> {
    const newList: Runner[] = []
    for (const r of this.runners) {
      if (r.id !== runner.id) newList.push(r)
    }
    this.runners = newList
    await storageService.saveRunners(this.runners)
    if (this.activeRunner !== null && this.activeRunner!.id === runner.id) {
      this.activeRunner = null
      await storageService.setActiveRunnerId('')
    }
  }
}
