import { FullAppState, FullPermission, FullLog } from '../../models/FullAppModels'

@Component
export struct FullPermissionLogView {
  @Link state: FullAppState
  @Prop mode: string = 'permissions'
  onRefreshPermissions: () => void = () => {}
  onReply: (id: string, reply: string) => void = () => {}

  build() {
    Scroll() {
      Column() {
        Text(this.mode === 'logs' ? 'Logs' : 'Permissions').fontSize(28).fontWeight(FontWeight.Bold).fontColor('#eee').margin({ bottom: 24 })

        if (this.mode === 'permissions') {
          Text('\u5237\u65b0\u6743\u9650').fontSize(14).fontColor('#111').backgroundColor('#ddd').padding(10).borderRadius(8).margin({ bottom: 14 }).onClick(() => this.onRefreshPermissions())
          ForEach(this.state.permissions, (p: FullPermission) => {
            Row() {
              Text(p.title.length > 0 ? p.title : p.id).fontSize(14).fontColor('#ddd').layoutWeight(1)
              Text('once').fontSize(12).fontColor('#111').backgroundColor('#ddd').padding(8).borderRadius(6).margin({ right: 8 }).onClick(() => this.onReply(p.id, 'once'))
              Text('deny').fontSize(12).fontColor('#fff').backgroundColor('#833').padding(8).borderRadius(6).onClick(() => this.onReply(p.id, 'deny'))
            }.width('100%').padding(12).backgroundColor('#151515').borderRadius(8).margin({ bottom: 8 })
          }, (p: FullPermission) => p.id)
        } else {
          ForEach(this.state.logs, (l: FullLog) => {
            Text(`[${l.level}] ${l.category}: ${l.message}`).fontSize(13).fontColor('#aaa').fontFamily('monospace').width('100%').margin({ bottom: 6 })
          }, (l: FullLog) => `${l.time}-${l.message}`)
        }
      }.padding(40).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').backgroundColor('#101010')
  }
}
