# OpenCode Harmony Native 功能补齐改造方案

版本：v1.0  
日期：2026-06-12  
适用项目：`/Volumes/MyDisk/coding/ohopencode`  
对比对象：

- `/Applications/OpenCode.app`，OpenCode Desktop 1.16.2 Electron 打包版本。
- `/Users/phoenix/Downloads/opencode-dev 2`，新版 OpenCode monorepo 源码。

---

## 1. 目标

本方案的目标是把当前 HarmonyOS 原生客户端从“可展示的 OpenCode 外壳”推进到“能稳定连接新版 OpenCode Runtime，并覆盖桌面端核心工作流”的版本。

最终目标：

```text
1. 支持新版 /api/... Server API。
2. 保留对旧版 OpenCode 1.16.2 API 的兼容层。
3. 会话、消息、权限、问题、文件、模型、Provider、命令、Skill 全部走真实 Runtime。
4. MCP、Connector、终端、文件树、Composer、Settings 从占位 UI 变成可用功能。
5. Runtime 启动、连接、日志、错误提示形成闭环。
6. 每个核心工作流都有 smoke test 文档和最小自动化测试。
```

不建议继续直接堆 UI。当前最大风险是 API 路径、数据结构和真实 Runtime 行为没有完全对齐，先补协议和状态层，再补交互。

---

## 2. 当前状态判断

当前项目已有：

- ArkTS / ArkUI 原生界面骨架。
- 首页、会话、Provider、模型、Runtime、设置等页面。
- `OpenCodeClient` 旧版 API 客户端。
- `V2Client` 对 snapshot、PTY、plugin、compact 等端点的封装。
- `LocalOpenCodeServerManager` 对内置 `rawfile/opencode` 的提取、fork、日志采集和健康检查。
- Agent transcript、工具卡片、Diff 面板、文件面板、MCP 面板、PTY 面板、Plugin 面板、Command 面板、Skill 面板等 UI。

但存在以下核心问题：

```text
1. API 主要仍按旧路径调用：/session、/provider、/file、/permission、/command、/skill。
2. opencode-dev 2 新版 server API 已经切到 /api/session、/api/fs/list、/api/permission/request 等。
3. 多个面板只是展示壳，缺真实数据接入或操作回写。
4. MCP、Keybinds、Connector、Composer 附件、文件树、终端 tab 等功能不完整。
5. Runtime 启动有两套服务：LocalOpenCodeServerManager 和 LocalOpenCodeRuntimeService，职责重叠且行为不一致。
6. README 的完成度高于实际代码闭环，需要重新定义验收标准。
```

---

## 3. 总体改造原则

### 3.1 先协议，后 UI

先建立稳定的 Server API 适配层，再让 UI 接入。不要在组件里继续直接猜 endpoint。

### 3.2 新版优先，旧版兼容

默认支持 `opencode-dev 2` 的 `/api/...` 路由。旧版 Desktop 1.16.2 的无 `/api` 路由作为 fallback。

### 3.3 一个功能只保留一条主路径

当前存在多套 Runtime、Storage、Client、页面实现。需要收敛为：

```text
Runtime 管理：LocalOpenCodeServerManager
Server API：OpenCodeApiAdapter
状态同步：OpenCodeStore / ViewModel
UI 页面：AppShell + 页面组件
```

### 3.4 所有“面板”必须有数据来源和验收动作

每个面板都要回答：

```text
1. 数据从哪个 API 来？
2. 用户点击后调用哪个 API？
3. 成功后刷新哪个状态？
4. 失败时显示什么？
```

没有真实 API 的面板，标记为 unsupported，不再伪装成完成。

---

## 4. 阶段划分

建议分 6 个阶段执行：

```text
M21：Server API 适配层重构
M22：核心会话闭环对齐新版 API
M23：文件、权限、问题、Todo、Diff 状态补齐
M24：Composer、Tabs、Terminal、MCP、Connector 补齐
M25：Settings、Provider、Model、Keybinds、Runtime 管理收敛
M26：验收、测试、文档、兼容矩阵
```

