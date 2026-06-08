/**
 * OpenCode Harmony Native - Design Token System
 * IDE/Developer Tool visual language for ArkUI
 */

export class FontSizes {
  xs: number = 10
  sm: number = 12
  md: number = 13
  lg: number = 15
  xl: number = 18
  code: number = 12
}

export class Spacing {
  xs: number = 2
  sm: number = 4
  md: number = 8
  lg: number = 12
  xl: number = 16
  xxl: number = 24
}

export class Radius {
  sm: number = 2
  md: number = 4
  lg: number = 6
}

export class Theme {
  // ══════════ Core Backgrounds ══════════
  static readonly BG: string = '#1e1e2e'
  static readonly BG_ALT: string = '#181825'
  static readonly PANEL: string = '#11111b'
  static readonly SIDEBAR: string = '#181825'
  static readonly STATUSBAR: string = '#11111b'
  static readonly COMPOSER: string = '#1e1e2e'
  static readonly COMPOSER_BORDER: string = '#45475a'
  static readonly INPUT_BG: string = '#11111b'

  // ══════════ Borders ══════════
  static readonly BORDER: string = '#313244'
  static readonly BORDER_LIGHT: string = '#45475a'
  static readonly BORDER_FOCUS: string = '#89b4fa'

  // ══════════ Text ══════════
  static readonly TEXT_PRIMARY: string = '#cdd6f4'
  static readonly TEXT_SECONDARY: string = '#a6adc8'
  static readonly TEXT_MUTED: string = '#6c7086'
  static readonly TEXT_INVERSE: string = '#1e1e2e'

  // ══════════ Accent ══════════
  static readonly ACCENT: string = '#89b4fa'
  static readonly ACCENT_DIM: string = '#1e3a5f'
  static readonly ACCENT_TEXT: string = '#89b4fa'

  // ══════════ Semantic ══════════
  static readonly SUCCESS: string = '#a6e3a1'
  static readonly SUCCESS_DIM: string = '#1a3a1a'
  static readonly WARNING: string = '#f9e2af'
  static readonly WARNING_DIM: string = '#3a3520'
  static readonly DANGER: string = '#f38ba8'
  static readonly DANGER_DIM: string = '#3a1a25'
  static readonly INFO: string = '#89dceb'

  // ══════════ Code & Tool ══════════
  static readonly CODE_BG: string = '#11111b'
  static readonly CODE_BORDER: string = '#313244'
  static readonly TOOL_BG: string = '#181825'
  static readonly TOOL_BORDER: string = '#313244'
  static readonly DIFF_ADD_BG: string = '#1a3a1a'
  static readonly DIFF_ADD_TEXT: string = '#a6e3a1'
  static readonly DIFF_DEL_BG: string = '#3a1a25'
  static readonly DIFF_DEL_TEXT: string = '#f38ba8'

  // ══════════ Interactive ══════════
  static readonly HOVER: string = '#1e1e2e'
  static readonly ACTIVE_BG: string = '#313244'
  static readonly SELECTION: string = '#45475a'
  static readonly SCROLLBAR: string = '#45475a'

  // ══════════ Activity Bar ══════════
  static readonly ACTIVITY_BAR_BG: string = '#11111b'
  static readonly ACTIVITY_BAR_ACTIVE: string = '#89b4fa'
  static readonly ACTIVITY_BAR_INACTIVE: string = '#6c7086'

  // ══════════ Typography ══════════
  static readonly FONT_SANS: string = 'HarmonyOS Sans'
  static readonly FONT_MONO: string = 'HarmonyOS Sans Mono'

  // ══════════ Instances ══════════
  static readonly fs: FontSizes = new FontSizes()
  static readonly sp: Spacing = new Spacing()
  static readonly rd: Radius = new Radius()

  // ══════════ Layout Dims ══════════
  static readonly ACTIVITY_BAR_W: number = 48
  static readonly SIDEBAR_W: number = 240
  static readonly STATUS_BAR_H: number = 28
  static readonly RIGHT_PANEL_W: number = 300
  static readonly COMPOSER_MIN_H: number = 52
}
