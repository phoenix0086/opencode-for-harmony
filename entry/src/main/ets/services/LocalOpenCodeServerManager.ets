import { Runner, RunnerConfig, createRunner, runnerBaseUrl } from '../models/Runner'
import { storageService } from './StorageService'
import { OpenCodeClient } from './OpenCodeClient'
import { ProcessBridge } from './ProcessBridge'

export class LocalServerStatus {
  status: string = 'unknown' // unknown | running | not_running | error | manual_required | starting
  message: string = ''
  baseUrl: string = 'http://127.0.0.1:4096'
  version: string = ''
  host: string = '127.0.0.1'
  port: number = 4096
  protocol: 'http' | 'https' = 'http'
  startCommand: string = 'opencode serve --port 4096 --hostname 127.0.0.1'
  logs: string[] = []
  processPid: number = -1
}

export class LocalServerConfig {
  host: string = '127.0.0.1'
  port: number = 4096
  protocol: 'http' | 'https' = 'http'
  token: string = ''
  mode: string = 'local' // local | dev-pc | remote
}

export class LocalOpenCodeServerManager {
  createDefaultConfig(): LocalServerConfig {
    return new LocalServerConfig()
  }

  createRunnerFromConfig(config: LocalServerConfig): Runner {
    const rc = new RunnerConfig()
    rc.name = config.mode === 'remote' ? 'Remote OpenCode Server' : 'Local OpenCode Server'
    rc.host = config.host
    rc.port = config.port
    rc.protocol = config.protocol
    rc.token = config.token
    return createRunner(rc)
  }

  getCommandForConfig(config: LocalServerConfig): string {
    if (config.mode === 'dev-pc' || config.mode === 'remote') {
      return `opencode serve --port ${config.port} --hostname 0.0.0.0`
    }
    return `opencode serve --port ${config.port} --hostname ${config.host}`
  }

  async checkHealth(config: LocalServerConfig): Promise<LocalServerStatus> {
    const status = new LocalServerStatus()
    status.host = config.host
    status.port = config.port
    status.protocol = config.protocol
    status.startCommand = this.getCommandForConfig(config)

    const runner = this.createRunnerFromConfig(config)
    status.baseUrl = runnerBaseUrl(runner)

    try {
      const client = new OpenCodeClient(runner)
      const health = await client.health()
      if (health.ok) {
        status.status = 'running'
        status.version = health.version
        status.message = `OpenCode Server is running: ${status.baseUrl}`
        status.logs.push(`[ok] /global/health healthy=true version=${health.version}`)
      } else {
        status.status = 'not_running'
        status.message = `OpenCode Server is not reachable: ${health.error}`
        status.logs.push(`[fail] /global/health ${health.error}`)
      }
    } catch (e) {
      status.status = 'error'
      status.message = `Health check failed: ${String(e)}`
      status.logs.push(`[error] ${String(e)}`)
    }

    return status
  }

  async saveAndActivate(config: LocalServerConfig): Promise<Runner> {
    const runner = this.createRunnerFromConfig(config)
    runner.status = 'connected'
    runner.lastConnectedAt = Date.now()
    runner.updatedAt = Date.now()

    const existing = await storageService.loadRunners()
    const next: Runner[] = []
    let replaced = false

    for (const item of existing) {
      if (item.host === runner.host && item.port === runner.port && item.protocol === runner.protocol) {
        next.push(runner)
        replaced = true
      } else {
        next.push(item)
      }
    }

    if (!replaced) {
      next.push(runner)
    }

    await storageService.saveRunners(next)
    await storageService.setActiveRunnerId(runner.id)
    await storageService.saveServerUrl(runnerBaseUrl(runner))

    return runner
  }

  async checkAndActivate(config: LocalServerConfig): Promise<LocalServerStatus> {
    const status = await this.checkHealth(config)
    if (status.status === 'running') {
      await this.saveAndActivate(config)
      status.logs.push('[ok] saved runner and set active runner')
    }
    return status
  }

  async prepareStart(config: LocalServerConfig): Promise<LocalServerStatus> {
    const status = new LocalServerStatus()
    status.host = config.host
    status.port = config.port
    status.protocol = config.protocol
    status.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    status.startCommand = this.getCommandForConfig(config)
    status.status = 'manual_required'
    status.message = '纯 ArkTS V1 不启动外部进程。请在终端运行命令，然后点击"检测并连接"。'
    status.logs.push(`[manual] ${status.startCommand}`)
    return status
  }

  // ══════════ V2: Native Bridge Process Management ══════════

  startServerProcess(config: LocalServerConfig, onLog: (line: string) => void): LocalServerStatus {
    const status = new LocalServerStatus()
    status.host = config.host
    status.port = config.port
    status.protocol = config.protocol
    status.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    status.startCommand = this.getCommandForConfig(config)

    const command = this.findOpencodeBinary()
    if (command.length === 0) {
      status.status = 'error'
      status.message = '找不到 opencode 可执行文件。请确认已安装 opencode 并在 PATH 中。'
      status.logs.push('[error] opencode binary not found')
      return status
    }

    const args = ['serve', '--port', `${config.port}`, '--hostname', config.host]

    ProcessBridge.setLogCallback((line: string) => {
      status.logs.push(line)
      onLog(line)
    })

    const pid = ProcessBridge.startProcess(command, args)
    if (pid <= 0) {
      status.status = 'error'
      status.message = '进程启动失败。可能是权限不足或 opencode 未安装。'
      status.logs.push(`[error] startProcess returned pid=${pid}`)
      return status
    }

    status.processPid = pid
    status.status = 'starting'
    status.message = `OpenCode Server 启动中 (pid=${pid})...`
    status.logs.push(`[ok] process started pid=${pid} cmd=${command} ${args.join(' ')}`)

    return status
  }

  stopServerProcess(pid: number): boolean {
    if (pid <= 0) return false
    return ProcessBridge.stopProcess(pid)
  }

  isProcessRunning(pid: number): boolean {
    if (pid <= 0) return false
    return ProcessBridge.isRunning(pid)
  }

  private findOpencodeBinary(): string {
    // Try common locations
    const candidates = [
      'opencode',
      '/usr/local/bin/opencode',
      '/usr/bin/opencode',
      '/opt/homebrew/bin/opencode'
    ]
    // In HarmonyOS sandbox, we rely on PATH or bundled binary
    // For now return 'opencode' and let execvp search PATH
    return 'opencode'
  }
}

export const localOpenCodeServerManager = new LocalOpenCodeServerManager()