每个阶段都必须能单独验收，不要一次性大改。

---

## 5. M21：Server API 适配层重构

### 5.1 目标

解决当前项目对新版 OpenCode Server 不兼容的问题。

新版 `opencode-dev 2` 的 API group 包括：

```text
GET  /api/health
GET  /api/location
GET  /api/agent
GET  /api/model
GET  /api/provider
GET  /api/provider/:providerID
GET  /api/connector
GET  /api/connector/:connectorID
POST /api/connector/:connectorID/connect/key
POST /api/connector/:connectorID/connect/oauth
GET  /api/connector/oauth/:attemptID
POST /api/connector/oauth/:attemptID/complete
DELETE /api/connector/oauth/:attemptID
GET  /api/session
POST /api/session
GET  /api/session/:sessionID
POST /api/session/:sessionID/prompt
POST /api/session/:sessionID/compact
POST /api/session/:sessionID/wait
GET  /api/session/:sessionID/context
GET  /api/session/:sessionID/message
GET  /api/permission/request
GET  /api/permission/saved
DELETE /api/permission/saved/:id
GET  /api/session/:sessionID/permission
POST /api/session/:sessionID/permission/:requestID/reply
GET  /api/question/request
GET  /api/session/:sessionID/question
POST /api/session/:sessionID/question/:requestID/reply
POST /api/session/:sessionID/question/:requestID/reject
GET  /api/fs/list
GET  /api/fs/find
GET  /api/fs/read/*
GET  /api/command
GET  /api/skill
GET  /api/event
GET  /api/reference
```

当前客户端大量调用旧路径，必须统一改造。

### 5.2 新增抽象

新增一个 API 适配层，建议命名：

```text
entry/src/main/ets/services/OpenCodeApiAdapter.ets
entry/src/main/ets/services/OpenCodeApiV2.ets
entry/src/main/ets/services/OpenCodeApiLegacy.ets
entry/src/main/ets/services/OpenCodeApiSchema.ets
```

职责：

- `OpenCodeApiAdapter`：对 UI 暴露稳定方法。
- `OpenCodeApiV2`：实现 `/api/...` 新路由。
- `OpenCodeApiLegacy`：实现旧 `/session`、`/provider` 等路由。
- `OpenCodeApiSchema`：集中放 ArkTS 类型和 normalize 函数。

示例方法形态：

```text
health()
detectCapabilities()
listSessions(query)
createSession(input)
sendPrompt(sessionID, prompt)
waitSession(sessionID)
listMessages(sessionID)
listSessionContext(sessionID)
listPermissionRequests(location)
listSessionPermissions(sessionID)
replyPermission(sessionID, requestID, reply)
listQuestions(sessionID)
replyQuestion(sessionID, requestID, optionIDs)
rejectQuestion(sessionID, requestID)
listFiles(path)
findFiles(query)
readFile(path)
listProviders()
getProvider(providerID)
listModels()
listCommands()
listSkills()
subscribeEvents()
```

### 5.3 能力探测

启动连接后必须执行能力探测：

```text
1. GET /api/health
2. 如果成功：mode = "api-v2"
3. 如果 404：尝试 GET /global/health
4. 如果成功：mode = "legacy"
5. 如果都失败：mode = "unknown"
```

能力结果保存在全局状态：

```text
serverMode: "api-v2" | "legacy" | "unknown"
capabilities: {
  fs: boolean
  sessionPrompt: boolean
  sessionWait: boolean
  sessionContext: boolean
  permissionSaved: boolean
  questionReject: boolean
  connector: boolean
  eventStream: boolean
  command: boolean
  skill: boolean
  pty: boolean
  mcp: boolean
}
```

UI 所有 unsupported 状态都从这里读，不再由组件内部猜。

### 5.4 响应结构 normalize

新版 API 大量返回：

```json
{ "data": ... }
```

旧版 API 可能直接返回数组或对象。

