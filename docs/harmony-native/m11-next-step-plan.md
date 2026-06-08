# OpenCode Harmony Native 下一步详细方案：M11 真机闭环验证与可演示版本

版本：v1.0  
日期：2026-06-08  
适用仓库：`phoenix0086/opencode-for-harmony`  
当前阶段判断：M9/M10 已完成，下一步进入 M11。

---

## 1. 当前状态判断

根据当前仓库 README，项目已经完成以下基础工作：

- 使用 ArkTS / ArkUI 构建鸿蒙原生 GUI。
- 通过 HTTP/SSE/OpenAPI Client 连接 OpenCode Server。
- 已经完成 M9：AppShell Wiring，即三栏 IDE 联调、真实页面接入、深色主题统一。
- 已经完成 M10：API 联调修复，即 OpenCodeClient 对齐真实 OpenAPI spec、normalize 层、13 项 endpoint 修正。

根据当前 smoke-test 文档，M10 已经审计并修正了 OpenCode Server API 的关键问题，包括：

- Provider 返回结构从 `data.providers` 修正为 `data.all`。
- Messages 从原始 `WithParts[]` 结构 normalize 成 UI 友好结构。
- sendMessage/sendMessageAsync 增加 `agent: "build"` 字段。
- replyPermission 从 `approve/reject` 修正为 `once/deny`。
- VCS 从 `/vcs/status` 与 `/vcs` 的职责重新区分。
- session diff 增加 required 的 `messageID`。
- doPost/doPatch/doDelete 都补齐 directory 参数。
- EventStreamClient 当前仍为轮询模式，不是真 SSE。

这说明现在项目已经从“界面搭建”和“接口猜测”阶段，进入“真实设备、真实 OpenCode Server、真实 Agent 流程验证”阶段。

---

## 2. M11 阶段目标

M11 的目标不是继续堆功能，而是把当前项目变成一个可以演示的最小可用版本。

一句话目标：

> 在 DevEco Studio / 鸿蒙设备上运行原生 App，连接真实 OpenCode Server，完成一次从创建 Session、发送 Prompt、接收 Agent 回复、展示工具调用、处理权限请求、查看 Diff 的端到端闭环。

M11 完成后，项目应该达到：

```text
1. App 可以编译运行。
2. App 可以连接真实 OpenCode Server。
3. App 可以创建或选择 Session。
4. App 可以发送 Prompt。
5. App 可以接收 Agent 结果。
6. App 可以展示工具调用，不重复。
7. App 可以处理 permission once/deny。
8. App 可以显示 VCS/Diff。
9. App 可以生成国内 Provider 配置。
10. 有完整 smoke-test 记录和问题清单。
```

---

## 3. 为什么下一步是 M11，而不是继续做新功能

当前项目最危险的地方不是 UI，也不是 Provider 数量，而是：

```text
代码看起来完成了，但没有完整真机闭环。
```

尤其是以下几个点必须实际验证：

1. ArkTS HTTP 模块是否真的支持当前请求方式。
2. `X-HTTP-Method-Override: PATCH` 是否被 OpenCode Server 正确处理。
3. 轮询式 EventStreamClient 是否能在真实 Agent 流程里稳定工作。
4. `permission/:id/reply` 的 `once/deny` 是否能真正推动 Agent 继续执行。
5. `WithParts[]` 里的 tool-invocation 字段是否和当前 normalize 逻辑完全一致。
6. session diff 的 `messageID` 应该取哪个 message。
7. OpenCode Server 的 directory 参数是否能正确绑定工作目录。
8. 鸿蒙 App 和本机/局域网 OpenCode Server 的网络访问是否稳定。

这些不验证，继续做美化、做 Provider、做文件树，都会建立在不确定基础上。

---

## 4. M11 工作范围

### 4.1 本阶段要做

M11 只做 8 件事：

1. DevEco 编译修复。
2. OpenCode Server 真实连接。
3. API smoke test 页面或调试日志。
4. Session 端到端流程。
5. Prompt 发送与结果展示。
6. Tool timeline 去重与状态稳定。
7. Permission once/deny 真实验证。
8. Diff/VCS 最小闭环。

