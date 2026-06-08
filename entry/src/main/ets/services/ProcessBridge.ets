import nativeModule from 'libopencode_native.so'

export class ProcessBridge {
  static startProcess(command: string, args: string[]): number {
    return nativeModule.processStart(command, args) as number
  }

  static stopProcess(pid: number): boolean {
    return nativeModule.processStop(pid) as boolean
  }

  static isRunning(pid: number): boolean {
    return nativeModule.processIsRunning(pid) as boolean
  }

  static exitCode(pid: number): number {
    return nativeModule.processExitCode(pid) as number
  }

  static setLogCallback(callback: (line: string) => void): void {
    nativeModule.processSetLogCallback(callback)
  }

  static stopAll(): void {
    nativeModule.processStopAll()
  }
}
