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

  /**
   * Safe log collection.
   * Native side stores process output in a queue. ArkTS drains logs from UI/service.
   */
  static drainLogs(pid: number): string[] {
    return nativeModule.processDrainLogs(pid) as string[]
  }

  /**
   * Backward compatibility only.
   * V2 no longer calls this callback from native worker threads.
   */
  static setLogCallback(callback: (line: string) => void): void {
    nativeModule.processSetLogCallback(callback)
  }

  static stopAll(): void {
    nativeModule.processStopAll()
  }

  /**
   * Set file permissions via native POSIX chmod (avoids CoreFileKit chmodSync absence).
   * @param path  absolute file path
   * @param mode  octal permission bits, e.g. 0o755
   */
  static chmodFile(path: string, mode: number): boolean {
    return nativeModule.processChmod(path, mode) as boolean
  }
}