### 4.2 本阶段不做

M11 不做：

```text
1. 不继续做全新 UI 风格。
2. 不增加复杂文件编辑器。
3. 不做插件市场。
4. 不做多 Agent 编排。
5. 不做内置 Runtime。
6. 不做 Linux 子系统自动化安装。
7. 不做企业账号。
8. 不做代码补全 IDE。
```

---

## 5. M11 详细任务拆解

## Task 1：DevEco 编译修复

### 目标

确保当前 ArkTS 工程可以在 DevEco Studio 中编译、运行到模拟器或真机。

### 操作

1. 用 DevEco Studio 打开项目。
2. 执行依赖同步。
3. 执行构建。
4. 修复所有 ArkTS 类型错误、import 错误、组件参数错误、权限配置错误。
5. 记录构建日志。

### 重点检查

```text
entry/src/main/ets/components/AppShell.ets
entry/src/main/ets/components/AgentTranscript.ets
entry/src/main/ets/components/ToolTimelinePanel.ets
entry/src/main/ets/components/DiffPanel.ets
entry/src/main/ets/components/FilePanel.ets
entry/src/main/ets/components/LogsPanel.ets
entry/src/main/ets/services/OpenCodeClient.ets
entry/src/main/ets/services/EventStreamClient.ets
entry/src/main/ets/models/Event.ets
```

### 验收标准

```text
1. DevEco 无阻塞编译错误。
2. App 能启动。
3. 不出现白屏。
4. AppShell 三栏布局能渲染。
5. 左侧 ActivityBar、SessionSidebar、TopStatusBar、ComposerBar 均显示。
```

---

## Task 2：准备真实 OpenCode 测试项目

### 目标

建立一个简单、可重复、适合 AI 修改的测试项目，避免直接拿复杂项目测试。

### 建议项目结构

```text
opencode-harmony-test-project/
├── package.json
├── src/
│   └── calculator.ts
├── test/
│   └── calculator.test.ts
└── README.md
```

### 示例任务

让 Agent 执行：

```text
请阅读这个项目，给 calculator.ts 增加 subtract(a,b) 和 multiply(a,b) 两个函数，并补充测试。
```

这个任务好处：

```text
1. 必然触发 read/search/edit。
2. 可能触发 bash/test。
3. Diff 简单。
4. 易判断结果是否正确。
```

### 验收标准

```text
1. OpenCode Server 可以在该项目目录启动。
2. App 能显示项目名。
3. VCS branch 能显示。
4. Agent 可以产生文件变更。
```

---

## Task 3：启动真实 OpenCode Server

### 目标

让鸿蒙 App 连接真实 OpenCode Server，而不是只看静态 UI。

### 命令

```bash
cd /path/to/opencode-harmony-test-project
opencode serve --port 4096 --hostname 0.0.0.0
```

### 建议同时记录

```bash
opencode --version
node --version
bun --version
git --version
pwd
```

### 网络注意

如果 App 在模拟器或真机上访问不到 `127.0.0.1`，改用局域网 IP，例如：

```text
http://192.168.x.x:4096
```

如果 OpenCode Server 设置了密码，需要确认 App 的 Runner.token 是否正确进入 Basic Auth。

### 验收标准

```text
1. 浏览器能打开 http://host:4096/global/health。
2. 浏览器能打开 http://host:4096/doc。
3. App health check 返回 connected。
4. TopStatusBar 显示 server URL 和 version。
5. LeftActivityBar 底部显示 online。
```

---

## Task 4：建立 API Smoke Test Matrix

### 目标

不要只靠 UI 点点看，要把每个关键 endpoint 都记录为“通过/失败/待确认”。

### 建议新建文件

```text
docs/harmony-native/m11-api-smoke-matrix.md
```

### 测试表

