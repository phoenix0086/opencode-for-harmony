/**
 * SlashCommandService — Sprint 1-A.10
 *
 * Resolves /-prefixed composer input to a structured action before it
 * reaches the agent. Built-in commands are implemented locally so the
 * user can navigate and inspect the IDE without consuming LLM tokens.
 *
 * Adding new commands:
 * 1. Add a new entry to BUILTIN_COMMANDS with a unique name + handler.
 * 2. The handler is invoked synchronously and returns a SlashResult.
 * 3. For commands that need to talk to the network, the Index layer
 *    dispatches an externalCommand string (see SlashCommand.externalCommand).
 */
export class SlashCommand {
  name: string = ''
  description: string = ''
  argumentHint: string = ''          // e.g. "<name>" shown in /help
  externalCommand: string = ''       // non-empty => Index will route to client
  clientOnly: boolean = false        // true => suppress if no active session
}

export class SlashResult {
  handled: boolean = false
  output: string = ''                // text to display in toast / log
  clearInput: boolean = true
  externalCommand: string = ''
  newMode: string = ''               // for /mode
  newModel: string = ''              // for /model
}

@Observed
export class SlashRegistry {
  private commands: Map<string, SlashCommand> = new Map()

  register(cmd: SlashCommand): void {
    this.commands.set(cmd.name, cmd)
  }

  list(): SlashCommand[] {
    return Array.from(this.commands.values())
  }

  match(name: string): SlashCommand | null {
    return this.commands.get(name) || null
  }
}

export const slashRegistry = new SlashRegistry()

// ─── Built-in commands ───

slashRegistry.register(makeSimpleCmd('help',
  '显示所有可用的 slash command',
  '',
  'help',
  '展示所有可用的 / 命令，参数：/help [name] 显示详情'))

slashRegistry.register(makeSimpleCmd('clear',
  '清空当前 composer 输入',
  '',
  'clear',
  '清空当前 composer 输入'))

slashRegistry.register(makeSimpleCmd('new',
  '创建新 session 并切换',
  '[<title>]',
  'new',
  '创建新 session'))

slashRegistry.register(makeSimpleCmd('model',
  '查看或切换默认模型（/model 或 /model <provider/model>）',
  '[<provider/model>]',
  'model',
  '查看或切换当前 model'))

slashRegistry.register(makeSimpleCmd('mode',
  '切换 agent 模式（/mode build|plan）',
  '<build|plan>',
  'mode',
  '切换 build / plan 模式'))

slashRegistry.register(makeSimpleCmd('sessions',
  '列出最近 10 个 session',
  '',
  'sessions',
  '列出当前项目的 session'))

slashRegistry.register(makeSimpleCmd('rename',
  '重命名当前 session（/rename <新标题>）',
  '<title>',
  'rename',
  '重命名当前 session'))

slashRegistry.register(makeSimpleCmd('fork',
  '从当前 session 复制出一个新 session',
  '',
  'fork',
  '复制当前 session'))

slashRegistry.register(makeSimpleCmd('compact',
  '请求 Runtime 压缩当前 session 的上下文',
  '',
  'compact',
  '压缩上下文（需 Runtime 支持 v2 /compaction 端点）'))

slashRegistry.register(makeSimpleCmd('tokens',
  '显示当前 session 的 token 用量',
  '',
  'tokens',
  '显示 token 使用量'))

slashRegistry.register(makeSimpleCmd('abort',
  '中断当前正在运行的 agent',
  '',
  'abort',
  '中断正在运行的 agent'))

slashRegistry.register(makeSimpleCmd('theme',
  '切换主题（/theme catppuccin|...）',
  '<name>',
  'theme',
  '切换主题'))

function makeSimpleCmd(
  name: string,
  description: string,
  argumentHint: string,
  externalCommand: string,
  helpText: string
): SlashCommand {
  const cmd = new SlashCommand()
  cmd.name = name
  cmd.description = description
  cmd.argumentHint = argumentHint
  cmd.externalCommand = externalCommand
  return cmd
}

/**
 * Parse a user input string. Returns null if the input is not a slash command.
 *
 * Recognized shapes:
 *   "/help"            → command="help", args=""
 *   "/new Fix auth"    → command="new", args="Fix auth"
 *   "/model x/abc"     → command="model", args="x/abc"
 */
export function parseSlashCommand(input: string): { command: SlashCommand, args: string } | null {
  const trimmed = input.trim()
  if (trimmed.length === 0 || trimmed.charAt(0) !== '/') {
    return null
  }

  // Split into command name + rest. Use first whitespace as separator.
  let space = -1
  for (let i = 0; i < trimmed.length; i++) {
    if (trimmed.charAt(i) === ' ' || trimmed.charAt(i) === '\t' || trimmed.charAt(i) === '\n') {
      space = i
      break
    }
  }
  const name = space > 0 ? trimmed.substring(1, space) : trimmed.substring(1)
  const rest = space > 0 ? trimmed.substring(space + 1).trim() : ''

  if (name.length === 0) {
    return null
  }

  const cmd = slashRegistry.match(name)
  if (!cmd) {
    return null
  }
  return { command: cmd, args: rest }
}

/**
 * Build a /help response string.
 */
export function buildHelpText(filter: string): string {
  const list = slashRegistry.list()
  if (filter.length > 0) {
    const m = slashRegistry.match(filter)
    if (!m) {
      return `未知命令：/${filter}`
    }
    let out = `/${m.name} ${m.argumentHint}\n${m.description}`
    if (m.externalCommand.length > 0) {
      out += `\n(handler: ${m.externalCommand})`
    }
    return out
  }
  let out = '可用命令：\n'
  for (const c of list) {
    const arg = c.argumentHint.length > 0 ? ' ' + c.argumentHint : ''
    out += `  /${c.name}${arg}  — ${c.description}\n`
  }
  return out
}
