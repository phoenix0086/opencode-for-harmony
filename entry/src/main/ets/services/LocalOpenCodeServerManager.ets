import { Runner, RunnerConfig, createRunner, runnerBaseUrl } from '../models/Runner'
import { storageService } from './StorageService'
import { OpenCodeClient } from './OpenCodeClient'
import { ProcessBridge } from './ProcessBridge'

export class LocalServerStatus {
  status: string = 'unknown' // unknown | running | not_running | error | manual_required | starting | stopped
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
  managedPid: number = -1

  createDefaultConfig(): LocalServerConfig {
    return new LocalServerConfig()
  }

  async loadLastConfig(): Promise<LocalServerConfig> {
    const cfg = new LocalServerConfig()
    const raw = await storageService.getLocalServerConfig()
    if (raw === null) return cfg
    if (typeof raw['host'] === 'string' && (raw['host'] as string).length > 0) {
      cfg.host = raw['host'] as string
    }
    if (typeof raw['port'] === 'number' && (raw['port'] as number) > 0) {
      cfg.port = raw['port'] as number
    }
    if (typeof raw['protocol'] === 'string' && (raw['protocol'] as string).length > 0) {
      cfg.protocol = raw['protocol'] as 'http' | 'https'
    }
    if (typeof raw['token'] === 'string') {
      cfg.token = raw['token'] as string
    }
    if (typeof raw['mode'] === 'string' && (raw['mode'] as string).length > 0) {
      cfg.mode = raw['mode'] as string
    }
    return cfg
  }

  async saveLastConfig(config: LocalServerConfig): Promise<void> {
    const out: Record<string, Object> = {}
    out['host'] = config.host
    out['port'] = config.port
    out['protocol'] = config.protocol
    out['token'] = config.token
    out['mode'] = config.mode
    await storageService.setLocalServerConfig(out)
  }

  createRunnerFromConfig(config: LocalServerConfig): Runner {
    const rc = new RunnerConfig()
    rc.name = config.mode === 'remote' ? 'Remote OpenCode Runtime' : 'Local OpenCode Runtime'
    rc.host = config.host
    rc.port = config.port
    rc.protocol = config.protocol
    rc.token = config.token
    return createRunner(rc)
  }

  getCommandForConfig(config: LocalServerConfig): string {
    if (config.mode === 'remote') {
      return `connect ${config.protocol}://${config.host}:${config.port}`
    }
    const hostname = config.mode === 'local' ? config.host : '0.0.0.0'
    return `opencode serve --port ${config.port} --hostname ${hostname}`
  }

  createPreviewStatus(config: LocalServerConfig): LocalServerStatus {
    const status = new LocalServerStatus()
    status.host = config.host
    status.port = config.port
    status.protocol = config.protocol
    status.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    status.startCommand = this.getCommandForConfig(config)
    return status
  }

