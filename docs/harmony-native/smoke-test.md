## Smoke Test Guide — M9 Runtime Verification

本手册描述 M9 阶段的运行时联调测试流程，用于验证 AppShell 三栏布局在真机/模拟器上的可运行性。

### 前置条件

1. HarmonyOS 6.0 真机或 DevEco Studio 模拟器 (API 12)
2. OpenCode Server 已安装并运行:
   ```bash
   curl -fsSL https://opencode.ai/install | bash
   cd /path/to/test/project
   opencode serve --port 4096 --hostname 0.0.0.0
   ```
3. 设备与 Server 在同一网络（或使用 localhost）

### Test 1: 应用启动

| Step | Action | Expected |
|------|--------|----------|
| 1.1 | 启动 App | 显示 OC loading 动画 (深色背景 #1e1e2e) |
| 1.2 | 等待初始化完成 | 过渡到三栏 IDE 布局 |
| 1.3 | 检查 TopStatusBar | 显示 server URL, 连接状态 |
| 1.4 | 检查 LeftActivityBar | 显示 OC logo + 5 个文字符号导航 |
| 1.5 | 检查连接指示器 | 底部圆点: 绿色=online / 红色=offline |

### Test 2: 导航切换

| Step | Action | Expected |
|------|--------|----------|
| 2.1 | 点击 `>` (Chat) | 中心区域显示 session header + transcript + composer |
| 2.2 | 点击 `{}` (Files) | 中心区域显示 FilePanel (项目信息 + 文件列表) |
| 2.3 | 点击 `~` (Diff) | 中心区域显示 DiffPanel |
| 2.4 | 点击 `P` (Provider) | 中心区域显示 ProviderPage (深色主题) |
| 2.5 | 点击 `*` (Settings) | 中心区域显示 SettingsPage (深色主题) |

### Test 3: 右侧面板

| Step | Action | Expected |
|------|--------|----------|
| 3.1 | 点击 `tools` tab | 显示工具调用时间线 |
| 3.2 | 点击 `diff` tab | 显示文件变更列表 |
| 3.3 | 点击 `logs` tab | 显示事件流日志 (带颜色编码) |
| 3.4 | 点击 `x` 关闭面板 | 右侧面板隐藏, 中心区域扩展 |
| 3.5 | 点击 `[]` 重新打开 | 右侧面板恢复 |

### Test 4: Server 连接

| Step | Action | Expected |
|------|--------|----------|
| 4.1 | 确保 Runner 已配置 | 启动时自动连接 |
| 4.2 | 查看 LogsPanel | 应显示 "Connecting to host:port..." |
| 4.3 | 连接成功后 | LogsPanel 显示 "Connected (vX.X.X)" |
| 4.4 | TopStatusBar 更新 | 显示项目名称、分支名、版本号 |
| 4.5 | LeftActivityBar 指示器 | 变为绿色 "online" |

### Test 5: 会话管理

| Step | Action | Expected |
|------|--------|----------|
| 5.1 | SessionSidebar 加载 | 显示已有会话列表 |
| 5.2 | 点击 "new session" | 创建新会话并自动选中 |
| 5.3 | 点击已有会话 | 加载消息到 AgentTranscript |
| 5.4 | SessionHeader 更新 | 显示 "session / title" |

### Test 6: 消息交互

| Step | Action | Expected |
|------|--------|----------|
| 6.1 | 在 ComposerBar 输入文本 | 文字正常显示 |
| 6.2 | 点击发送 `[>]` | 用户消息出现在 transcript, 输入框清空 |
| 6.3 | 等待 Agent 回复 | 流式文本逐步显示 (isStreaming=true) |
| 6.4 | 查看 LogsPanel | 应显示 llm.started → tool.started → tool.success → llm.ended → session.idle |
| 6.5 | 查看 tools tab | 工具调用按时间线排列, 无重复 |
| 6.6 | 权限请求弹出 | 内联审批栏出现, allow/deny 可点击 |

### Test 7: Diff 查看

| Step | Action | Expected |
|------|--------|----------|
| 7.1 | 在有文件变更的会话中点击 diff tab | 显示变更文件列表 |
| 7.2 | 文件状态标识 | A=新增, M=修改, D=删除, R=重命名 |
| 7.3 | 点击文件 | 展开 patch 内容, 增删行有颜色区分 |

### Test 8: Provider 配置

| Step | Action | Expected |
|------|--------|----------|
| 8.1 | 切换到 Provider 页面 | 深色主题卡片列表 |
| 8.2 | Toggle 启用/禁用 | 状态即时更新 |
| 8.3 | 展开 Provider 卡片 | 显示模型列表 + API Key 输入 + 默认模型选择 |
| 8.4 | 点击 "generate config" | 显示 opencode.json 配置输出 |

### Test 9: 设置

| Step | Action | Expected |
|------|--------|----------|
| 9.1 | 切换到 Settings 页面 | 深色主题分区卡片 |
| 9.2 | 调整字号 Slider | 数值实时更新 |
| 9.3 | 点击 "save settings" | 状态消息 "settings saved" (绿色) |
| 9.4 | 点击 "clear local data" | 出现二次确认, 确认后数据清除 |

### 日志颜色编码

| 日志关键词 | 颜色 | 说明 |
|-----------|------|------|
| error, failed | 红色 (#f38ba8) | 错误 |
| connected, success, idle | 绿色 (#a6e3a1) | 成功/空闲 |
| started, Sending | 蓝色 (#89b4fa) | 进行中 |
| 其他 | 灰色 (#6c7086) | 默认 |

### 已知限制

- EventStreamClient 使用轮询模式 (2 秒间隔), 非真正 SSE
- FilePanel 依赖 OpenCode `/file` API, 需要 Server 支持
- ProviderPage API Key 保存依赖 Server `/auth` API
- 暂不支持真正的文件编辑/预览, 仅展示文件列表
