import nativeModule from 'libopencode_native.so'

export class ProcessBridge {
  /**
   * Check if the native module loaded successfully.
   * Returns false when libopencode_native.so is missing or failed to initialize.
   */
  static get isAvailable(): boolean {
    return nativeModule !== undefined && nativeModule !== null
  }

  static startProcess(command: string, args: string[]): number {
    if (!ProcessBridge.isAvailable) return -1
    return nativeModule.processStart(command, args) as number
  }

  /**
   * Start a process with working directory and environment variables.
   * @param command  absolute path to the executable
   * @param args     command-line arguments
   * @param cwd      working directory (empty string = inherit parent)
   * @param env      environment variables (merged with parent env)
   * @returns child PID on success, -1 on failure
   */
  static startProcessEx(command: string, args: string[], cwd: string, env?: Record<string, string>): number {
    if (!ProcessBridge.isAvailable) return -1
    if (env && Object.keys(env).length > 0) {
      return nativeModule.processStartEx(command, args, cwd, env) as number
    }
    return nativeModule.processStartEx(command, args, cwd) as number
  }

  static stopProcess(pid: number): boolean {
    if (!ProcessBridge.isAvailable) return false
    return nativeModule.processStop(pid) as boolean
  }

  static isRunning(pid: number): boolean {
    if (!ProcessBridge.isAvailable) return false
    return nativeModule.processIsRunning(pid) as boolean
  }

  static exitCode(pid: number): number {
    if (!ProcessBridge.isAvailable) return -1
    return nativeModule.processExitCode(pid) as number
  }

  /**
   * Safe log collection.
   * Native side stores process output in a queue. ArkTS drains logs from UI/service.
   */
  static drainLogs(pid: number): string[] {
    if (!ProcessBridge.isAvailable) return []
    return nativeModule.processDrainLogs(pid) as string[]
  }

  /**
   * Backward compatibility only.
   * V2 no longer calls this callback from native worker threads.
   */
  static setLogCallback(callback: (line: string) => void): void {
    if (!ProcessBridge.isAvailable) return
    nativeModule.processSetLogCallback(callback)
  }

  static stopAll(): void {
    if (!ProcessBridge.isAvailable) return
    nativeModule.processStopAll()
  }

  /**
   * Set file permissions via native POSIX chmod (avoids CoreFileKit chmodSync absence).
   * @param path  absolute file path
   * @param mode  octal permission bits, e.g. 0o755
   */
  static chmodFile(path: string, mode: number): boolean {
    if (!ProcessBridge.isAvailable) return false
    return nativeModule.processChmod(path, mode) as boolean
  }
}
