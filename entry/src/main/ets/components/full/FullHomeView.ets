import { FullAppState } from '../../models/FullAppModels'

@Component
export struct FullHomeView {
  @Link state: FullAppState
  onSend: () => void = () => {}
  onNewSession: () => void = () => {}
  onOpenRuntime: () => void = () => {}
  onOpenModels: () => void = () => {}
  onOpenFiles: () => void = () => {}

  build() {
    Column() {
      this.TopBar()

      Row() {
        this.LeftRail()
        this.Center()
        this.Right()
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#101010')
  }

  @Builder
  TopBar() {
    Row() {
      Row() {
        Circle().width(14).height(14).fill('#ff5f57')
        Circle().width(14).height(14).fill('#ffbd2e').margin({ left: 10 })
        Circle().width(14).height(14).fill('#28c840').margin({ left: 10 })
      }
      .width(120)
      .padding({ left: 14 })

      Text('\u270e').fontSize(18).fontColor('#FFFFFF').width(36).height(30).textAlign(TextAlign.Center).backgroundColor('#2b2b2b').borderRadius(7)

      Row() {
        Text(`搜索 ${this.state.projectName.length > 0 ? this.state.projectName : 'workspace'}`).fontSize(14).fontColor('#FFFFFF').layoutWeight(1)
        Text('\u2318K').fontSize(12).fontColor('#FFFFFF')
      }
      .width(310).height(31).padding({ left: 12, right: 12 }).borderRadius(8).borderWidth(1).borderColor('#292929').backgroundColor('#0c0c0c').margin({ left: 30 })

      Blank()

      Stack() {
        Text('\u25a4').fontSize(20).fontColor('#FFFFFF').width(36).textAlign(TextAlign.Center)
        if (this.state.isConnected) {
          Circle().width(8).height(8).fill('#3dd24a').position({ x: 26, y: 2 })
        }
      }
      .width(36).height(30).margin({ right: 18 }).onClick(() => this.onOpenRuntime())
    }
    .width('100%')
    .height(52)
    .borderWidth({ bottom: 1 })
    .borderColor('#292929')
    .backgroundColor('#101010')
  }

  @Builder
  LeftRail() {
    Column() {
      Text(`${this.state.sessions.length}`).fontSize(24).fontColor('#FFFFFF').width(52).height(52).textAlign(TextAlign.Center).backgroundColor('#4b2170').borderRadius(10).borderWidth(3).borderColor('#dedede').margin({ top: 16 })
      Text('+').fontSize(34).fontColor('#FFFFFF').width(52).height(52).textAlign(TextAlign.Center).margin({ top: 18 }).onClick(() => this.onNewSession())
      Blank()
      Text('\u2699').fontSize(24).fontColor('#FFFFFF').width(52).height(42).textAlign(TextAlign.Center).onClick(() => this.onOpenRuntime())
      Text('?').fontSize(22).fontColor('#FFFFFF').width(52).height(42).textAlign(TextAlign.Center).margin({ bottom: 20 })
    }
    .width(82).height('100%').backgroundColor('#111111').borderWidth({ right: 1 }).borderColor('#292929')
  }

  @Builder
  Center() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Column() {
        this.Logo(false)
        Text(this.state.projectName.length > 0 ? this.state.projectName : '\u6784\u5efa\u4efb\u4f55\u4e1c\u897f').fontSize(27).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ top: 32 })
        Text(this.state.runner === null ? '/workspace' : `${this.state.runner.protocol}://${this.state.runner.host}:${this.state.runner.port}`).fontSize(18).fontColor('#FFFFFF').margin({ top: 24 })
        Text(this.state.branchName.length > 0 ? this.state.branchName : '\u672a\u52a0\u8f7d\u5206\u652f').fontSize(16).fontColor('#FFFFFF').margin({ top: 28 })
      }
      .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)

      this.Composer()
    }
    .layoutWeight(1).height('100%').backgroundColor('#111111').borderWidth({ right: 1 }).borderColor('#292929')
  }

  @Builder
  Composer() {
    Column() {
      TextArea({ text: this.state.inputText, placeholder: '\u968f\u4fbf\u95ee\u70b9\u4ec0\u4e48... \u201c\u8fd9\u4e2a\u9519\u8bef\u662f\u4ec0\u4e48\u610f\u601d\uff1f\u201d' })
        .width('100%').height(116).fontSize(16).fontColor('#FFFFFF').placeholderColor('#757575').backgroundColor('#111111').padding({ left: 18, right: 70, top: 18, bottom: 18 })
        .onChange((v: string) => this.state.inputText = v)

      Row() {
        Text('\u2304').fontSize(16).fontColor('#FFFFFF')
        Text(this.state.defaultModel.length > 0 ? this.state.defaultModel : '\u9009\u62e9\u6a21\u578b').fontSize(16).fontColor('#FFFFFF').margin({ left: 22 }).onClick(() => this.onOpenModels())
        Blank()
        Text(this.state.isSending ? '\u00d7' : '\u2191').fontSize(23).fontColor('#FFFFFF').width(44).height(42).textAlign(TextAlign.Center).borderRadius(7).backgroundColor('#8d8d8d').margin({ right: 12 }).onClick(() => this.onSend())
      }
      .height(58).width('100%').padding({ left: 36 }).backgroundColor('#111111')
    }
    .width('calc(100% - 30px)').height(175).margin({ left: 15, right: 15, bottom: 14 }).borderRadius(14).borderWidth(1).borderColor('#2d2d2d').backgroundColor('#111111')
  }

  @Builder
  Right() {
    Column() {
      Row() {
        Text('+').fontSize(32).fontColor('#FFFFFF').width(64).height(62).textAlign(TextAlign.Center).borderWidth({ right: 1 }).borderColor('#292929').onClick(() => this.onOpenFiles())
      }
      .width('100%').height(62).borderWidth({ bottom: 1 }).borderColor('#292929')

      Column() {
        this.Logo(true)
        Text('\u9009\u62e9\u8981\u6253\u5f00\u7684\u6587\u4ef6').fontSize(18).fontColor('#FFFFFF').margin({ top: 34 })
      }
      .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center).onClick(() => this.onOpenFiles())
    }
    .layoutWeight(0.95).height('100%').backgroundColor('#111111')
  }

  @Builder
  Logo(dim: boolean) {
    Stack() {
      Rect().width(dim ? 74 : 54).height(dim ? 90 : 66).fill(dim ? '#282828' : '#e8e4de')
      Rect().width(dim ? 36 : 26).height(dim ? 54 : 38).fill('#111111')
    }
  }
}
