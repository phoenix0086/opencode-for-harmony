import { FullRunner, FullHealth, FullRuntimeConfig, FullRuntimeState } from '../models/FullAppModels'
import { OpenCodeApiClient } from './OpenCodeApiClient'
import { errStr } from '../utils/ErrorUtil'

export class LocalRuntimeManager {
  createRunner(config: FullRuntimeConfig): FullRunner {
    const r = new FullRunner()
    r.id = `${config.protocol}-${config.host}-${config.port}`
    r.name = config.mode === 'remote' ? 'Remote OpenCode Runtime' : 'Local OpenCode Runtime'
    r.host = config.host
    r.port = config.port
    r.protocol = config.protocol
    r.token = config.token
    return r
  }

  command(config: FullRuntimeConfig): string {
    if (config.mode === 'local') {
      return `opencode serve --port ${config.port} --hostname ${config.host}`
    }
    return `opencode serve --port ${config.port} --hostname 0.0.0.0`
  }

  async health(config: FullRuntimeConfig): Promise<FullRuntimeState> {
    const s = new FullRuntimeState()
    const runner = this.createRunner(config)
    s.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    s.command = this.command(config)

    try {
      const client = new OpenCodeApiClient(runner)
      const h: FullHealth = await client.health()
      if (h.ok) {
        s.status = 'running'
        s.version = h.version
        s.message = `Runtime 已连接：${s.baseUrl}`
      } else {
        s.status = 'stopped'
        s.message = `Runtime 未连接：${h.error}`
      }
    } catch (e) {
      s.status = 'error'
      s.message = errStr(e)
    }

    return s
  }

  async prepareStart(config: FullRuntimeConfig): Promise<FullRuntimeState> {
    const s = new FullRuntimeState()
    s.baseUrl = `${config.protocol}://${config.host}:${config.port}`
    s.command = this.command(config)
    s.status = 'manual_required'
    s.message = 'V0.1 显示启动命令；V0.2 通过 Native Bridge 启动 opencode serve。'
    return s
  }
}

export const localRuntimeManager = new LocalRuntimeManager()
