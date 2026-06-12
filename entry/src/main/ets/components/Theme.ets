/**
 * OpenCode Harmony Native - Multi-Theme Design Token System
 * IDE/Developer Tool visual language for ArkUI
 *
 * Supports: Catppuccin Mocha (default), Tokyo Night, Gruvbox Dark
 */

export class FontSizes {
  xs: number = 14
  sm: number = 16
  md: number = 18
  lg: number = 20
  xl: number = 24
  code: number = 16
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

// ══════════════════════════════════════════════════════════════
//  Theme Palette — all color tokens that change between themes
// ══════════════════════════════════════════════════════════════

export class ThemePalette {
  // Core Backgrounds
  BG: string = ''
  BG_ALT: string = ''
  PANEL: string = ''
  SIDEBAR: string = ''
  STATUSBAR: string = ''
  COMPOSER: string = ''
  COMPOSER_BORDER: string = ''
  INPUT_BG: string = ''
  // Borders
  BORDER: string = ''
  BORDER_LIGHT: string = ''
  BORDER_FOCUS: string = ''
  // Text
  TEXT_PRIMARY: string = ''
  TEXT_SECONDARY: string = ''
  TEXT_MUTED: string = ''
  TEXT_INVERSE: string = ''
  // Accent
  ACCENT: string = ''
  ACCENT_DIM: string = ''
  ACCENT_TEXT: string = ''
  // Semantic
  SUCCESS: string = ''
  SUCCESS_DIM: string = ''
  WARNING: string = ''
  WARNING_DIM: string = ''
  DANGER: string = ''
  DANGER_DIM: string = ''
  INFO: string = ''
  // Code & Tool
  CODE_BG: string = ''
  CODE_BORDER: string = ''
  TOOL_BG: string = ''
  TOOL_BORDER: string = ''
  DIFF_ADD_BG: string = ''
  DIFF_ADD_TEXT: string = ''
  DIFF_DEL_BG: string = ''
  DIFF_DEL_TEXT: string = ''
  // Panel & Button aliases (newer components use these)
  PANEL_BG: string = ''
  HEADER_BG: string = ''
  BTN_BG: string = ''
  // Interactive
  HOVER: string = ''
  ACTIVE_BG: string = ''
  SELECTION: string = ''
  SCROLLBAR: string = ''
  // Activity Bar
  ACTIVITY_BAR_BG: string = ''
  ACTIVITY_BAR_ACTIVE: string = ''
  ACTIVITY_BAR_INACTIVE: string = ''
}

// ══════════════════════════════════════════════════════════════
//  Theme Instances
// ══════════════════════════════════════════════════════════════

const CatppuccinMocha: ThemePalette = (() => {
  const p = new ThemePalette()
  // Core Backgrounds
  p.BG = '#1e1e2e'
  p.BG_ALT = '#181825'
  p.PANEL = '#11111b'
  p.SIDEBAR = '#181825'
  p.STATUSBAR = '#11111b'
  p.COMPOSER = '#1e1e2e'
  p.COMPOSER_BORDER = '#45475a'
  p.INPUT_BG = '#11111b'
  // Borders
  p.BORDER = '#313244'
  p.BORDER_LIGHT = '#45475a'
  p.BORDER_FOCUS = '#89b4fa'
  // Text
  p.TEXT_PRIMARY = '#cdd6f4'
  p.TEXT_SECONDARY = '#a6adc8'
  p.TEXT_MUTED = '#6c7086'
  p.TEXT_INVERSE = '#1e1e2e'
  // Accent
  p.ACCENT = '#89b4fa'
  p.ACCENT_DIM = '#1e3a5f'
  p.ACCENT_TEXT = '#1e1e2e'
  // Semantic
  p.SUCCESS = '#a6e3a1'
  p.SUCCESS_DIM = '#1a3a1a'
  p.WARNING = '#f9e2af'
  p.WARNING_DIM = '#3a3520'
  p.DANGER = '#f38ba8'
  p.DANGER_DIM = '#3a1a25'
  p.INFO = '#89dceb'
  // Code & Tool
  p.CODE_BG = '#11111b'
  p.CODE_BORDER = '#313244'
  p.TOOL_BG = '#181825'
  p.TOOL_BORDER = '#313244'
  p.DIFF_ADD_BG = '#1e3a2a'
  p.DIFF_ADD_TEXT = '#a6e3a1'
  p.DIFF_DEL_BG = '#3a1e1e'
  p.DIFF_DEL_TEXT = '#f38ba8'
  // Panel & button aliases
  p.PANEL_BG = p.PANEL
  p.HEADER_BG = p.STATUSBAR
  p.ACTIVE_BG = '#313244'
  p.BTN_BG = p.ACTIVE_BG
  // Interactive
  p.HOVER = '#1e1e2e'
  p.SELECTION = '#45475a'
  p.SCROLLBAR = '#45475a'
  // Activity Bar
  p.ACTIVITY_BAR_BG = '#11111b'
  p.ACTIVITY_BAR_ACTIVE = '#89b4fa'
  p.ACTIVITY_BAR_INACTIVE = '#6c7086'
  return p
})()

const TokyoNight: ThemePalette = (() => {
  const p = new ThemePalette()
  // Core Backgrounds
  p.BG = '#1a1b26'
  p.BG_ALT = '#16161e'
  p.PANEL = '#13131a'
  p.SIDEBAR = '#16161e'
  p.STATUSBAR = '#13131a'
  p.COMPOSER = '#1a1b26'
  p.COMPOSER_BORDER = '#3b4261'
  p.INPUT_BG = '#13131a'
  // Borders
  p.BORDER = '#292e42'
  p.BORDER_LIGHT = '#3b4261'
  p.BORDER_FOCUS = '#7aa2f7'
  // Text
  p.TEXT_PRIMARY = '#c0caf5'
  p.TEXT_SECONDARY = '#9aa5ce'
  p.TEXT_MUTED = '#565f89'
  p.TEXT_INVERSE = '#1a1b26'
  // Accent
  p.ACCENT = '#7aa2f7'
  p.ACCENT_DIM = '#1a2744'
  p.ACCENT_TEXT = '#1a1b26'
  // Semantic
  p.SUCCESS = '#9ece6a'
  p.SUCCESS_DIM = '#1a2e1a'
  p.WARNING = '#e0af68'
  p.WARNING_DIM = '#2e2a1a'
  p.DANGER = '#f7768e'
  p.DANGER_DIM = '#2e1a22'
  p.INFO = '#7dcfff'
  // Code & Tool
  p.CODE_BG = '#13131a'
  p.CODE_BORDER = '#292e42'
  p.TOOL_BG = '#16161e'
  p.TOOL_BORDER = '#292e42'
  p.DIFF_ADD_BG = '#1a2e1a'
  p.DIFF_ADD_TEXT = '#9ece6a'
  p.DIFF_DEL_BG = '#2e1a22'
  p.DIFF_DEL_TEXT = '#f7768e'
  // Panel & button aliases
  p.PANEL_BG = p.PANEL
  p.HEADER_BG = p.STATUSBAR
  p.ACTIVE_BG = '#292e42'
  p.BTN_BG = p.ACTIVE_BG
  // Interactive
  p.HOVER = '#1a1b26'
  p.SELECTION = '#3b4261'
  p.SCROLLBAR = '#3b4261'
  // Activity Bar
  p.ACTIVITY_BAR_BG = '#13131a'
  p.ACTIVITY_BAR_ACTIVE = '#7aa2f7'
  p.ACTIVITY_BAR_INACTIVE = '#565f89'
  return p
})()

const GruvboxDark: ThemePalette = (() => {
  const p = new ThemePalette()
  // Core Backgrounds
  p.BG = '#282828'
  p.BG_ALT = '#1d2021'
  p.PANEL = '#1d2021'
  p.SIDEBAR = '#1d2021'
  p.STATUSBAR = '#1d2021'
  p.COMPOSER = '#282828'
  p.COMPOSER_BORDER = '#504945'
  p.INPUT_BG = '#1d2021'
  // Borders
  p.BORDER = '#3c3836'
  p.BORDER_LIGHT = '#504945'
  p.BORDER_FOCUS = '#83a598'
  // Text
  p.TEXT_PRIMARY = '#ebdbb2'
  p.TEXT_SECONDARY = '#d5c4a1'
  p.TEXT_MUTED = '#928374'
  p.TEXT_INVERSE = '#282828'
  // Accent
  p.ACCENT = '#83a598'
  p.ACCENT_DIM = '#1e302e'
  p.ACCENT_TEXT = '#282828'
  // Semantic
  p.SUCCESS = '#b8bb26'
  p.SUCCESS_DIM = '#2a2e1a'
  p.WARNING = '#fabd2f'
  p.WARNING_DIM = '#2e2a1a'
  p.DANGER = '#fb4934'
  p.DANGER_DIM = '#2e1a1a'
  p.INFO = '#83a598'
  // Code & Tool
  p.CODE_BG = '#1d2021'
  p.CODE_BORDER = '#3c3836'
  p.TOOL_BG = '#1d2021'
  p.TOOL_BORDER = '#3c3836'
  p.DIFF_ADD_BG = '#2a2e1a'
  p.DIFF_ADD_TEXT = '#b8bb26'
  p.DIFF_DEL_BG = '#2e1a1a'
  p.DIFF_DEL_TEXT = '#fb4934'
  // Panel & button aliases
  p.PANEL_BG = p.PANEL
  p.HEADER_BG = p.STATUSBAR
  p.ACTIVE_BG = '#3c3836'
  p.BTN_BG = p.ACTIVE_BG
  // Interactive
  p.HOVER = '#282828'
  p.SELECTION = '#504945'
  p.SCROLLBAR = '#504945'
  // Activity Bar
  p.ACTIVITY_BAR_BG = '#1d2021'
  p.ACTIVITY_BAR_ACTIVE = '#83a598'
  p.ACTIVITY_BAR_INACTIVE = '#928374'
  return p
})()

// ══════════════════════════════════════════════════════════════
//  Theme — static access layer (backward compatible)
// ══════════════════════════════════════════════════════════════

export class Theme {
  // Mutable palette reference — swapped by switchTheme()
  private static _current: ThemePalette = CatppuccinMocha

