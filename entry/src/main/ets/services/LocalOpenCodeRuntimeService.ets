import { Runner, RunnerConfig, createRunner, runnerBaseUrl } from '../models/Runner'
import { storageService } from './StorageService'
import { OpenCodeClient } from './OpenCodeClient'
import { ILocalProcessBridge, manualProcessBridge, ProcessStartRequest } from './LocalProcessBridge'
import { errStr } from '../utils/ErrorUtil'

export class RuntimeConfig {
  mode: string = 'local' // local | dev-pc | remote
  host: string = '127.0.0.1'
  port: number = 4096
  protocol: 'http' | 'https' = 'http'
  token: string = ''
  workspace: string = ''
}

export class RuntimeState {
  status: string = 'unknown' // unknown | manual_required | starting | running | stopped | error
  baseUrl: string = 'http://127.0.0.1:4096'
  version: string = ''
  message: string = ''
  command: string = ''
  logs: string[] = []
}

export class LocalOpenCodeRuntimeService {
  private bridge: ILocalProcessBridge = manualProcessBridge

  setBridge(bridge: ILocalProcessBridge): void {
    this.bridge = bridge
  }

  defaultConfig(): RuntimeConfig {
    return new RuntimeConfig()
  }

  command(config: RuntimeConfig): string {
    if (config.mode === 'local') {
      return `opencode serve --port ${config.port} --hostname ${config.host}`
    }
    return `opencode serve --port ${config.port} --hostname 0.0.0.0`
  }

  createRunner(config: RuntimeConfig): Runner {
    const rc = new RunnerConfig()
    rc.name = config.mode === 'remote' ? 'Remote OpenCode Runtime' : 'Local OpenCode Runtime'
    rc.host = config.host
    rc.port = config.port
    rc.protocol = config.protocol
    rc.token = config.token
    return createRunner(rc)
  }

  async prepareStart(config: RuntimeConfig): Promise<RuntimeState> {
    const s = new RuntimeState()
    s.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    s.command = this.command(config)

    if (!this.bridge.canStartProcess()) {
      s.status = 'manual_required'
      s.message = 'V1 需要手动启动本地 Runtime。V2 将通过 Native Bridge 一键启动。'
      s.logs.push(`[manual] ${s.command}`)
      return s
    }

    const req = new ProcessStartRequest()
    req.command = 'opencode'
    req.args = ['serve', '--port', `${config.port}`, '--hostname', config.mode === 'local' ? config.host : '0.0.0.0']
    req.cwd = config.workspace

    const handle = await this.bridge.start(req)
    s.status = handle.started ? 'starting' : 'error'
    s.message = handle.message
    s.logs.push(`[process] ${handle.message}`)
    return s
  }

  async health(config: RuntimeConfig): Promise<RuntimeState> {
    const s = new RuntimeState()
    const runner = this.createRunner(config)
    s.baseUrl = runnerBaseUrl(runner)
    s.command = this.command(config)

    try {
      const client = new OpenCodeClient(runner)
      const health = await client.health()
      if (health.ok) {
        s.status = 'running'
        s.version = health.version
        s.message = `Runtime running: ${s.baseUrl}`
        s.logs.push(`[ok] /global/health version=${health.version}`)
      } else {
        s.status = 'stopped'
        s.message = `Runtime not reachable: ${health.error}`
        s.logs.push(`[fail] /global/health ${health.error}`)
      }
    } catch (e) {
      s.status = 'error'
      s.message = `Runtime health failed: ${errStr(e)}`
      s.logs.push(`[error] ${errStr(e)}`)
    }

    return s
  }

  async activate(config: RuntimeConfig): Promise<RuntimeState> {
    const s = await this.health(config)
    if (s.status !== 'running') return s

    const runner = this.createRunner(config)
    runner.status = 'connected'
    runner.version = s.version
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

    s.logs.push('[ok] runner saved and activated')
    return s
  }
}

export const localOpenCodeRuntimeService = new LocalOpenCodeRuntimeService()
