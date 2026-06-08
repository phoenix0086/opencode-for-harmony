import { FullAppState, FullFileItem, FullDiff } from '../../models/FullAppModels'

@Component
export struct FullFileDiffView {
  @Link state: FullAppState
  @Prop mode: string = 'files'
  onLoadFiles: () => void = () => {}
  onOpenFile: (path: string) => void = () => {}
  onLoadDiff: () => void = () => {}

  build() {
    Row() {
      Column() {
        Text(this.mode === 'diff' ? 'Diff' : 'Files').fontSize(24).fontWeight(FontWeight.Bold).fontColor('#eee').margin({ bottom: 20 })
        if (this.mode === 'diff') {
          Text('\u5237\u65b0 Diff').fontSize(14).fontColor('#111').backgroundColor('#ddd').padding(10).borderRadius(8).onClick(() => this.onLoadDiff())
          ForEach(this.state.diffs, (d: FullDiff) => {
            Text(`${d.status} ${d.file} +${d.additions} -${d.deletions}`).fontSize(13).fontColor('#ddd').padding(10).backgroundColor('#151515').width('100%').margin({ top: 8 })
          }, (d: FullDiff) => d.file)
        } else {
          Text('\u52a0\u8f7d\u6587\u4ef6').fontSize(14).fontColor('#111').backgroundColor('#ddd').padding(10).borderRadius(8).onClick(() => this.onLoadFiles())
          ForEach(this.state.files, (f: FullFileItem) => {
            Text(`${f.type} ${f.path}`).fontSize(13).fontColor('#ddd').padding(10).backgroundColor('#151515').width('100%').margin({ top: 8 }).onClick(() => this.onOpenFile(f.path))
          }, (f: FullFileItem) => f.path)
        }
      }.width(360).height('100%').padding(24).backgroundColor('#101010').borderWidth({ right: 1 }).borderColor('#292929')

      Scroll() {
        Text(this.mode === 'diff' ? this.state.diffs.map((d: FullDiff) => d.patch).join('\n\n') : this.state.fileContent)
          .fontSize(13).fontColor('#ddd').fontFamily('monospace').padding(24)
      }.layoutWeight(1).height('100%').backgroundColor('#0f0f0f')
    }.width('100%').height('100%')
  }
}