  // ══════════ Color token getters (delegate to _current) ══════════

  // Core Backgrounds
  static get BG(): string { return Theme._current.BG }
  static get BG_ALT(): string { return Theme._current.BG_ALT }
  static get PANEL(): string { return Theme._current.PANEL }
  static get SIDEBAR(): string { return Theme._current.SIDEBAR }
  static get STATUSBAR(): string { return Theme._current.STATUSBAR }
  static get COMPOSER(): string { return Theme._current.COMPOSER }
  static get COMPOSER_BORDER(): string { return Theme._current.COMPOSER_BORDER }
  static get INPUT_BG(): string { return Theme._current.INPUT_BG }

  // Borders
  static get BORDER(): string { return Theme._current.BORDER }
  static get BORDER_LIGHT(): string { return Theme._current.BORDER_LIGHT }
  static get BORDER_FOCUS(): string { return Theme._current.BORDER_FOCUS }

  // Text
  static get TEXT_PRIMARY(): string { return Theme._current.TEXT_PRIMARY }
  static get TEXT_SECONDARY(): string { return Theme._current.TEXT_SECONDARY }
  static get TEXT_MUTED(): string { return Theme._current.TEXT_MUTED }
  static get TEXT_INVERSE(): string { return Theme._current.TEXT_INVERSE }

