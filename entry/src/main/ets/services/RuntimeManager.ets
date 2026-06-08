import { OpenCodeClient, HealthResult } from './OpenCodeClient'
import { Runner, createRunner, RunnerConfig } from '../models/Runner'

/**
 * Runtime 管理器
 * 负责检测、连接和管理 OpenCode Server 实例
 *
 * 阶段一：仅做连接检测和状态管理
 * 阶段二：尝试启动外部 opencode 进程（需验证 HarmonyOS 权限）
 * 阶段三：随包内置 sidecar（需验证沙箱和打包限制）
 */
export class RuntimeManager {
  private runners: Runner[] = []
  private activeRunner: Runner | null = null
  private healthCheckInterval: number = -1
  private healthCheckPeriod: number = 30000 // 30秒

  // ══════════ Runner 管理 ══════════

  setRunners(runners: Runner[]): void {
    this.runners = runners
  }

  getRunners(): Runner[] {
    return this.runners
  }

  getActiveRunner(): Runner | null {
    return this.activeRunner
  }

  setActiveRunner(runner: Runner | null): void {
    this.activeRunner = runner
    if (runner) {
      this.startHealthCheck()
    } else {
      this.stopHealthCheck()
    }
  }

  addRunner(config: RunnerConfig): Runner {
    const runner = createRunner(config)
    this.runners.push(runner)
    return runner
  }

  removeRunner(id: string): void {
    const newList: Runner[] = []
    for (const r of this.runners) {
      if (r.id !== id) {
        newList.push(r)
      }
    }
    this.runners = newList
    if (this.activeRunner !== null && this.activeRunner!.id === id) {
      this.setActiveRunner(null)
    }
  }

  // ══════════ 健康检查 ══════════

  async checkHealth(runner: Runner): Promise<HealthResult> {
    const client = new OpenCodeClient(runner)
    return client.health()
  }

  async checkActiveRunner(): Promise<HealthResult> {
    if (this.activeRunner === null) {
      const r = new HealthResult()
      r.ok = false
      r.error = '没有活动的 Runner'
      return r
    }
    return this.checkHealth(this.activeRunner!)
  }

  /**
   * 更新 Runner 状态
   */
  async refreshRunnerStatus(runner: Runner): Promise<Runner> {
    const result = await this.checkHealth(runner)
    const updated = new Runner()
    updated.id = runner.id
    updated.name = runner.name
    updated.host = runner.host
    updated.port = runner.port
    updated.protocol = runner.protocol
    updated.token = runner.token
    updated.status = result.ok ? 'online' : 'offline'
    updated.version = result.version
    updated.lastConnectedAt = result.ok ? Date.now() : runner.lastConnectedAt
    updated.createdAt = runner.createdAt
    updated.updatedAt = Date.now()
    return updated
  }

  /**
   * 启动定期健康检查
   */
  startHealthCheck(): void {
    this.stopHealthCheck()
    this.healthCheckInterval = setInterval(async () => {
      if (this.activeRunner !== null) {
        const result = await this.checkHealth(this.activeRunner!)
        if (!result.ok) {
          // Runner 离线
          this.activeRunner!.status = 'offline'
        } else {
          this.activeRunner!.status = 'online'
          this.activeRunner!.version = result.version
        }
      }
    }, this.healthCheckPeriod)
  }

  /**
   * 停止定期健康检查
   */
  stopHealthCheck(): void {
    if (this.healthCheckInterval !== -1) {
      clearInterval(this.healthCheckInterval)
      this.healthCheckInterval = -1
    }
  }

  // ══════════ 阶段二：外部进程管理（验证性） ══════════

  /**
   * 检测本机是否安装了 opencode
   * 注意：HarmonyOS 沙箱环境下可能无法执行此操作
   */
  static getInstallCheckCommand(): string {
    return 'which opencode || command -v opencode'
  }

  /**
   * 获取启动 opencode serve 的命令
   */
  static getStartCommand(port: number, hostname: string, projectDir?: string): string {
    let cmd = `opencode serve --port ${port} --hostname ${hostname}`
    if (projectDir) {
      cmd += ` --directory ${projectDir}`
    }
    return cmd
  }

  /**
   * 获取带密码的启动命令
   */
  static getStartCommandWithAuth(port: number, hostname: string, password: string): string {
    return `OPENCODE_SERVER_PASSWORD=${password} opencode serve --port ${port} --hostname ${hostname}`
  }

  /**
   * 获取停止命令
   */
  static getStopCommand(port: number): string {
    return `lsof -ti:${port} | xargs kill`
  }

  /**
   * 检查端口是否被占用
   */
  static getPortCheckCommand(port: number): string {
    return `lsof -i:${port} -t`
  }

  // ══════════ 连接建议 ══════════

  /**
   * 生成用户友好的启动指南
   */
  static getStartupGuide(): string[] {
    return [
      '在电脑上启动 OpenCode Server:',
      '',
      '1. 安装 OpenCode:',
      '   curl -fsSL https://opencode.ai/install | bash',
      '',
      '2. 进入项目目录:',
      '   cd /path/to/your/project',
      '',
      '3. 启动 Server:',
      '   opencode serve --port 4096 --hostname 0.0.0.0',
      '',
      '4. 如果需要密码保护:',
      '   OPENCODE_SERVER_PASSWORD=your-password opencode serve --port 4096 --hostname 0.0.0.0',
      '',
      '5. 在平板上配置 Server 地址:',
      '   地址: 你电脑的局域网 IP',
      '   端口: 4096',
      '   密码: 你设置的密码（如果有）',
      '',
      '提示:',
      '- 确保平板和电脑在同一网络下',
      '- 查看电脑 IP: macOS 用 ifconfig, Windows 用 ipconfig',
      '- 如果连接失败，检查防火墙设置',
    ]
  }

  /**
   * 验证报告 - 鸿蒙 App 是否能管理 Runtime
   */
  static getVerificationReport(): VerificationReport {
    const report = new VerificationReport()
    report.canDetectInstalled = false
    report.canStartProcess = false
    report.canReadStdout = false
    report.canStopProcess = false
    report.canHandlePortConflict = false
    report.conclusion = '第一阶段建议使用外置 OpenCode Server，鸿蒙 App 仅做连接检测和状态管理。' +
      'HarmonyOS 沙箱环境对进程管理有严格限制，需要进一步验证是否能在 App 内执行系统命令。' +
      '建议阶段二通过 Native C++ 模块或 Extension Ability 探索进程管理能力。'
    return report
  }
}

/**
 * 验证报告
 */
export class VerificationReport {
  canDetectInstalled: boolean = false
  canStartProcess: boolean = false
  canReadStdout: boolean = false
  canStopProcess: boolean = false
  canHandlePortConflict: boolean = false
  conclusion: string = ''
}

export const runtimeManager = new RuntimeManager()
