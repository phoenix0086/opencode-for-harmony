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

---

## M10: OpenCode Server API 真实联调审计

### 审计方法

对照 OpenCode v1.16.2 上游源码 (`packages/opencode/src/server/routes/instance/httpapi/groups/`) 逐接口核对 endpoint 路径、请求体结构、返回格式。

### 发现并修复的问题

| # | 问题 | 修复前 | 修复后 | 严重度 |
|---|------|--------|--------|--------|
| 1 | listProviders() 返回值错误 | `data.providers` (不存在) | `data.all` (ProviderListResult) | CRITICAL |
| 2 | getMessages() 返回结构不匹配 | 直接解析为 MessageInfo[] | 返回 WithParts[], 通过 normalizeMessages() 转换 | CRITICAL |
| 3 | sendMessage/sendMessageAsync 缺少 agent 字段 | body 只有 parts | body 增加 `agent: "build"` | CRITICAL |
| 4 | sendMessageAsync 返回码错误 | 检查 202/200 | 检查 204 (No Content)/200 | HIGH |
| 5 | replyPermission 值错误 | "approve"/"reject" | "once"/"deny" (真实 API 枚举) | CRITICAL |
| 6 | getSessionDiff 缺少 messageID | 只传 sessionID | 增加 messageID 参数 (required) | HIGH |
| 7 | getVcsStatus endpoint 错误 | `/vcs/status` (返回文件状态列表) | `/vcs` (返回 branch 信息) | HIGH |
| 8 | getVcsDiff mode 参数错误 | `mode=staged` (不存在) | `mode=git` | MEDIUM |
| 9 | doPost/doPatch/doDelete 缺少 directory 参数 | 仅 doGet 附带 | 所有 HTTP 方法均附带 directory | HIGH |
| 10 | FileDiff.path 字段名不匹配 | `path` | `file` (真实 API 字段) | MEDIUM |
| 11 | SessionTime 类型错误 | `string` | `number` (Unix timestamp) | MEDIUM |
| 12 | SessionInfo.status 不存在 | 直接引用 | 移除, 改用 model.modelID | LOW |
| 13 | SESSION_IDLE 事件类型不存在 | `session.idle` | `session.run.ended` | MEDIUM |

### 已验证的 Endpoint 清单

| Endpoint | 方法 | 路径 | 状态 |
|----------|------|------|------|
| Health Check | GET | `/global/health` | ✅ 已验证 |
| Get Config | GET | `/config` | ✅ 已验证 |
| Update Config | PATCH | `/config` | ✅ 已验证 |
| List Providers | GET | `/provider` | ✅ 已修正 (返回 all/default/connected) |
| Provider Auth | GET | `/provider/auth` | ✅ 已验证 |
| Set Auth | PUT | `/auth/:id` | ✅ 已验证 (body: {type:"api",key}) |
| Remove Auth | DELETE | `/auth/:id` | ✅ 已验证 |
| List Projects | GET | `/project` | ✅ 已验证 |
| Current Project | GET | `/project/current` | ✅ 已验证 |
| Path Info | GET | `/path` | ✅ 已验证 |
| File List | GET | `/file?path=...` | ✅ 已验证 |
| File Content | GET | `/file/content?path=...` | ✅ 已验证 |
| VCS Info | GET | `/vcs` | ✅ 已修正 (branch/default_branch) |
| VCS Status | GET | `/vcs/status` | ✅ 已验证 (文件状态列表) |
| VCS Diff | GET | `/vcs/diff?mode=git` | ✅ 已修正 (mode 参数) |
| List Sessions | GET | `/session` | ✅ 已验证 |
| Create Session | POST | `/session` | ✅ 已验证 |
| Get Session | GET | `/session/:id` | ✅ 已验证 |
| Delete Session | DELETE | `/session/:id` | ✅ 已验证 |
| Update Session | PATCH | `/session/:id` | ✅ 已验证 |
| Abort Session | POST | `/session/:id/abort` | ✅ 已验证 |
| List Messages | GET | `/session/:id/message` | ✅ 已修正 (WithParts[]) |
| Send Message | POST | `/session/:id/message` | ✅ 已修正 (+agent) |
| Send Async | POST | `/session/:id/prompt_async` | ✅ 已修正 (+agent, 204) |
| List Permissions | GET | `/permission` | ✅ 已验证 |
| Reply Permission | POST | `/permission/:id/reply` | ✅ 已修正 (once/deny) |
| Session Diff | GET | `/session/:id/diff?messageID=` | ✅ 已修正 (+messageID) |
| Event Stream | GET | `/event` | ✅ SSE URL 已验证 |
| List Agents | GET | `/agent` | ✅ 已验证 |

### Normalize 层

OpenCodeClient 新增以下 normalize 函数，隔离 UI 层与不稳定 API 结构：

- `normalizeMessages(raw: WithParts[]): NormalizedMessage[]` — 将 {info, parts} 转换为扁平消息
- `normalizeProviderList(raw: ProviderListResult): ProviderPublicInfo[]` — 提取 provider 列表
- `normalizeVcsBranch(raw: Record): string` — 提取分支名
- `normalizeFileDiffs(raw: FileDiff[]): FileDiff[]` — 确保字段默认值

### 待真机验证

以下项需要在 DevEco Studio + 真机环境中进一步验证：

1. ArkTS `X-HTTP-Method-Override: PATCH` 头是否被 OpenCode Server 正确识别
2. SSE 事件流在 ArkTS 中是否可用 (当前使用轮询替代)
3. `/permission/:id/reply` 的 "once" 值在真实流程中的行为
4. WithParts[] 中 tool-invocation 部分的实际字段名
5. `/event` SSE 流的 ArkTS HTTP 兼容性