  // Accent
  static get ACCENT(): string { return Theme._current.ACCENT }
  static get ACCENT_DIM(): string { return Theme._current.ACCENT_DIM }
  static get ACCENT_TEXT(): string { return Theme._current.ACCENT_TEXT }

  // Semantic
  static get SUCCESS(): string { return Theme._current.SUCCESS }
  static get SUCCESS_DIM(): string { return Theme._current.SUCCESS_DIM }
  static get WARNING(): string { return Theme._current.WARNING }
  static get WARNING_DIM(): string { return Theme._current.WARNING_DIM }
  static get DANGER(): string { return Theme._current.DANGER }
  static get DANGER_DIM(): string { return Theme._current.DANGER_DIM }
  static get INFO(): string { return Theme._current.INFO }

  // Code & Tool
  static get CODE_BG(): string { return Theme._current.CODE_BG }
  static get CODE_BORDER(): string { return Theme._current.CODE_BORDER }
  static get TOOL_BG(): string { return Theme._current.TOOL_BG }
  static get TOOL_BORDER(): string { return Theme._current.TOOL_BORDER }
  static get DIFF_ADD_BG(): string { return Theme._current.DIFF_ADD_BG }
  static get DIFF_ADD_TEXT(): string { return Theme._current.DIFF_ADD_TEXT }
  static get DIFF_DEL_BG(): string { return Theme._current.DIFF_DEL_BG }
  static get DIFF_DEL_TEXT(): string { return Theme._current.DIFF_DEL_TEXT }
  static get PANEL_BG(): string { return Theme._current.PANEL_BG }
  static get HEADER_BG(): string { return Theme._current.HEADER_BG }
  static get BTN_BG(): string { return Theme._current.BTN_BG }

