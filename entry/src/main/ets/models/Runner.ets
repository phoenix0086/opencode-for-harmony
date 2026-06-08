export class Runner {
  id: string = ''
  name: string = ''
  host: string = ''
  port: number = 0
  protocol: 'http' | 'https' = 'http'
  token: string = ''
  status: string = 'unknown'
  version: string = ''
  lastConnectedAt: number = 0
  createdAt: number = 0
  updatedAt: number = 0
}

export class RunnerConfig {
  name: string = ''
  host: string = ''
  port: number = 4096
  protocol: 'http' | 'https' = 'http'
  token: string = ''
}

export function createRunner(config: RunnerConfig): Runner {
  const r = new Runner()
  const now = Date.now()
  r.id = `runner_${now}_${Math.floor(Math.random() * 999999)}`
  r.name = config.name
  r.host = config.host
  r.port = config.port
  r.protocol = config.protocol
  r.token = config.token
  r.status = 'unknown'
  r.createdAt = now
  r.updatedAt = now
  return r
}

export function runnerBaseUrl(r: Runner): string {
  return `${r.protocol}://${r.host}:${r.port}`
}