| 模块 | Endpoint | App 调用方法 | 预期结果 | 状态 | 备注 |
|---|---|---|---|---|---|
| Health | GET /global/health | health() | 返回 healthy/version | TODO |  |
| Config | GET /config | getConfig() | 返回 ConfigInfo | TODO |  |
| Provider | GET /provider | listProviders() | 返回 all/default/connected | TODO |  |
| Auth | PUT /auth/:id | setAuth() | 保存 API Key | TODO | 注意脱敏 |
| Project | GET /project/current | getCurrentProject() | 返回当前项目 | TODO |  |
| VCS | GET /vcs | getVcsInfo() | 返回 branch/default_branch | TODO |  |
| VCS Status | GET /vcs/status | getVcsStatus() | 返回文件状态 | TODO |  |
| Session | GET /session | listSessions() | 返回会话列表 | TODO |  |
| Session | POST /session | createSession() | 创建会话 | TODO |  |
| Message | GET /session/:id/message | getMessages() | 返回 normalize 后消息 | TODO |  |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | 204/200 | TODO |  |
| Permission | GET /permission | listPermissions() | 返回权限请求 | TODO |  |
| Permission | POST /permission/:id/reply | replyPermission() | once/deny 生效 | TODO |  |
| Diff | GET /session/:id/diff?messageID= | getSessionDiff() | 返回 FileDiff[] | TODO | messageID 必须非空 |
| Agent | GET /agent | listAgents() | 返回 agent 列表 | TODO |  |

### 验收标准

M11 结束时，每一行都必须是：

```text
PASS / FAIL / SKIP / BLOCKED
```

不能继续保留 TODO。

---

## Task 5：修正 session diff 的 messageID 策略

### 问题

当前 `getSessionDiff(sessionID, messageID)` 已经增加了 `messageID` 参数，但 UI 层需要明确“取哪个 messageID”。

### 推荐策略

```text
1. 当前选中的 assistant message 有 tool/edit/write，则优先取该 messageID。
2. 如果没有选中 message，则取最近一个 assistant messageID。
3. 如果没有 assistant message，则右侧 DiffPanel 显示 empty state：
   "No assistant message available for diff."
```

### 需要修改

```text
entry/src/main/ets/pages/Index.ets
entry/src/main/ets/components/DiffPanel.ets
entry/src/main/ets/models/Event.ets
```

### 验收标准

```text
1. 不再用空 messageID 调 diff。
2. 无 messageID 时不报错。
3. Agent 修改文件后，diff tab 能显示对应变更。
4. DiffPanel 空状态文案明确。
```

---

## Task 6：完善 EventStreamClient 轮询逻辑

### 当前情况

`EventStreamClient.ets` 目前不是 SSE，而是每 2 秒轮询 messages 和 permissions。这个方案可接受，但 M11 必须让它稳定。

### 现有风险

1. 首次轮询会记录已有 message，不触发事件；如果刚发 prompt 后首次轮询刚好发生，可能漏事件。
2. 只根据新 message ID 判断变化，可能无法捕捉同一 assistant message 的流式更新。
3. tool invocation 如果在同一 message 内状态变化，可能不会更新。
4. 没有 session run ended 的明确事件。
5. error 后仍继续轮询，但 UI 层可能不知道当前状态。

### 建议改法

增加一个 polling mode 状态：

```text
cold_start：首次进入历史会话，不触发历史事件
active_run：用户刚发送 prompt 后，所有 message 更新都应该触发 UI refresh
idle：普通轮询
error：连续失败超过阈值
```

### 推荐新增 API

```ts
markActiveRun(): void
markIdle(): void
setPollingInterval(ms: number): void
getStatus(): string
```

### 验收标准

```text
1. 用户发送 Prompt 后，不漏掉第一条 assistant message。
2. 同一 message 的 tool 状态变化能触发 loadMessages。
3. 连续错误 3 次后 logs panel 显示 warning。
4. Agent 完成后 isSending/isStreaming 能回到 false。
```

---

## Task 7：让 LogsPanel 成为真实调试工具

### 目标

LogsPanel 不只是展示文字，而是用来帮助判断联调问题。

### 需要记录的日志类型