所有 API 方法必须 normalize 成同一种 ArkTS model。不要让组件知道 `data`、`all`、`connected`、`cursor` 等差异。

### 5.5 验收标准

M21 完成后：

```text
1. 连接 opencode-dev 2 server，能识别 api-v2。
2. 连接 /Applications/OpenCode.app 对应 1.16.2 server，能识别 legacy。
3. Health、Provider、Model、Session、Message、Permission、File、Command、Skill 都通过适配层调用。
4. UI 组件不再直接依赖旧 endpoint。
5. 有一份 api compatibility smoke matrix。
```

---

## 6. M22：核心会话闭环对齐新版 API

### 6.1 目标

让“创建会话、发送 prompt、等待执行、展示消息”完全走新版 API，并保留旧版 fallback。

### 6.2 新版流程

新版推荐流程：

```text
1. POST /api/session
   payload: { agent?, model?, location? }

2. POST /api/session/:sessionID/prompt
   payload: {
     id?,
     prompt,
     delivery?,
     resume?
   }

3. GET /api/event
   或 POST /api/session/:sessionID/wait

4. GET /api/session/:sessionID/message

5. GET /api/session/:sessionID/context
```

当前旧流程：

```text
POST /session
POST /session/:id/prompt_async
轮询 /session/:id/message
```

需要把 `MainViewModel.sendMessage()` 改成调用适配层，不再直接使用 `HttpService` 和旧常量。

### 6.3 消息状态模型

新增统一状态：

```text
SessionRunState:
  idle
  admitting
  running
  waiting_permission
  waiting_question
  completed
  aborted
  error
```

UI 的 `isGenerating`、`sendLock`、`activeTurnId` 应该合并到这个状态机里。

### 6.4 Event Stream

优先接入 `/api/event`：

```text
1. 能 SSE 就用 SSE。
2. HarmonyOS SSE 不稳定时，用长轮询兼容层。
3. 事件 reducer 统一处理 session、message、permission、question、todo、tool events。
```

不要只靠固定间隔拉 message，因为权限、question、todo、tool status 都会滞后。

### 6.5 Stop / Abort

当前有 `/abort` 旧接口假设。新版需要确认 server API 是否提供 abort 或通过 session input/run state 控制。

方案：

```text
1. api-v2 模式：优先按新版 SDK 能力实现。
2. legacy 模式：保留 /session/:id/abort。
3. 如果 server 不支持：UI 显示 unsupported，不假装已停止。
```

### 6.6 验收标准

```text
1. 新建 session 成功。
2. 发送 prompt 后 UI 进入 running。
3. Agent 回复后 UI 进入 completed。
4. 网络失败、模型失败、权限阻塞都有明确状态。
5. 切换 session 不会把上一轮迟到回复写到当前 session。
6. legacy server 仍可完成最小聊天闭环。
```

---

## 7. M23：文件、权限、问题、Todo、Diff 补齐

### 7.1 文件系统

当前 `FilePanel` 只是调用旧 `/file?path=/` 并展示一层路径。需要改成新版 FS：

```text
GET /api/fs/list?path=...
GET /api/fs/find?query=...&type=...
GET /api/fs/read/*
```

要实现：

```text
1. 树形目录。
2. 展开/折叠目录。
3. 文件搜索。
4. 文件内容读取。
5. 文件 tab 打开。
6. 文件内容缓存。
7. 二进制/图片文件识别。
8. ignored/protected 文件显示策略。
```

### 7.2 权限

当前权限主要是旧 `/permission`。新版要支持：

```text
GET /api/permission/request
GET /api/permission/saved
DELETE /api/permission/saved/:id
GET /api/session/:sessionID/permission
POST /api/session/:sessionID/permission/:requestID/reply
```

要实现：

```text
1. Pending permission dock。
2. once / always / reject。
3. saved permissions 列表。
4. 删除 saved permission。
5. 自动响应策略配置。
6. 权限请求和 session 绑定，避免跨 session 误处理。
```

### 7.3 Question

