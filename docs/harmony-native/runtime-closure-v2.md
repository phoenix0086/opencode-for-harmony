# Runtime Closure V2

## 当前目标

把 Native Bridge 真正接成可用功能：

```text
启动本地 Runtime
停止 Runtime
重启 Runtime
检测 health
启动后自动连接
```

## 用户路径

```text
本地 Runtime 页面
→ 点击启动本地 Runtime
→ Native Bridge startProcess(opencode serve)
→ 自动轮询 /global/health
→ 成功后 saveAndActivate
→ onRunnerActivated
→ onReconnect
```

## 和之前区别

之前：

```text
显示启动命令
用户手动运行
用户检测
用户保存连接
```

现在：

```text
App 直接启动进程
App 自动检测
App 自动激活 runner
```

## 还不是最终版的地方

当前仍依赖系统 PATH 里存在 `opencode`。

最终 V3 要做：

```text
App 内置 opencode runtime
优先使用 bundle 内路径
找不到才使用 PATH
```
