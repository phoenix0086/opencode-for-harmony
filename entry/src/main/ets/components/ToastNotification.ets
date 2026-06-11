import { Theme } from './Theme'

// ════════════════════════════════════════════════════════════
// ToastData — data model for a single toast notification
// ════════════════════════════════════════════════════════════

export class ToastData {
  id: string = ''
  message: string = ''
  type: string = 'info' // 'info' | 'success' | 'warning' | 'error'
  duration: number = 3000 // ms
}

// ════════════════════════════════════════════════════════════
// ToastItem — internal component rendering a single toast
// ════════════════════════════════════════════════════════════

@Component
struct ToastItem {
  @Prop message: string = ''
  @Prop type: string = 'info'
  onDismiss: () => void = () => {}
  @State visible: boolean = false
  private appearTimer: number = -1

  aboutToDisappear(): void {
    if (this.appearTimer >= 0) {
      clearTimeout(this.appearTimer)
      this.appearTimer = -1
    }
  }

  build() {
    Row() {
      // Status icon
      Text(this.type === 'success' ? '\u2713'
        : this.type === 'warning' ? '!'
        : this.type === 'error' ? '\u2715'
        : 'i')
        .fontSize(Theme.fs.xs)
        .fontFamily(Theme.FONT_MONO)
        .fontColor(
          this.type === 'success' ? Theme.SUCCESS
            : this.type === 'warning' ? Theme.WARNING
            : this.type === 'error' ? Theme.DANGER
            : Theme.ACCENT
        )
        .width(20)
        .textAlign(TextAlign.Center)

      // Message text
      Text(this.message)
        .fontSize(Theme.fs.sm)
        .fontFamily(Theme.FONT_MONO)
        .fontColor(Theme.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ left: Theme.sp.md })

      // Dismiss button
      Text('\u00D7')
        .fontSize(Theme.fs.lg)
        .fontFamily(Theme.FONT_MONO)
        .fontColor(Theme.TEXT_MUTED)
        .margin({ left: Theme.sp.md })
        .onClick(() => {
          this.onDismiss()
        })
    }
    .width('100%')
    .padding({
      left: Theme.sp.lg,
      right: Theme.sp.lg,
      top: Theme.sp.md,
      bottom: Theme.sp.md
    })
    .backgroundColor(
      this.type === 'success' ? Theme.SUCCESS_DIM
        : this.type === 'warning' ? Theme.WARNING_DIM
        : this.type === 'error' ? Theme.DANGER_DIM
        : Theme.ACCENT_DIM
    )
    .border({
      width: 1,
      color: Theme.BORDER,
      style: BorderStyle.Solid
    })
    .borderRadius(Theme.rd.lg)
    .constraintSize({ maxWidth: 400 })
    .opacity(this.visible ? 1 : 0)
    .animation({ duration: 300, curve: Curve.EaseOut })
    .onAppear(() => {
      this.appearTimer = setTimeout(() => {
        this.visible = true
      }, 50)
    })
  }
}

// ════════════════════════════════════════════════════════════
// ToastContainer — overlay rendering active toasts
// ════════════════════════════════════════════════════════════

@Component
export struct ToastContainer {
  @StorageProp('themeId') themeId: string = 'catppuccin'
  @Prop toasts: ToastData[] = []
  onDismiss: (id: string) => void = () => {}

  build() {
    Stack() {
      Column() {
        ForEach(this.toasts.slice(-3), (toast: ToastData) => {
          ToastItem({
            message: toast.message,
            type: toast.type,
            onDismiss: () => {
              this.onDismiss(toast.id)
            }
          })
            .margin({ top: Theme.sp.md })
        }, (toast: ToastData) => toast.id)
      }
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: Theme.sp.xxl })
    }
    .width('100%')
    .height('100%')
    .alignContent(Alignment.Bottom)
    .hitTestBehavior(HitTestMode.Transparent)
  }
}

// ════════════════════════════════════════════════════════════
// ToastManager — static utility for managing toast lifecycle
// ════════════════════════════════════════════════════════════

export class ToastManager {
  private static _toasts: ToastData[] = []
  private static _onChange: (() => void) | null = null
  private static _timers: number[] = []

  static setOnChange(handler: (() => void) | null): void {
    ToastManager._onChange = handler
    // Clear all pending auto-dismiss timers when handler is unset (component unmount)
    if (handler === null) {
      for (const t of ToastManager._timers) {
        clearTimeout(t)
      }
      ToastManager._timers = []
    }
  }

  static show(message: string, type: string = 'info', duration: number = 3000): void {
    const toast = new ToastData()
    toast.id = `toast_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`
    toast.message = message
    toast.type = type
    toast.duration = duration
    ToastManager._toasts.push(toast)
    if (ToastManager._onChange) {
      ToastManager._onChange()
    }
    // Auto-dismiss after duration
    const timerId = setTimeout(() => {
      ToastManager.dismiss(toast.id)
    }, duration)
    ToastManager._timers.push(timerId)
  }

  static dismiss(id: string): void {
    const next: ToastData[] = []
    for (const t of ToastManager._toasts) {
      if (t.id !== id) {
        next.push(t)
      }
    }
    ToastManager._toasts = next
    if (ToastManager._onChange) {
      ToastManager._onChange()
    }
  }

  static getToasts(): ToastData[] {
    return ToastManager._toasts
  }
}