  async checkHealth(config: LocalServerConfig): Promise<LocalServerStatus> {
    const status = this.createPreviewStatus(config)
    const runner = this.createRunnerFromConfig(config)
    status.baseUrl = runnerBaseUrl(runner)

    try {
      const client = new OpenCodeClient(runner)
      const health = await client.health()
      if (health.ok) {
        status.status = 'running'
        status.version = health.version
        status.message = `本地 OpenCode Runtime 运行中：${status.baseUrl}`
        status.logs.push(`[ok] /global/health healthy=true version=${health.version}`)
      } else {
        status.status = 'not_running'
        status.message = `本地 OpenCode Runtime 未启动或不可达：${health.error}`
        status.logs.push(`[fail] /global/health ${health.error}`)
      }
    } catch (e) {
      status.status = 'error'
      status.message = `Runtime 检测失败：${String(e)}`
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

    if (!replaced) next.push(runner)

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
    const status = this.createPreviewStatus(config)
    if (config.mode === 'remote') {
      status.status = 'manual_required'
      status.message = '远程模式不启动本地进程，只检测并连接远程 Runtime。'
      status.logs.push(`[remote] ${status.baseUrl}`)
      return status
    }

    status.status = 'manual_required'
    status.message = '可以点击“启动本地 Runtime”自动启动；如果失败，再复制命令到终端排查。'
    status.logs.push(`[cmd] ${status.startCommand}`)
    return status
  }

  startServerProcess(config: LocalServerConfig): LocalServerStatus {
    const status = this.createPreviewStatus(config)

    if (config.mode === 'remote') {
      status.status = 'error'
      status.message = '远程模式不能启动本地 Runtime，请使用“检测”或“保存并连接”。'
      status.logs.push('[error] remote mode cannot start local process')
      return status
    }

    const command = this.findOpencodeBinary()
    if (command.length === 0) {
      status.status = 'error'
      status.message = '找不到 opencode 可执行文件。请确认已安装 opencode，或后续使用随包内置 Runtime。'
      status.logs.push('[error] opencode binary not found')
      return status
    }

    const hostname = config.mode === 'local' ? config.host : '0.0.0.0'
    const args = ['serve', '--port', `${config.port}`, '--hostname', hostname]
    const pid = ProcessBridge.startProcess(command, args)

    if (pid <= 0) {
      status.status = 'error'
      status.message = 'Runtime 进程启动失败。可能是权限不足、opencode 未安装，或 Native Bridge 不可用。'
      status.logs.push(`[error] startProcess returned pid=${pid}`)
      return status
    }

    status.processPid = pid
    status.status = 'starting'
    status.message = `本地 OpenCode Runtime 启动中 (pid=${pid})...`
    status.logs.push(`[ok] process started pid=${pid}`)
    status.logs.push(`[cmd] ${command} ${args.join(' ')}`)
    return status
  }

  stopServerProcess(pid: number): LocalServerStatus {
    const status = new LocalServerStatus()
    status.processPid = pid

    if (pid <= 0) {
      status.status = 'stopped'
      status.message = '没有正在管理的 Runtime 进程。'
      status.logs.push('[info] no managed pid')
      return status
    }

    const ok = ProcessBridge.stopProcess(pid)
    status.status = ok ? 'stopped' : 'error'
    status.message = ok ? `Runtime 已停止 (pid=${pid})` : `Runtime 停止失败 (pid=${pid})`
    status.logs.push(ok ? `[ok] stopped pid=${pid}` : `[error] stop failed pid=${pid}`)
    return status
  }

  isProcessRunning(pid: number): boolean {
    if (pid <= 0) return false
    return ProcessBridge.isRunning(pid)
  }

  collectProcessLogs(pid: number): string[] {
    if (pid <= 0) return []
    try {
      return ProcessBridge.drainLogs(pid)
    } catch (e) {
      return [`[error] drainLogs failed: ${String(e)}`]
    }
  }

  /**
   * Auto-start: the core method for built-in server.
   * 1. Load saved config (or use default)
   * 2. Check health → if already running, activate and return
   * 3. Start process via native bridge
   * 4. Poll health until server is ready
   * 5. Save and activate the runner
   * Returns status with logs for UI display.
   */
  async autoStart(onStatusChange?: (status: LocalServerStatus) => void): Promise<LocalServerStatus> {
    const config = await this.loadLastConfig()

    // Step 1: check if already running
    let healthStatus = await this.checkHealth(config)
    if (healthStatus.status === 'running') {
      await this.saveAndActivate(config)
      healthStatus.logs.push('[auto] server already running, activated')
      if (onStatusChange) onStatusChange(healthStatus)
      return healthStatus
    }

    // Step 2: start the process
    const startStatus = this.startServerProcess(config)
    if (onStatusChange) onStatusChange(startStatus)

    if (startStatus.status === 'error') {
      return startStatus
    }

    this.managedPid = startStatus.processPid

    // Step 3: poll health up to 30 times (30 seconds max)
    const maxPolls = 30
    const pollIntervalMs = 1000
    for (let i = 0; i < maxPolls; i++) {
      await this.delay(pollIntervalMs)

      // Check if process is still alive
      if (!this.isProcessRunning(this.managedPid)) {
        const logs = this.collectProcessLogs(this.managedPid)
        const failStatus = new LocalServerStatus()
        failStatus.status = 'error'
        failStatus.processPid = this.managedPid
        failStatus.message = 'Runtime 进程已退出，启动失败。'
        failStatus.logs = startStatus.logs.concat(logs)
        failStatus.logs.push(`[auto] process exited during startup poll #${i + 1}`)
        this.managedPid = -1
        if (onStatusChange) onStatusChange(failStatus)
        return failStatus
      }

      // Check health endpoint
      healthStatus = await this.checkHealth(config)
      if (healthStatus.status === 'running') {
        await this.saveAndActivate(config)
        healthStatus.processPid = this.managedPid
        healthStatus.logs = startStatus.logs.concat(healthStatus.logs)
        healthStatus.logs.push(`[auto] server healthy after ${(i + 1)}s, activated`)
        if (onStatusChange) onStatusChange(healthStatus)
        return healthStatus
      }

      // Report progress
      const progressStatus = new LocalServerStatus()
      progressStatus.status = 'starting'
      progressStatus.processPid = this.managedPid
      progressStatus.host = config.host
      progressStatus.port = config.port
      progressStatus.baseUrl = `${config.protocol}://${config.host}:${config.port}`
      progressStatus.message = `Runtime 启动中... 等待就绪 (${i + 1}/${maxPolls}s)`
      progressStatus.logs = startStatus.logs
      progressStatus.logs.push(`[auto] health poll #${i + 1}: not ready yet`)
      if (onStatusChange) onStatusChange(progressStatus)
    }

    // Step 4: timed out
    const timeoutStatus = new LocalServerStatus()
    timeoutStatus.status = 'error'
    timeoutStatus.processPid = this.managedPid
    timeoutStatus.host = config.host
    timeoutStatus.port = config.port
    timeoutStatus.message = `Runtime 启动超时 (${maxPolls}s)。进程可能卡住，请检查日志。`
    timeoutStatus.logs = startStatus.logs
    timeoutStatus.logs.push(`[auto] health check timed out after ${maxPolls}s`)
    // Collect any available logs
    const finalLogs = this.collectProcessLogs(this.managedPid)
    timeoutStatus.logs = timeoutStatus.logs.concat(finalLogs)
    if (onStatusChange) onStatusChange(timeoutStatus)
    return timeoutStatus
  }

  /**
   * Gracefully shut down the managed server process.
   * Should be called when the app is closing.
   */
  shutdown(): LocalServerStatus {
    if (this.managedPid <= 0) {
      const s = new LocalServerStatus()
      s.status = 'stopped'
      s.message = '没有正在管理的 Runtime 进程。'
      return s
    }
    const result = this.stopServerProcess(this.managedPid)
    this.managedPid = -1
    return result
  }

  /**
   * Stop all managed processes (safety net).
   */
  shutdownAll(): void {
    ProcessBridge.stopAll()
    this.managedPid = -1
  }

  private async delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms)
    })
  }

  private findOpencodeBinary(): string {
    // Priority: bundled binary > common install paths > PATH fallback
    // V3: bundled binary would be at context.filesDir/opencode
    // V2: relies on PATH for now
    return 'opencode'
  }
}

export const localOpenCodeServerManager = new LocalOpenCodeServerManager()