新版 question API：

```text
GET /api/question/request
GET /api/session/:sessionID/question
POST /api/session/:sessionID/question/:requestID/reply
POST /api/session/:sessionID/question/:requestID/reject
```

要实现：

```text
1. QuestionCard 从静态展示变成真实请求列表。
2. 支持多选 optionIDs。
3. 支持 reject。
4. 回复后更新 session run state。
```

### 7.4 Todo

上游桌面端有 session todo dock。当前项目有 `TodoListBlock`，但需要接入真实事件或 message parts。

要实现：

```text
1. 从 event/message 中提取 todo。
2. running 时自动打开 todo dock。
3. 全部 completed/cancelled 后延迟收起。
4. 过期 todo 不要在下一轮重新弹出。
```

### 7.5 Diff / Revert

当前 `DiffPanel` 能展示 diff，但需要补齐：

```text
1. 新版 API 下 diff 数据来源确认。
2. 文件 tab 内 review。
3. 单文件查看。
4. session/turn 级别回滚或 revert dock。
5. Snapshot 如果新版 server 无公开 /snapshot，需要降级为 git diff + revert 提示。
```

### 7.6 验收标准

```text
1. 文件树能浏览真实项目。
2. 搜索能返回真实文件。
3. 权限请求能阻塞 composer 并正确放行。
4. Question 能回复和拒绝。
5. Todo 随 agent 进度变化。
6. Diff 能定位到本轮变更。
```

---

## 8. M24：Composer、Tabs、Terminal、MCP、Connector 补齐

### 8.1 Composer

当前 Composer 主要是纯文本输入。需要补齐桌面端核心能力：

```text
1. 输入历史。
2. Slash command popover。
3. 文件引用。
4. 图片附件。
5. 粘贴图片/文件处理。
6. 拖拽覆盖层。
7. @ 文件搜索。
8. token/context 预估。
9. blocked 状态：有 permission/question 时不继续提交普通 prompt。
```

提交 payload 统一交给适配层构建，不在组件里拼 JSON。

### 8.2 Tabs / Draft

上游有 session tab、draft tab、terminal tab。当前 `SessionTabs` 比较简单。

需要实现：

```text
1. Session tab。
2. Draft tab：还没创建 session 但已有 prompt。
3. Terminal tab。
4. 关闭 tab。
5. 恢复最近 tab。
6. tab 与 server/workspace scope 绑定。
```

### 8.3 Terminal

当前 `PtyPanel` 假设 `/pty` 端点。需要重新对齐上游 terminal 能力：

```text
1. 确认新版 server 是否公开 PTY API。
2. 如果公开：接入真实 start/input/output/resize/close。
3. 如果不公开：通过本地 native ProcessBridge 实现 HarmonyOS 本地 terminal，但标明和 OpenCode server terminal 不同。
4. 多 terminal tab。
5. 标题同步。
6. 输出增量写入。
7. resize。
8. 断线重连。
```

### 8.4 MCP

当前 MCP 面板没有数据接入。需要按上游配置和 connector 体系拆开：

```text
1. Config MCP server 列表。
2. MCP server 启停状态。
3. MCP tool 列表。
4. tool enabled/disabled。
5. OAuth 型 MCP 的授权状态。
6. 错误日志和重连。
```

如果 server 没有公开 MCP API，则至少从 `/api/connector` 和 config 中展示真实状态，不再使用空数组。

### 8.5 Connector

新增 Connector 页面或整合进 Provider 页面：

```text
GET    /api/connector
GET    /api/connector/:connectorID
POST   /api/connector/:connectorID/connect/key
POST   /api/connector/:connectorID/connect/oauth
GET    /api/connector/oauth/:attemptID
POST   /api/connector/oauth/:attemptID/complete
DELETE /api/connector/oauth/:attemptID
```

要支持：

```text
1. API key connect。
2. OAuth begin/status/complete/cancel。
3. 连接状态展示。
4. 错误处理。
5. Provider 和 Connector 的关系展示。
```

