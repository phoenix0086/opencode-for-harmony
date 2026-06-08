import { Theme } from './Theme'

/**
 * TerminalPanel — placeholder for embedded terminal integration (M19.4)
 *
 * OpenCode Desktop uses xterm.js for an embedded terminal.
 * On HarmonyOS, this can be achieved via:
 *
 * 1. WebView + xterm.js (recommended)
 *    - Load xterm.js from CDN or local assets in a Web component
 *    - Communicate via JavaScript proxy / postMessage
 *    - Requires: Web component, internet permission or local asset bundling
 *
 * 2. Native Shell Component
 *    - Use @ohos.process to spawn shell processes
 *    - Render output in a Scroll + Text component
 *    - Limited interactivity, no ANSI escape code support
 *
 * 3. Custom PTY via NAPI
 *    - Build a native C/C++ PTY bridge via Node-API
 *    - Most powerful but requires native compilation
 *
 * Current implementation: placeholder panel showing approach info.
 * Full implementation depends on target device capabilities.
 */
@Component
export struct TerminalPanel {
  @Prop projectName: string = ''
  @State commandHistory: string[] = []
  @State inputCommand: string = ''

  build() {
    Column() {
      // Header
      Row() {
        Text('TERMINAL')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontWeight(FontWeight.Bold)
          .fontFamily(Theme.FONT_MONO)
          .letterSpacing(1)

        Blank()

        Text('stub')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.WARNING)
          .fontFamily(Theme.FONT_MONO)
          .backgroundColor(Theme.WARNING_DIM)
          .borderRadius(Theme.rd.sm)
          .padding({ left: Theme.sp.md, right: Theme.sp.md, top: Theme.sp.xs, bottom: Theme.sp.xs })
      }
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg, top: Theme.sp.lg, bottom: Theme.sp.md })

      Divider()
        .color(Theme.BORDER)
        .strokeWidth(1)
        .margin({ left: Theme.sp.md, right: Theme.sp.md })

      // Terminal area (placeholder)
      Column() {
        // Simulated terminal prompt
        ForEach(this.commandHistory, (line: string, index: number) => {
          Row() {
            Text('$')
              .fontSize(Theme.fs.code)
              .fontColor(Theme.SUCCESS)
              .fontFamily(Theme.FONT_MONO)
              .margin({ right: Theme.sp.md })
            Text(line)
              .fontSize(Theme.fs.code)
              .fontColor(Theme.TEXT_PRIMARY)
              .fontFamily(Theme.FONT_MONO)
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: Theme.sp.xs, bottom: Theme.sp.xs })
        }, (line: string, index: number) => index.toString())

        // Input prompt
        Row() {
          Text('$')
            .fontSize(Theme.fs.code)
            .fontColor(Theme.SUCCESS)
            .fontFamily(Theme.FONT_MONO)
            .margin({ right: Theme.sp.md })

          TextInput({ placeholder: 'type a command...', text: this.inputCommand })
            .fontSize(Theme.fs.code)
            .fontColor(Theme.TEXT_PRIMARY)
            .placeholderColor(Theme.TEXT_MUTED)
            .fontFamily(Theme.FONT_MONO)
            .backgroundColor('transparent')
            .layoutWeight(1)
            .caretColor(Theme.ACCENT)
            .onSubmit(() => {
              if (this.inputCommand.trim().length > 0) {
                const updated: string[] = [...this.commandHistory]
                updated.push(this.inputCommand.trim())
                this.commandHistory = updated
                this.inputCommand = ''
              }
            })
            .onChange((value: string) => {
              this.inputCommand = value
            })
        }
        .width('100%')
        .padding({ top: Theme.sp.sm, bottom: Theme.sp.sm })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: Theme.sp.lg, right: Theme.sp.lg })
      .backgroundColor(Theme.PANEL)

      // Info footer
      Column() {
        Text('WebView + xterm.js integration planned')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .textAlign(TextAlign.Center)

        Text('Full terminal emulation requires Web component with xterm.js library')
          .fontSize(Theme.fs.xs)
          .fontColor(Theme.TEXT_MUTED)
          .fontFamily(Theme.FONT_MONO)
          .textAlign(TextAlign.Center)
          .margin({ top: Theme.sp.xs })
      }
      .width('100%')
      .padding({
        left: Theme.sp.lg,
        right: Theme.sp.lg,
        top: Theme.sp.md,
        bottom: Theme.sp.md
      })
      .borderWidth({ top: 1 })
      .borderColor(Theme.BORDER)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.BG)
  }
}
