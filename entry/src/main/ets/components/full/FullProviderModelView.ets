import { FullAppState, FullProviderInput, FullModelInput, FullModelOption } from '../../models/FullAppModels'

@Component
export struct FullProviderModelView {
  @Link state: FullAppState
  @State providerId: string = ''
  @State displayName: string = ''
  @State baseURL: string = ''
  @State apiKey: string = ''
  @State modelId: string = ''
  @State modelName: string = ''
  @State status: string = ''

  onSaveProvider: (p: FullProviderInput) => void = () => {}
  onSetModel: (model: string) => void = () => {}

  build() {
    Scroll() {
      Column() {
        Text('Provider / Model').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#eee').margin({ bottom: 24 })
        this.Field('Provider ID', this.providerId, (v: string) => this.providerId = v)
        this.Field('\u663e\u793a\u540d\u79f0', this.displayName, (v: string) => this.displayName = v)
        this.Field('Base URL', this.baseURL, (v: string) => this.baseURL = v)
        this.Field('API Key', this.apiKey, (v: string) => this.apiKey = v)
        this.Field('Model ID', this.modelId, (v: string) => this.modelId = v)
        this.Field('Model Name', this.modelName, (v: string) => this.modelName = v)

        Text('\u4fdd\u5b58 Provider').fontSize(14).fontColor('#111').backgroundColor('#ddd').padding(12).borderRadius(8).onClick(() => this.save())

        Text('\u53ef\u7528\u6a21\u578b').fontSize(18).fontColor('#eee').margin({ top: 30, bottom: 12 })
        ForEach(this.state.models, (m: FullModelOption) => {
          Row() {
            Text(m.modelRef).fontSize(14).fontColor('#ddd').layoutWeight(1)
            Text('\u8bbe\u9ed8\u8ba4').fontSize(12).fontColor('#111').backgroundColor('#ddd').padding(8).borderRadius(6).onClick(() => this.onSetModel(m.modelRef))
          }.width('100%').padding(12).backgroundColor('#151515').borderRadius(8).margin({ bottom: 8 })
        }, (m: FullModelOption) => m.modelRef)

        Text(this.status).fontSize(14).fontColor('#aaa').margin({ top: 20 })
      }.padding(40).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').backgroundColor('#101010')
  }

  @Builder
  Field(label: string, value: string, onChange: (v: string) => void) {
    Column() {
      Text(label).fontSize(12).fontColor('#777').margin({ bottom: 6 })
      TextInput({ text: value, placeholder: label }).height(38).width('100%').fontSize(14).fontColor('#ddd').backgroundColor('#151515').borderRadius(8).onChange((v: string) => onChange(v))
    }.width('100%').margin({ bottom: 14 })
  }

  private save(): void {
    const p = new FullProviderInput()
    p.providerId = this.providerId
    p.displayName = this.displayName
    p.baseURL = this.baseURL
    p.apiKey = this.apiKey
    const m = new FullModelInput()
    m.id = this.modelId
    m.name = this.modelName.length > 0 ? this.modelName : this.modelId
    p.models.push(m)
    this.onSaveProvider(p)
    this.status = 'Provider saved'
  }
}