### 8.6 验收标准

```text
1. Composer 支持文件引用和图片附件。
2. slash popover 显示 server command + local command。
3. draft session 可以创建、提交、转为真实 session。
4. Terminal 至少一种模式真实可用。
5. MCP 页面不再是空壳。
6. Connector key connect 和 OAuth 流程至少完成一个真实 provider 验证。
```

---

## 9. M25：Settings、Provider、Model、Keybinds、Runtime 管理收敛

### 9.1 Settings

当前 Settings 有很多静态状态。需要拆成真实配置：

```text
General:
  language
  theme
  font
  notifications
  sound
  layout flags

Models:
  server model list
  selected model
  small model
  unavailable model reason

Providers:
  provider list
  auth method
  API key
  custom provider
  generated config preview

Servers:
  local/dev-pc/remote
  active runner
  health
  logs
  saved servers

Keybinds:
  current keymap
  edit keybind
  conflict detection
  reset
```

### 9.2 Provider / Model

当前 Provider 配置偏国内 Provider Pack。上游 provider 能力更完整。

需要分层：

```text
1. Server runtime provider：从 /api/provider 读取。
2. Local custom provider：用户在 Harmony app 配置，还未写入 runtime。
3. Connector provider：通过 /api/connector 授权。
4. Generated config：生成 opencode 配置片段。
```

模型选择必须基于真实模型状态：

```text
1. 可用。
2. 未授权。
3. 不支持 tool。
4. 不支持 image。
5. 上下文限制。
6. 推荐 small model。
```

### 9.3 Runtime 管理

当前有：

```text
LocalOpenCodeServerManager
LocalOpenCodeRuntimeService
LocalRuntimeManager
```

需要收敛。

建议：

```text
1. 保留 LocalOpenCodeServerManager 作为唯一 Runtime manager。
2. 删除或弃用 LocalOpenCodeRuntimeService / LocalRuntimeManager 的启动职责。
3. RuntimePage、Index autoStart、ServerSettingsPage 都走同一个 manager。
4. manager 输出统一 RuntimeState。
```

RuntimeState：

```text
unknown
manual_required
extracting
starting
running
stopping
stopped
error
```

### 9.4 内置 binary 风险处理

当前内置 `rawfile/opencode` 是：

```text
ELF 64-bit LSB executable, ARM aarch64, dynamically linked,
interpreter /lib/ld-musl-aarch64.so.1
```

必须处理：

```text
1. HarmonyOS 是否存在 musl loader。
2. 缺 loader 时 UI 明确提示。
3. 支持用户配置外部 Runtime。
4. 不要把 fork 成功等同于 server 可用。
5. 启动后必须以 health 作为最终成功标准。
```

### 9.5 Keybinds

当前设置页明确写了 `editing keybinds is not yet implemented`。

要实现：

```text
1. keybind 数据模型。
2. 默认 keybind 列表。
3. 编辑弹窗。
4. 冲突检测。
5. 持久化。
6. 组件调用统一 keybinding service。
```

### 9.6 验收标准

```text
1. 设置项刷新后仍持久化。
2. Provider 连接状态来自真实 Runtime。
3. 模型切换会影响下一次 prompt。
4. Runtime 管理只有一个主服务。
5. Keybinds 可以编辑并生效。
```

---

## 10. M26：测试、文档、兼容矩阵

### 10.1 Smoke Matrix

新增并维护：

```text
docs/harmony-native/opencode-api-compatibility-matrix.md
```

矩阵字段：

```text
Feature
api-v2 endpoint
legacy endpoint
ArkTS method
UI entry
OpenCode.app 1.16.2 result
opencode-dev 2 result
Harmony device result
Status
Notes
```

### 10.2 必测工作流

