# M11 Demo Script：可录屏演示流程

## 演示目标

展示 OpenCode Harmony Native 已经从“静态 UI 原型”进入“真实 OpenCode Server 联调”阶段。

## 演示准备

1. 启动 OpenCode Server：

```bash
cd /path/to/opencode-harmony-test-project
opencode serve --port 4096 --hostname 0.0.0.0
```

2. 打开鸿蒙 App。
3. 确认 Server 配置为当前机器 IP 和 4096 端口。

## 演示流程

### Step 1：启动 App

展示：

- 深色 OpenCode-like 界面。
- 顶部状态栏。
- 左侧 ActivityBar。
- Session Sidebar。
- 中间 Transcript。
- 右侧 tools/diff/logs。
- 底部 Composer。

讲解词：

```text
这是鸿蒙原生 ArkUI 实现的 OpenCode 客户端，不是 Electron，不是 WebView。
```

### Step 2：连接 OpenCode Server

展示：

- offline → online。
- TopStatusBar 出现 server version。
- LogsPanel 出现 server.connected。

### Step 3：新建 Session

点击 new session。

展示：

- SessionSidebar 出现新 session。
- 中间 session header 更新。

### Step 4：发送 Prompt

输入：

```text
请阅读这个项目，给 calculator.ts 增加 subtract(a,b) 和 multiply(a,b) 两个函数，并补充测试。
```

展示：

- 用户消息进入 Transcript。
- LogsPanel 出现 message.sending。
- Composer 进入 running 状态。

### Step 5：观察工具调用

展示右侧 tools tab：

- read
- grep/glob
- edit/write
- bash/test

要求：

- 工具调用不重复。
- 状态清晰。

### Step 6：权限审批

如果出现权限请求：

- 显示 permission block。
- 点击 allow。
- LogsPanel 显示 permission.reply.once。
- Agent 继续。

如果点击 deny：

- LogsPanel 显示 permission.reply.deny。
- Agent 停止对应操作或给出反馈。

### Step 7：查看 Diff

切换 diff tab。

展示：

- calculator.ts 修改。
- test 文件修改。
- 新增/删除行颜色区分。

### Step 8：查看 Logs

切换 logs tab。

展示完整流程：

```text
server.connected
session.created
message.sending
poll.message.updated
tool.detected
permission.reply.once
diff.loaded
```

### Step 9：总结

讲解词：

```text
这一版完成的是鸿蒙原生 GUI + OpenCode Server 的端到端闭环。下一步会把轮询事件升级为真正 SSE，并进一步做 RuntimeManager 和打包体验。
```