```text
server.connecting
server.connected
server.error
session.created
session.selected
message.sending
message.sent
message.failed
poll.started
poll.message.updated
poll.permission.pending
tool.detected
permission.reply.once
permission.reply.deny
diff.loading
diff.loaded
diff.failed
```

### 日志字段

```text
timestamp
level: info/warn/error/debug
source: server/session/message/tool/permission/diff
message
metadata
```

### 验收标准

```text
1. 每次发送 Prompt，logs 能看到完整流程。
2. API 失败时 logs 能看到 endpoint 和 response code。
3. 不记录 API Key。
4. logs 可以清空。
```

---

## Task 8：Provider 配置真实验证

### 目标

Provider 页面不仅能生成配置，还要能真实保存/验证 API Key。

### 最小测试 Provider

M11 只需要真实验证 3 个：

```text
DeepSeek
Qwen / DashScope
GLM / BigModel
```

其他 Provider 可以保留配置，但标记为“待验证”。

### 需要测试

```text
1. Provider 列表是否从 /provider 正确加载。
2. API Key 是否通过 PUT /auth/:id 保存。
3. /provider 返回的 connected 是否更新。
4. 默认 model 是否能写入 config。
5. sendMessageAsync 是否使用选中的模型。
```

### 验收标准

```text
1. DeepSeek 可以配置并被 OpenCode 使用。
2. Qwen 可以配置并被 OpenCode 使用。
3. GLM 可以配置并被 OpenCode 使用。
4. 密钥不打印到 LogsPanel。
5. 配置保存失败时有明确错误提示。
```

---

## Task 9：权限审批真实验证

### 目标

确认 `replyPermission(requestID, "once")` 和 `replyPermission(requestID, "deny")` 真能推动或阻止 Agent。

### 测试 Prompt

```text
请运行 npm test，如果失败，请修改代码直到测试通过。
```

这个任务大概率触发 bash 权限。

### 验收标准

```text
1. App 显示 permission block。
2. 点击 allow 后调用 replyPermission(id, "once")。
3. Agent 继续执行。
4. 点击 deny 后调用 replyPermission(id, "deny")。
5. Agent 停止对应动作或给出无法继续的反馈。
6. LogsPanel 有完整记录。
```

---

## Task 10：准备演示脚本

### 目标

M11 结束时要能录屏演示，而不是只说“代码完成”。

### 演示流程

```text
1. 打开 OpenCode Harmony Native。
2. 显示 Server offline。
3. 启动 opencode serve。
4. App 连接成功，状态变 online。
5. 新建 session。
6. 输入任务：给 calculator 增加 subtract/multiply 并补测试。
7. Agent 开始执行。
8. 右侧 tools 显示 read/edit/bash 等工具调用。
9. 如果出现权限请求，点击 allow。
10. 切换 diff tab，查看文件变更。
11. 切换 logs tab，展示执行过程。
12. 结束任务。
```

### 产出文件

```text
docs/harmony-native/m11-demo-script.md
```

---

## 6. M11 代码修改建议

### 6.1 建议新增文件

```text
docs/harmony-native/m11-next-step-plan.md
docs/harmony-native/m11-api-smoke-matrix.md
docs/harmony-native/m11-demo-script.md
docs/harmony-native/m11-bug-list.md
```

### 6.2 建议修改文件

```text
README.md
docs/harmony-native/smoke-test.md
entry/src/main/ets/pages/Index.ets
entry/src/main/ets/services/EventStreamClient.ets
entry/src/main/ets/services/OpenCodeClient.ets
entry/src/main/ets/components/LogsPanel.ets
entry/src/main/ets/components/DiffPanel.ets
entry/src/main/ets/components/ProviderPage.ets
entry/src/main/ets/models/Event.ets
```

---

## 7. M11 验收标准

M11 完成必须满足：

```text
1. DevEco 编译通过。
2. AppShell 三栏布局正常显示。
3. 能连接真实 OpenCode Server。
4. 能显示 project、branch、server version。
5. 能创建 session。
6. 能发送 prompt。
7. 能看到 assistant message。
8. 能看到 tool timeline，且不重复。
9. 能处理 permission once/deny。
10. 能显示 diff 或明确空状态。
11. Provider 页面能保存至少一个国内模型 API Key。
12. LogsPanel 能记录核心流程。
13. m11-api-smoke-matrix.md 填写真实结果。
14. m11-demo-script.md 可以照着录屏。
```