```text
1. 启动 App，自动探测 server。
2. 连接 legacy server。
3. 连接 api-v2 server。
4. 新建 session。
5. 发送普通 prompt。
6. Agent 调用 read/grep/bash/edit。
7. 权限 once。
8. 权限 deny。
9. Question reply。
10. 文件树浏览。
11. 文件搜索。
12. Diff 展示。
13. Compact。
14. Provider API key 设置。
15. Model 切换。
16. MCP/Connector 状态展示。
17. Terminal 启动、输入、关闭。
18. Runtime 启动失败提示。
```

### 10.3 自动化测试

优先补：

```text
1. API normalize 单元测试。
2. capability detection 单元测试。
3. session run state 单元测试。
4. permission/question reducer 单元测试。
5. file tree transform 单元测试。
6. Provider config generate 单元测试。
```

ArkTS UI 自动化只覆盖主路径，不要试图一开始把所有 UI 都自动化。

### 10.4 文档更新

需要更新：

```text
README.md
docs/harmony-native/api-mapping.md
docs/harmony-native/smoke-test.md
docs/harmony-native/runtime-native-verification.md
docs/harmony-native/ui-parity-checklist.md
```

README 里不要再把未闭环功能标成完成。改成：

```text
Done
Partial
Unsupported on legacy server
Planned
```

---

## 11. 具体文件级修改清单

### 11.1 API 层

新增：

```text
entry/src/main/ets/services/OpenCodeApiAdapter.ets
entry/src/main/ets/services/OpenCodeApiV2.ets
entry/src/main/ets/services/OpenCodeApiLegacy.ets
entry/src/main/ets/services/OpenCodeCapabilities.ets
entry/src/main/ets/services/OpenCodeEventReducer.ets
entry/src/main/ets/models/OpenCodeApiModels.ets
```

改造：

```text
entry/src/main/ets/services/OpenCodeClient.ets
entry/src/main/ets/services/V2Client.ets
entry/src/main/ets/viewmodel/MainViewModel.ets
entry/src/main/ets/pages/Index.ets
```

目标：

```text
1. OpenCodeClient 降级为底层 HTTP helper 或拆成 legacy client。
2. MainViewModel 不直接拼 endpoint。
3. V2Client 不再假设所有 v2 功能都是 /snapshot、/pty、/plugin。
```

### 11.2 状态层

新增：

```text
entry/src/main/ets/model/SessionRunState.ets
entry/src/main/ets/model/WorkspaceState.ets
entry/src/main/ets/model/CapabilityState.ets
```

改造：

```text
entry/src/main/ets/model/AppState.ets
entry/src/main/ets/model/ChatMessage.ets
entry/src/main/ets/models/Event.ets
```

目标：

```text
1. session、message、permission、question、todo、tool event 都有统一状态。
2. UI 不再靠多个 boolean 判断复杂流程。
```

### 11.3 UI 面板

改造：

```text
entry/src/main/ets/components/ComposerBar.ets
entry/src/main/ets/components/AgentTranscript.ets
entry/src/main/ets/components/SessionTurn.ets
entry/src/main/ets/components/FilePanel.ets
entry/src/main/ets/components/MCPPanel.ets
entry/src/main/ets/components/PtyPanel.ets
entry/src/main/ets/components/CommandPanel.ets
entry/src/main/ets/components/SkillPanel.ets
entry/src/main/ets/components/SnapshotPanel.ets
entry/src/main/ets/components/QuestionCard.ets
entry/src/main/ets/components/TodoListBlock.ets
entry/src/main/ets/components/SessionTabs.ets
```

新增：

```text
entry/src/main/ets/components/composer/SlashCommandPopover.ets
entry/src/main/ets/components/composer/FileMentionPopover.ets
entry/src/main/ets/components/composer/AttachmentStrip.ets
entry/src/main/ets/components/session/PermissionDock.ets
entry/src/main/ets/components/session/QuestionDock.ets
entry/src/main/ets/components/session/TodoDock.ets
entry/src/main/ets/components/file/FileTree.ets
entry/src/main/ets/components/file/FileViewer.ets
entry/src/main/ets/components/connector/ConnectorPanel.ets
```

### 11.4 Settings / Provider

改造：

