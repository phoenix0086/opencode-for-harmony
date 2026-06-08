# Local OpenCode Server Manager V1

## 目标

先做“方案一”的第一版：让 App 内部管理本地 OpenCode Server 的状态。

V1 不直接启动外部进程，而是完成：

```text
1. 显示本地服务启动命令
2. 检测 /global/health
3. 保存并激活 localhost runner
4. 支持开发电脑 / 局域网模式
5. 支持远程 server 模式
6. 为以后 Native Bridge 一键启动 opencode serve 预留服务层
```

## 为什么 V1 不直接启动 opencode serve

`opencode serve` 是一个外部 CLI 进程。纯 ArkTS 页面代码不能简单等价于在终端执行一行 shell 命令。

真正一键启动需要后续做其中一种：

```text
1. Harmony PC 可用的子进程 / Native Bridge
2. 随 App 打包 opencode 二进制
3. 通过系统能力拉起外部终端或后台任务
4. 做一个独立本地守护服务
```

所以 V1 先做“管理与连接”，不是假装已经内置启动。

## 三种模式

### 本机模式

App 和 server 在同一台鸿蒙 PC 上：

```bash
opencode serve --port 4096 --hostname 127.0.0.1
```

App 里填：

```text
Host: 127.0.0.1
Port: 4096
```

### 开发电脑 / 局域网模式

App 在模拟器或真机，server 在开发电脑：

```bash
opencode serve --port 4096 --hostname 0.0.0.0
```

App 里填开发电脑 IP：

```text
Host: 192.168.x.x
Port: 4096
```

### 远程模式

App 连接远程服务器：

```text
Host: server.example.com
Port: 4096
Token: 可选
```

## 下一步

V2 做 Native Bridge：

```ts
startProcess(command: string): Promise<ProcessHandle>
stopProcess(pid: number): Promise<boolean>
readLogs(pid: number): Promise<string[]>
```
