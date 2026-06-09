/**
 * I18nService — Sprint 4-C.25
 *
 * Simple i18n service with zh-CN / en-US dictionaries.
 * Keys use dot.notation: 'agent.title', 'composer.send', etc.
 *
 * 用法:
 *   I18n.setLocale('zh-CN')
 *   Text(I18n.t('agent.title'))
 *
 * Locale 自动从 AppStorage 读取 'appLocale',变化时自动重新计算。
 */

export type Locale = 'zh-CN' | 'en-US'

@Observed
export class I18nStrings {
  // ═══════ Agent / Composer ═══════
  'agent.title': string = 'Agent'
  'agent.build': string = 'build'
  'agent.plan': string = 'plan'
  'composer.send': string = 'send'
  'composer.placeholder': string = 'Ask the agent anything... (or type / for commands)'

  // ═══════ Sidebar / Activity ═══════
  'sidebar.chat': string = 'Chat'
  'sidebar.diff': string = 'Diff'
  'sidebar.files': string = 'Files'
  'sidebar.logs': string = 'Logs'
  'sidebar.runtime': string = 'Runtime'
  'sidebar.history': string = 'History'
  'sidebar.terminal': string = 'Terminal'
  'sidebar.mcp': string = 'MCP'
  'sidebar.lsp': string = 'LSP'
  'sidebar.formatters': string = 'Formatters'
  'sidebar.plugins': string = 'Plugins'
  'sidebar.settings': string = 'Settings'

  // ═══════ Status ═══════
  'status.connected': string = 'connected'
  'status.disconnected': string = 'disconnected'
  'status.connecting': string = 'connecting'
  'status.error': string = 'error'
  'status.unsupported': string = 'unsupported'

  // ═══════ Errors ═══════
  'error.network': string = 'network error'
  'error.server': string = 'server error'
  'error.timeout': string = 'timeout'
  'error.not_implemented': string = 'not implemented'

  // ═══════ Toast / Log ═══════
  'toast.copied': string = 'copied'
  'toast.compacted': string = 'session compacted'
  'toast.aborted': string = 'aborted'
  'toast.snapshot_created': string = 'snapshot created'
  'toast.snapshot_restored': string = 'snapshot restored'
  'toast.pty_started': string = 'pty started'
  'toast.pty_closed': string = 'pty closed'

  // ═══════ Slash Commands ═══════
  'slash.help': string = 'show help'
  'slash.clear': string = 'clear input'
  'slash.new': string = 'new session'
  'slash.model': string = 'switch model'
  'slash.mode': string = 'switch agent mode'
  'slash.sessions': string = 'list sessions'
  'slash.rename': string = 'rename session'
  'slash.fork': string = 'fork session'
  'slash.compact': string = 'compact context'
  'slash.tokens': string = 'show token usage'
  'slash.abort': string = 'abort current run'
  'slash.theme': string = 'switch theme'
}

export class I18nService {
  private currentLocale: Locale = 'zh-CN'
  private listeners: Array<(locale: Locale) => void> = []
  private strings: Map<string, I18nStrings> = new Map()

  constructor() {
    this.loadBundles()
  }

  private loadBundles(): void {
    const zh = new I18nStrings()
    zh['agent.title'] = '代理'
    zh['agent.build'] = '构建'
    zh['agent.plan'] = '规划'
    zh['composer.send'] = '发送'
    zh['composer.placeholder'] = '向代理提问... (输入 / 查看命令)'
    zh['sidebar.chat'] = '对话'
    zh['sidebar.diff'] = '差异'
    zh['sidebar.files'] = '文件'
    zh['sidebar.logs'] = '日志'
    zh['sidebar.runtime'] = '运行时'
    zh['sidebar.history'] = '历史'
    zh['sidebar.terminal'] = '终端'
    zh['sidebar.mcp'] = 'MCP'
    zh['sidebar.lsp'] = 'LSP'
    zh['sidebar.formatters'] = '格式化'
    zh['sidebar.plugins'] = '插件'
    zh['sidebar.settings'] = '设置'
    zh['status.connected'] = '已连接'
    zh['status.disconnected'] = '未连接'
    zh['status.connecting'] = '连接中'
    zh['status.error'] = '错误'
    zh['status.unsupported'] = '不支持'
    zh['error.network'] = '网络错误'
    zh['error.server'] = '服务器错误'
    zh['error.timeout'] = '超时'
    zh['error.not_implemented'] = '未实现'
    zh['toast.copied'] = '已复制'
    zh['toast.compacted'] = '会话已压缩'
    zh['toast.aborted'] = '已中止'
    zh['toast.snapshot_created'] = '快照已创建'
    zh['toast.snapshot_restored'] = '快照已恢复'
    zh['toast.pty_started'] = '终端已启动'
    zh['toast.pty_closed'] = '终端已关闭'
    zh['slash.help'] = '显示帮助'
    zh['slash.clear'] = '清空输入'
    zh['slash.new'] = '新会话'
    zh['slash.model'] = '切换模型'
    zh['slash.mode'] = '切换代理模式'
    zh['slash.sessions'] = '列出会话'
    zh['slash.rename'] = '重命名会话'
    zh['slash.fork'] = '分叉会话'
    zh['slash.compact'] = '压缩上下文'
    zh['slash.tokens'] = '显示 token 用量'
    zh['slash.abort'] = '中止当前运行'
    zh['slash.theme'] = '切换主题'
    this.strings.set('zh-CN', zh)

    const en = new I18nStrings()
    this.strings.set('en-US', en)
  }

  setLocale(locale: Locale): void {
    if (this.currentLocale === locale) return
    this.currentLocale = locale
    for (const fn of this.listeners) {
      fn(locale)
    }
  }

  getLocale(): Locale {
    return this.currentLocale
  }

  subscribe(fn: (locale: Locale) => void): void {
    this.listeners.push(fn)
  }

  /**
   * Translate a key. Falls back to the key itself if not found
   * (or to en-US bundle if current locale has no entry).
   */
  t(key: string): string {
    const bundle = this.strings.get(this.currentLocale)
    if (bundle !== undefined) {
      const v = bundle[key]
      if (v !== undefined && v.length > 0) {
        return v
      }
    }
    const fallback = this.strings.get('en-US')
    if (fallback !== undefined) {
      const v = fallback[key]
      if (v !== undefined && v.length > 0) {
        return v
      }
    }
    return key
  }
}

export const i18n: I18nService = new I18nService()