---

## 8. 给 AI 编程工具的下一步总控提示词

把下面这段直接丢给 Codex / OpenCode / Claude Code：

```text
当前项目 OpenCode Harmony Native 已完成 M9/M10：
- M9: AppShell 三栏 IDE 布局，Provider/Settings/File/Diff/Logs 接入
- M10: OpenCodeClient 对齐 OpenCode v1.16.2 API，normalize 层和 13 项 endpoint 修复

现在进入 M11：真机闭环验证与可演示版本。

不要继续重做 UI，不要新增大功能。目标是让现有 ArkUI 原生 App 连接真实 OpenCode Server，跑通一次完整 Agent 编程流程。

请执行以下任务：

1. 用 DevEco Studio 构建项目，修复所有 ArkTS 编译错误。
2. 启动真实 OpenCode Server：
   opencode serve --port 4096 --hostname 0.0.0.0
3. 新建测试项目 opencode-harmony-test-project，用 calculator.ts 做最小任务。
4. 验证 health/config/provider/auth/project/vcs/session/message/permission/diff/agent 等 endpoint。
5. 新增 docs/harmony-native/m11-api-smoke-matrix.md，记录每个 endpoint 的 PASS/FAIL/SKIP/BLOCKED。
6. 修正 session diff 的 messageID 策略，不能用空 messageID 请求 diff。
7. 优化 EventStreamClient 轮询逻辑，增加 active_run 状态，避免漏掉发送 prompt 后的第一条 assistant message。
8. 让 LogsPanel 记录 server/session/message/tool/permission/diff 的关键事件。
9. 真实验证 permission once/deny。
10. Provider 页面至少真实验证 DeepSeek/Qwen/GLM 之一。
11. 新增 docs/harmony-native/m11-demo-script.md，写出演示流程。
12. 更新 README，增加 M11 状态。

验收标准：
- DevEco 编译通过
- App 能连接真实 OpenCode Server
- 能新建 session
- 能发送 prompt
- 能收到 assistant message
- tools tab 显示工具调用且不重复
- permission allow/deny 生效
- diff tab 有结果或清晰空状态
- logs tab 能追踪完整流程
- smoke matrix 有真实结果
```

---

## 9. 风险和处理策略

### 风险 1：ArkTS HTTP 不支持 PATCH

当前代码用 `X-HTTP-Method-Override: PATCH`。如果 OpenCode Server 不识别，需要：

```text
方案 A：在 OpenCode Server 侧支持 method override。
方案 B：ArkTS 侧寻找 PATCH 支持方式。
方案 C：暂时跳过 config/session patch，只保留 get/post/put/delete 流程。
```

### 风险 2：轮询无法模拟 SSE 流式体验

M11 可接受轮询，但要承认限制：

```text
1. 不是 token 级流式。
2. 只能 message 级更新。
3. 工具状态可能滞后。
```

M12 再做真正 SSE 或 native event client。

### 风险 3：Permission API 字段不完全一致

以真实 OpenCode `/doc` 和实际返回为准，必要时在 LogsPanel 输出脱敏 raw event。

### 风险 4：Diff messageID 不好选

先采用“最近 assistant message”策略，后续在 UI 中支持选择 message 查看 diff。

### 风险 5：Provider Auth 成功但模型不可用

Provider Auth 只代表 key 保存成功，不代表模型可调用。M11 要增加“发送最小 prompt 测试模型”的步骤。

---

## 10. M12 预告

M11 完成后，M12 才开始做：

```text
1. 真 SSE 替换轮询。
2. 文件树真实浏览和文件内容预览。
3. Provider 模型测试按钮。
4. RuntimeManager 自动启动本地 OpenCode Server。
5. 打包安装体验。
6. 演示视频和 README 截图。
```

M11 不要提前做 M12。