```text
entry/src/main/ets/pages/SettingsPage.ets
entry/src/main/ets/pages/ProviderPage.ets
entry/src/main/ets/pages/ModelPage.ets
entry/src/main/ets/services/ProviderConnectionService.ets
entry/src/main/ets/services/ProviderModelManager.ets
entry/src/main/ets/services/ModelSelectionService.ets
```

新增：

```text
entry/src/main/ets/services/ConnectorService.ets
entry/src/main/ets/services/KeybindService.ets
entry/src/main/ets/services/SettingsService.ets
```

### 11.5 Runtime

改造：

```text
entry/src/main/ets/services/LocalOpenCodeServerManager.ets
entry/src/main/ets/pages/RuntimePage.ets
entry/src/main/ets/pages/ServerSettingsPage.ets
entry/src/main/cpp/process_manager.cpp
entry/src/main/ets/services/ProcessBridge.ets
```

弃用或合并：

```text
entry/src/main/ets/services/LocalOpenCodeRuntimeService.ets
entry/src/main/ets/services/LocalRuntimeManager.ets
entry/src/main/ets/services/LocalProcessBridge.ets
```

---

## 12. 推荐实施顺序

### Step 1：冻结当前功能面

先做一份当前状态表：

```text
Feature | UI exists | API wired | Works on legacy | Works on api-v2 | Notes
```

不要再接受“看起来有面板”作为完成标准。

### Step 2：实现 capability detection

这是后续所有 UI 的基础。

完成后，状态栏要显示：

```text
OpenCode Server: api-v2 / legacy / unknown
```

### Step 3：迁移 Session API

先保证新版 server 能聊天。其他功能都依赖 session。

### Step 4：迁移 Message / Event / Permission / Question

保证 agent 跑起来后，阻塞、提问、工具调用都能正确驱动 UI。

### Step 5：迁移 File / Diff

让文件树、文件读取、Diff review 可用。

### Step 6：补 Composer

实现 slash popover、文件引用、附件、历史。

### Step 7：补 MCP / Connector / Provider

这些依赖 config、auth、connector、provider 状态，放在核心聊天闭环后面。

### Step 8：收敛 Runtime 服务

Runtime 影响启动体验，但不应该阻塞远程连接和 dev-pc 模式。所以在 API 主链路稳定后再收敛。

### Step 9：Settings / Keybinds / Polish

最后补设置、快捷键、通知、release notes、更新等桌面体验。

---

## 13. 风险和处理策略

### 风险 1：新版 API 仍在变化

处理：

```text
1. 适配层集中维护 endpoint。
2. 所有 API 方法有 capability fallback。
3. smoke matrix 标明测试版本和日期。
```

### 风险 2：HarmonyOS HTTP/SSE 能力不足

处理：

```text
1. SSE 优先。
2. 不稳定时用 event polling。
3. 轮询间隔按 running/idle 动态调整。
```

### 风险 3：内置 opencode binary 无法执行

处理：

```text
1. local mode 只是增强能力，不作为唯一使用路径。
2. dev-pc 和 remote mode 必须完整可用。
3. 启动失败时展示 loader、exit code、stderr。
```

### 风险 4：旧版和新版 API 差异过大

处理：

```text
1. UI 只调用 adapter。
2. adapter 根据 serverMode 分发。
3. legacy 缺失功能显示 unsupported。
```

### 风险 5：面板太多导致状态混乱

处理：

```text
1. 用 event reducer 集中更新状态。
2. 组件只读状态和发 action。
3. 禁止组件内部再维护一套 server truth。
```

---

## 14. 完成定义

本轮大改完成的定义不是“文件写完”，而是以下验收全部通过：

