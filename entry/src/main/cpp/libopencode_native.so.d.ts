/**
 * Type declarations for the opencode_native NAPI module.
 * Wraps C++ ProcessManager for subprocess lifecycle management.
 */
declare namespace libopencode_native {
  /**
   * Fork+exec a child process.
   * @param command  absolute path to the executable
   * @param args     command-line arguments (argv[1..])
   * @returns child PID on success, -1 on failure
   */
  function processStart(command: string, args: string[]): number;

  /**
   * Fork+exec with working directory and environment variables.
   * @param command  absolute path to the executable
   * @param args     command-line arguments (argv[1..])
   * @param cwd      working directory (empty string = inherit parent)
   * @param env      environment variables to set (merged with parent env)
   * @returns child PID on success, -1 on failure
   */
  function processStartEx(command: string, args: string[], cwd: string, env?: Record<string, string>): number;

  /**
   * Send SIGTERM (then SIGKILL after timeout) to a managed process.
   */
  function processStop(pid: number): boolean;

  /**
   * Check whether a managed process is still running.
   */
  function processIsRunning(pid: number): boolean;

  /**
   * Return the exit code of a terminated process, or -1 if unknown.
   */
  function processExitCode(pid: number): number;

  /**
   * Drain buffered stdout/stderr lines for a process.
   */
  function processDrainLogs(pid: number): string[];

  /**
   * Register a JS callback for log forwarding (backward compat only).
   */
  function processSetLogCallback(callback: (line: string) => void): void;

  /**
   * Stop all managed processes.
   */
  function processStopAll(): void;

  /**
   * Change file permission bits (POSIX chmod).
   * @param path  absolute file path
   * @param mode  permission mode, e.g. 0o755
   */
  function processChmod(path: string, mode: number): boolean;
}

export default libopencode_native;
