import { FullAppState, FullMessage, FullMessagePart } from '../../models/FullAppModels'
import { formatServerTitle } from '../../utils/DateTimeUtil'

@Component
export struct FullWorkspaceView {
  @Link state: FullAppState
  onSend: () => void = () => {}
  onAbort: () => void = () => {}
  onSelectSession: (id: string) => void = () => {}
  onNewSession: () => void = () => {}
  onOpenRuntime: () => void = () => {}
  onOpenProvider: () => void = () => {}
  onOpenFiles: () => void = () => {}
  onOpenDiff: () => void = () => {}
  onOpenPermissions: () => void = () => {}

  build() {
    Row() {
      Column() {
        this.NavButton('Chat', 'workspace')
        this.NavButton('Runtime', 'runtime')
        this.NavButton('Provider', 'provider')
        this.NavButton('Files', 'files')
        this.NavButton('Diff', 'diff')
        this.NavButton('Perm', 'permissions')
      }
      .width(80).height('100%').backgroundColor('#111111').borderWidth({ right: 1 }).borderColor('#292929')

      Column() {
        Row() {
          Text('+').fontSize(28).fontColor('#8d8d8d').width(54).height(48).textAlign(TextAlign.Center).onClick(() => this.onNewSession())
          Text('Sessions').fontSize(16).fontColor('#ddd').margin({ left: 8 })
        }
        .height(52).width('100%').borderWidth({ bottom: 1 }).borderColor('#292929')

        ForEach(this.state.sessions, (s: FullSession) => {
          Text(s.title !== undefined && s.title.length > 0 ? s.title : s.id)
            .fontSize(13)
            .fontColor(this.state.activeSessionId === s.id ? '#fff' : '#888')
            .padding(12)
            .width('100%')
            .backgroundColor(this.state.activeSessionId === s.id ? '#252525' : '#111111')
            .onClick(() => this.onSelectSession(s.id))
        }, (s: FullSession) => s.id)
      }
      .width(260).height('100%').backgroundColor('#111111').borderWidth({ right: 1 }).borderColor('#292929')

      Column() {
        Scroll() {
          Column() {
            ForEach(this.state.messages, (m: FullMessage) => {
              this.MessageBlock(m)
            }, (m: FullMessage) => m.id)
          }
          .width('100%').padding(20).alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1).width('100%')

        Row() {
          TextArea({ text: this.state.inputText, placeholder: 'Ask OpenCode...' })
            .layoutWeight(1).height(74).fontSize(15).fontColor('#e8e2dd').backgroundColor('#151515').onChange((v: string) => this.state.inputText = v)
          Text(this.state.isSending ? 'Stop' : 'Send')
            .width(80).height(54).fontSize(15).fontColor('#111').textAlign(TextAlign.Center).borderRadius(8).backgroundColor('#ddd').margin({ left: 12 })
            .onClick(() => this.state.isSending ? this.onAbort() : this.onSend())
        }
        .width('100%').padding(14).borderWidth({ top: 1 }).borderColor('#292929')
      }
      .layoutWeight(1).height('100%').backgroundColor('#101010')
    }
    .width('100%').height('100%').backgroundColor('#101010')
  }

  @Builder
  NavButton(label: string, page: string) {
    Text(label).fontSize(12).fontColor('#aaa').width(72).height(44).textAlign(TextAlign.Center).margin({ top: 8 }).onClick(() => this.state.activePage = page)
  }

  @Builder
  MessageBlock(m: FullMessage) {
    Column() {
      Text(m.role).fontSize(12).fontColor('#777').margin({ bottom: 8 })
      ForEach(m.parts, (p: FullMessagePart) => {
        if (p.type === 'tool') {
          Text(`[tool] ${p.tool}`).fontSize(13).fontColor('#caa').fontFamily('monospace').margin({ bottom: 6 })
        } else {
          Text(p.text).fontSize(15).fontColor('#ddd').margin({ bottom: 6 })
        }
      }, (p: FullMessagePart) => `${p.type}-${p.callID}-${p.text}`)
    }
    .width('100%').padding(14).borderRadius(10).backgroundColor(m.role === 'user' ? '#1d1d1d' : '#151515').margin({ bottom: 12 }).alignItems(HorizontalAlign.Start)
  }
}
