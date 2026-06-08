import { FullAppState } from '../../models/FullAppModels'

@Component
export struct FullRuntimeView {
  @Link state: FullAppState
  onPrepare: () => void = () => {}
  onHealth: () => void = () => {}
  onActivate: () => void = () => {}

  build() {
    Scroll() {
      Column() {
        Text('\u672c\u5730 Runtime').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#eee').margin({ bottom: 24 })
        this.ModeRow()
        this.Field('Host', this.state.runtimeConfig.host, (v: string) => this.state.runtimeConfig.host = v)
        this.Field('Port', `${this.state.runtimeConfig.port}`, (v: string) => {
          const n = Number(v)
          if (!Number.isNaN(n)) this.state.runtimeConfig.port = n
        })
        this.Field('Token', this.state.runtimeConfig.token, (v: string) => this.state.runtimeConfig.token = v)

        Text(this.state.runtimeState.command).fontSize(13).fontColor('#ddd').fontFamily('monospace').padding(14).backgroundColor('#151515').borderRadius(8).width('100%').margin({ top: 18 })
        Text(this.state.runtimeState.message).fontSize(14).fontColor('#aaa').margin({ top: 14 })

        Row() {
          this.Button('\u542f\u52a8\u547d\u4ee4', () => this.onPrepare())
          this.Button('\u68c0\u6d4b', () => this.onHealth())
          this.Button('\u4fdd\u5b58\u5e76\u8fde\u63a5', () => this.onActivate())
        }
        .margin({ top: 18 })
      }
      .padding(40).width('100%').alignItems(HorizontalAlign.Start)
    }
    .width('100%').height('100%').backgroundColor('#101010')
  }

  @Builder
  ModeRow() {
    Row() {
      this.Mode('local', '\u672c\u673a')
      this.Mode('dev-pc', '\u5f00\u53d1\u7535\u8111')
      this.Mode('remote', '\u8fdc\u7a0b')
    }.margin({ bottom: 20 })
  }

  @Builder
  Mode(id: string, label: string) {
    Text(label).fontSize(14).fontColor(this.state.runtimeConfig.mode === id ? '#111' : '#ccc').backgroundColor(this.state.runtimeConfig.mode === id ? '#ddd' : '#222').padding({ left: 14, right: 14, top: 8, bottom: 8 }).borderRadius(8).margin({ right: 10 }).onClick(() => this.state.runtimeConfig.mode = id)
  }

  @Builder
  Field(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label).fontSize(12).fontColor('#777').margin({ bottom: 6 })
      TextInput({ text: value, placeholder: label }).height(38).width('100%').fontSize(14).fontColor('#ddd').backgroundColor('#151515').borderRadius(8).onChange((v: string) => onChange(v))
    }.width('100%').margin({ bottom: 14 })
  }

  @Builder
  Button(label: string, action: () => void) {
    Text(label).fontSize(14).fontColor('#111').backgroundColor('#ddd').padding({ left: 16, right: 16, top: 10, bottom: 10 }).borderRadius(8).margin({ right: 10 }).onClick(() => action())
  }
}