```text
1. 连接 opencode-dev 2，识别 api-v2。
2. 连接 OpenCode 1.16.2，识别 legacy。
3. api-v2 模式能完成创建 session、发送 prompt、等待回复。
4. 权限请求能 once / always / reject。
5. question 能 reply / reject。
6. 文件树能列目录、搜索、读文件。
7. Composer 支持 slash、文件引用、附件。
8. Provider、Model 从真实 server 状态读取。
9. MCP 或 Connector 不再是空壳；若 server 不支持，明确显示 unsupported。
10. Runtime 启动失败能给出明确诊断。
11. README 和 parity checklist 与真实状态一致。
12. smoke matrix 记录 legacy、api-v2、Harmony device 三类结果。
```

---

## 15. 第一批建议落地任务

如果要马上开始，建议第一批只做 8 个任务：

```text
1. 新增 OpenCodeCapabilities，完成 /api/health 与 /global/health 探测。
2. 新增 OpenCodeApiAdapter，先覆盖 health、session、message、provider、model。
3. 把 MainViewModel 的 session/chat 调用改走 adapter。
4. 支持新版 POST /api/session/:id/prompt 和 /api/session/:id/wait。
5. 把 listSessions normalize 成统一 SessionInfo[]。
6. 把 listMessages normalize 成统一 ChatMessage[]。
7. 状态栏显示 api-v2 / legacy / unknown。
8. 新增 smoke matrix 文档，记录两个参照物的实际结果。
```

第一批完成后，再进入文件、权限、question、composer。这样风险最低，也最容易确认方向正确。

---

## 16. 实施进度跟踪

### 已完成

| 里程碑 | 任务 | 状态 | Commit |
|--------|------|------|--------|
| M21 | OpenCodeCapabilities 能力探测 | ✅ | `c4835fe` |
| M21 | OpenCodeApiAdapter 统一适配器 | ✅ | `c4835fe` |
| M21 | MainViewModel 改走 adapter | ✅ | `c4835fe` |
| M21 | api-v2 prompt + wait 支持 | ✅ | `c4835fe` |
| M21 | 状态栏显示 server mode | ✅ | `c4835fe` |
| M21 | smoke matrix 文档 | ✅ | `c4835fe` |
| M22 | Turn alignment (activeTurnId) | ✅ | `5b170b7` |
| M22 | Send lock 防并发 | ✅ | `10e96dd` |
| M22 | Chat UI: error/tool/system/streaming/stop | ✅ | `103010f` |
| M23 | Adapter: permissions/questions/commands/skills/abort/events | ✅ | `cb55af5` |
| M23 | Permission dock (Allow/Always/Reject) | ✅ | `da22b09` |
| M23 | Question dock (Options + Reject) | ✅ | `dbcc9c4` |
| M24 | MCP/Command/Skill loading via adapter | ✅ | `16af14b` |
| M25 | stopGeneration via adapter | ✅ | `16af14b` |
| M25 | 删除死代码 LocalRuntimeManager | ✅ | `00fec6a` |

### 待完成

| 里程碑 | 任务 | 优先级 | 说明 |
|--------|------|--------|------|
| M23 | FilePanel 接入 adapter | 中 | 当前用 OpenCodeClient，可工作 |
| M23 | Todo 展示 | 低 | 需要 event stream 或 message parts |
| M23 | Diff 展示 | 低 | 需要确认新版 API 数据来源 |
| M24 | ComposerBar 改进 | 中 | 模型标签、slash popover、附件 |
| M24 | Terminal 接入 | 低 | 需要确认 PTY API |
| M24 | MCP 面板接入 | 低 | UI 壳已完成，需数据接入 |
| M25 | Runtime 服务收敛 | 低 | LocalOpenCodeRuntimeService 待迁移 |
| M25 | Settings 真实配置 | 低 | 当前多为静态状态 |
| M26 | 兼容矩阵完善 | 低 | smoke matrix 已有基础 |

### 关键架构决策

```text
1. 适配器优先：所有 API 调用走 OpenCodeApiAdapter，不直接用 HttpService
2. 新版优先：默认 api-v2，legacy 作为 fallback
3. 一个功能一条路径：收敛到 LocalOpenCodeServerManager + OpenCodeApiAdapter
4. 面板必须有数据来源：没有真实 API 的标记为 unsupported
```
