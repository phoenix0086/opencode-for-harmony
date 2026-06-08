export class ProcessStartRequest {
  command: string = ''
  args: string[] = []
  cwd: string = ''
  env: Record<string, string> = {}
}

export class ProcessHandle {
  pid: number = -1
  started: boolean = false
  message: string = ''
}

export class ProcessStopResult {
  stopped: boolean = false
  message: string = ''
}

export class ProcessLogResult {
  lines: string[] = []
}

/**
 * Bridge contract for V2.
 *
 * Pure ArkTS cannot be treated as a shell. A production build should implement
 * this contract through Harmony Native Bridge or a packaged local daemon.
 */
export interface ILocalProcessBridge {
  canStartProcess(): boolean
  start(request: ProcessStartRequest): Promise<ProcessHandle>
  stop(pid: number): Promise<ProcessStopResult>
  logs(pid: number): Promise<ProcessLogResult>
}

/**
 * V1 implementation.
 *
 * It does not start external processes. It returns the command the user/dev
 * should run, then LocalOpenCodeRuntimeService can health-check and connect.
 */
export class ManualProcessBridge implements ILocalProcessBridge {
  canStartProcess(): boolean {
    return false
  }

  async start(request: ProcessStartRequest): Promise<ProcessHandle> {
    const h = new ProcessHandle()
    h.started = false
    h.pid = -1
    h.message = `Manual start required: ${request.command} ${request.args.join(' ')}`
    return h
  }

  async stop(pid: number): Promise<ProcessStopResult> {
    const r = new ProcessStopResult()
    r.stopped = false
    r.message = 'ManualProcessBridge cannot stop external process.'
    return r
  }

  async logs(pid: number): Promise<ProcessLogResult> {
    const r = new ProcessLogResult()
    r.lines = ['ManualProcessBridge has no process logs.']
    return r
  }
}

export const manualProcessBridge = new ManualProcessBridge()