  // Interactive
  static get HOVER(): string { return Theme._current.HOVER }
  static get ACTIVE_BG(): string { return Theme._current.ACTIVE_BG }
  static get SELECTION(): string { return Theme._current.SELECTION }
  static get SCROLLBAR(): string { return Theme._current.SCROLLBAR }

  // Activity Bar
  static get ACTIVITY_BAR_BG(): string { return Theme._current.ACTIVITY_BAR_BG }
  static get ACTIVITY_BAR_ACTIVE(): string { return Theme._current.ACTIVITY_BAR_ACTIVE }
  static get ACTIVITY_BAR_INACTIVE(): string { return Theme._current.ACTIVITY_BAR_INACTIVE }

  // ══════════ Non-color constants (unchanged across themes) ══════════

  // Typography
  static readonly FONT_SANS: string = 'HarmonyOS Sans'
  static readonly FONT_MONO: string = 'HarmonyOS Sans Mono'

  // Instances
  static readonly fs: FontSizes = new FontSizes()
  static readonly sp: Spacing = new Spacing()
  static readonly rd: Radius = new Radius()

  // Layout Dims
  static readonly ACTIVITY_BAR_W: number = 48
  static readonly SIDEBAR_W: number = 240
  static readonly STATUS_BAR_H: number = 28
  static readonly RIGHT_PANEL_W: number = 300
  static readonly COMPOSER_MIN_H: number = 52

  // ══════════ Theme management ══════════

  static switchTheme(name: string): void {
    if (name === 'tokyonight') {
      Theme._current = TokyoNight
    } else if (name === 'gruvbox') {
      Theme._current = GruvboxDark
    } else {
      Theme._current = CatppuccinMocha
    }
    AppStorage.setOrCreate('themeId', name)
  }

  static currentTheme(): string {
    if (Theme._current === TokyoNight) return 'tokyonight'
    if (Theme._current === GruvboxDark) return 'gruvbox'
    return 'catppuccin'
  }

  static themeNames(): string[] {
    return ['catppuccin', 'tokyonight', 'gruvbox']
  }
}
