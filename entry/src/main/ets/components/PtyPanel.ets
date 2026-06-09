import { Theme } from './Theme'
import { PtySessionInfo, PtyChunk } from '../services/V2Type'

/**
 * PtyPanel — 嵌入式终端 (Sprint 2-A.1)
 *
 * - 列出当前所有 PTY session
 * - 选定 session 显示输出 buffer
 * - 底部 input bar → 写 stdin
 * - 选定 session 启动 poller,每 1s 拉取 chunk
 *
 * v2-only。v1 server 会显示 "unsupported" 占位。
 */
@Component
export struct PtyPanel {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop sessions: PtySessionInfo[] = []
  @Prop activeSessionID: string = ''
  @Prop outputBuffer: string = ''
  @Prop isLoading: boolean = false
  @Prop unsupported: boolean = false
  @Prop errorMessage: string = ''
  @State inputText: string = ''
  onRefresh: () => void = () => {}
  onStart: (command: string) => void = () => {}
  onSelect: (sessionID: string) => void = () => {}
  onClose: (sessionID: string) => void = () => {}
  onSendInput: (sessionID: string, data: string) => void = () => {}

  build() {
    Column() {
      // ═══════ Header ═══════
      Row() {
        Text('terminal')
          .fontSize(Theme.fs.md)
          .fontColor(Theme.ACCENT)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)

        if (this.sessions.length > 0) {
          Text(`${this.sessions.length}`)
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ left: Theme.sp.sm })
        }

        Blank()

        Button(this.isLoading ? '...' : 'refresh')
          .height(28)
          .fontSize(Theme.fs.xs)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.BTN_BG)
          .fontColor(Theme.TEXT_PRIMARY)
          .enabled(!this.isLoading)
          .onClick((): void => { this.onRefresh() })
      }
      .width('100%')
      .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.sm, bottom: Theme.sp.sm })
      .backgroundColor(Theme.HEADER_BG)

      Divider()
        .color(Theme.BORDER)
        .height(1)

      // ═══════ Session Tabs ═══════
      if (this.sessions.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.sessions, (s: PtySessionInfo) => {
              this.SessionTab(s)
            }, (s: PtySessionInfo) => s.id)
          }
          .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: Theme.sp.xs, bottom: Theme.sp.xs })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .height(36)
        .backgroundColor(Theme.PANEL_BG)

        Divider()
          .color(Theme.BORDER)
          .height(1)
      }

      // ═══════ Body ═══════
      if (this.unsupported) {
        Column() {
          Text('!')
            .fontSize(Theme.fs.xxl)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
          Text('pty not supported')
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.TEXT_PRIMARY)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
          Text('requires v2 server')
            .fontSize(Theme.fs.xs)
            .fontColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.xs })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else if (this.errorMessage.length > 0) {
        Column() {
          Text('!')
            .fontSize(Theme.fs.xl)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
          Text(this.errorMessage)
            .fontSize(Theme.fs.sm)
            .fontColor(Theme.DANGER)
            .fontFamily(Theme.FONT_MONO)
            .margin({ top: Theme.sp.sm })
            .maxLines(4)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .padding(Theme.sp.xl)
      } else {
        Column() {
          // Terminal output area
          Scroll() {
            Text(this.outputBuffer.length > 0 ? this.outputBuffer : '(no output yet)')
              .fontSize(Theme.fs.xs)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .textAlign(TextAlign.Start)
              .width('100%')
              .padding(Theme.sp.sm)
          }
          .layoutWeight(1)
          .width('100%')
          .backgroundColor('#000000')
          .scrollBar(BarState.Auto)
          .scrollable(ScrollDirection.Vertical)

          Divider()
            .color(Theme.BORDER)
            .height(1)

          // Input bar
          Row() {
            TextInput({ text: this.inputText, placeholder: this.activeSessionID.length > 0 ? '$ ' : 'start: bash, ls, ...' })
              .layoutWeight(1)
              .height(36)
              .fontSize(Theme.fs.sm)
              .fontFamily(Theme.FONT_MONO)
              .backgroundColor(Theme.CODE_BG)
              .fontColor(Theme.TEXT_PRIMARY)
              .placeholderColor(Theme.TEXT_MUTED)
              .onChange((v: string): void => { this.inputText = v })
              .onSubmit((): void => {
                this.handleSubmit()
              })

            if (this.activeSessionID.length > 0) {
              Button('send')
                .height(36)
                .fontSize(Theme.fs.xs)
                .fontFamily(Theme.FONT_MONO)
                .backgroundColor(Theme.ACCENT)
                .fontColor(Theme.ACCENT_TEXT)
                .margin({ left: Theme.sp.xs })
                .onClick((): void => { this.handleSubmit() })
            } else {
              Button('start')
                .height(36)
                .fontSize(Theme.fs.xs)
                .fontFamily(Theme.FONT_MONO)
                .backgroundColor(Theme.ACCENT)
                .fontColor(Theme.ACCENT_TEXT)
                .margin({ left: Theme.sp.xs })
                .onClick((): void => { this.handleSubmit() })
            }
          }
          .width('100%')
          .padding(Theme.sp.xs)
          .backgroundColor(Theme.PANEL_BG)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.PANEL_BG)
  }

  // ═══════ Session Tab ═══════
  @Builder
  SessionTab(s: PtySessionInfo) {
    Row() {
      Circle({ width: 6, height: 6 })
        .fill(s.status === 'running' ? Theme.SUCCESS : Theme.TEXT_MUTED)
        .margin({ right: Theme.sp.xs })

      Text(s.title.length > 0 ? s.title : s.id.substring(0, 6))
        .fontSize(Theme.fs.xs)
        .fontColor(this.activeSessionID === s.id ? Theme.ACCENT_TEXT : Theme.TEXT_PRIMARY)
        .fontFamily(Theme.FONT_MONO)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .constraintSize({ maxWidth: 80 })

      if (this.activeSessionID === s.id) {
        Text('x')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.DANGER)
          .fontFamily(Theme.FONT_MONO)
          .margin({ left: Theme.sp.xs })
          .onClick((): void => { this.onClose(s.id) })
      }
    }
    .height(28)
    .padding({ left: Theme.sp.sm, right: Theme.sp.sm, top: Theme.sp.xs, bottom: Theme.sp.xs })
    .backgroundColor(this.activeSessionID === s.id ? Theme.ACCENT : Theme.BTN_BG)
    .borderRadius(Theme.rd.sm)
    .margin({ right: Theme.sp.xs })
    .onClick((): void => {
      if (this.activeSessionID !== s.id) {
        this.onSelect(s.id)
      }
    })
  }

  private handleSubmit(): void {
    const text = this.inputText
    this.inputText = ''
    if (text.length === 0) return
    if (this.activeSessionID.length > 0) {
      // Send to existing session
      this.onSendInput(this.activeSessionID, text + '\n')
    } else {
      // Start new session
      this.onStart(text)
    }
  }
}
