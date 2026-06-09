# M14 Agent 执行闭环验收清单

> 目标：让 OpenCode Harmony 不再只是「AI 回一句话」，而是真正能执行 OpenCode 编程任务，
> 并且把执行过程、错误、权限、diff 都可视、可干预。

## 0. 准备

- [ ] DevEco 编译通过（`hvigorw assembleHap` 或 IDE Build）
- [ ] 本地 opencode server 已启动（`opencode serve --port 4096` 或对应版本命令）
- [ ] App 内 Runtime 已连接（左侧 StatusPopover 显示 `connected vX.Y.Z`）
- [ ] 已经添加至少一个可用 Provider + Model
- [ ] 准备一个本地项目目录作为工作区

---

## 1. 基础发送回路

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 1.1 | 在 Composer 输入 `hi` 并发送 | Assistant 文本块出现在 Chat | Chat 内可见；无红色错误块 |
| 1.2 | 打开右侧 **Logs** 页签 | 看到完整链路 | 应有 `message.sending → model.active → message.beforeCount=N → prompt_async.sent=true → poll.result ok=true assistant=true tool=false ...` |
| 1.3 | 重复发送 3 次相同消息 | 每次都能成功 | Logs 中 `poll.result` 每次都 `ok=true` |

**Logs 关键行模板**（成功一次发消息的完整链路）：

```text
message.sending length=N
model.active xiaomi-mimo/mimo-v2.5-pro
message.beforeCount=3
prompt_async.sent=true beforeCount=3
poll.result ok=true assistant=true tool=false permission=false error=false count=5
diff.loaded 0 files (vcs)
```

---

## 2. 工具调用

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 2.1 | 发送「读取 README.md 并总结」 | Chat 中出现 `read`/`Read` 工具调用块；右侧 Tools 面板有时间线条目 | Tools 页签应自动切到（如果原本不在） |
| 2.2 | Tools 面板空态文案 | 未触发工具时显示「发送需要读写文件或运行命令的任务后，这里会显示 OpenCode 的工具调用。」 | 不是英文 "No tool calls yet" |
| 2.3 | 工具条目展开后 | 至少显示 工具名 / 状态 / 输入 / 输出（running 时不显示输出） | 对应 `ToolTimelineEntry.{toolName,status,input,output}` |
| 2.4 | 发送「修改 README.md 加一行说明」 | Chat 出现 `edit`/`Write` 工具块；Diff 面板有变更 | Diff 页签自动切到；显示文件名 + 行级 diff |

---

## 3. 错误路径（重点验证）

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 3.1 | 在 Provider 配置页填一个**故意错误**的 API Key | 保存成功 | 提示「API Key 已保存」 |
| 3.2 | 回到 Chat 发送任意任务 | 1) Chat 中出现**红色 Runtime Error 块** <br/> 2) 右侧 Logs 页签**自动打开** | 不需要手动点 Logs |
| 3.3 | Logs 关键行 | `poll.result ok=false error=true` + `message.error ...` | 错误文本同时出现在 Chat 与 Logs |
| 3.4 | 把 API Key 改回正确值再发送 | 正常回复；不再出现错误块 | 一次正常 + 一次错误 的对照 |

**预期错误块渲染**（AgentTranscript.ErrorBlock）：

```text
┌─── ! Runtime Error ───────────┐
│ provider "x" returned 401: ... │
└───────────────────────────────┘
```

- 红色边框
- 红色 标题 `Runtime Error`
- 错误正文（最多 6 行，溢出省略号）
- 背景 `Theme.DANGER_DIM`

---

## 4. 权限路径

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 4.1 | 在 Settings 中关闭「自动批准文件编辑」或类似开关 | 保存成功 | — |
| 4.2 | 发送「编辑 src/foo.ts 添加一行 export const X = 1」 | 1) Chat 出现 **Permission 卡片** <br/> 2) 卡片显示：风险条 + 类型 + 工具 + 描述 + `allow` / `always` / `deny` 三个按钮 | 卡片左侧颜色条按风险等级变色（红/黄/绿） |
| 4.3 | 点击 `allow once` | 1) 卡片状态变为 `approved` <br/> 2) Runtime 继续执行并完成编辑 | Tools + Diff 出现 `edit` 工具与文件变化 |
| 4.4 | 点击 `deny` | 1) 卡片状态变为 `rejected` <br/> 2) Runtime 收到拒绝信号（可能产生 tool-error） | Logs 出现 `permission.reply.deny` |

**会话权限回复**（OpenCodeClient.replySessionPermission）：

```text
POST /session/:id/permissions/:requestID/reply
body: { "reply": "once" | "always" | "deny" }
```

旧版全局 endpoint `/permission/:id/reply` 仍然保留作为 fallback。

---

## 5. Diff 路径

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 5.1 | 任务让 AI 改文件 | 1) Diff 面板出现文件 <br/> 2) 每行 +/- 着色 | `index.ets` `loadDiffs()` 调用到 `getSessionDiff` 或 fallback `getVcsDiff` |
| 5.2 | Logs 关键行 | `diff.loaded N files (session)` 优先；fallback 时 `diff.loaded N files (vcs)` | 第一次失败时还有一行 `session diff failed, falling back to vcs diff` |
| 5.3 | 多次发任务不改文件 | Diff 列表保持空 | `diff.loaded 0 files` |

---

## 6. 模型测试（testModel）

> Provider/Model 页面的「测试」按钮必须真正等到 assistant 回复才能返回结果。

| # | 操作 | 期望 | 验证方式 |
|---|---|---|---|
| 6.1 | 选一个**正确的**模型，点「测试」 | 提示 `模型测试成功：assistant returned — provider/model` | 30 秒内返回 |
| 6.2 | 改一个**错误**的 API Key，再测试 | 提示 `模型测试失败：Runtime error — <error>` | 30 秒内返回，不会卡死 |
| 6.3 | 关闭 Runtime 再测试 | 提示 `无法测试模型：本地 Runtime 未连接。...` | 立即返回 |
| 6.4 | 故意把 Provider 配置成无法路由的地址 | 提示 `模型测试超时：Runtime 没有返回 ...` | 30 秒后返回 |

---

## 7. 右侧页签自动聚焦

> 行为来自 `Index.sendMessage` 在 `waitForExecution` 之后设置 `rightPanelTab`。

| poll 结果 | 自动页签 | showRightPanel |
|---|---|---|
| `hasError = true` | `logs` | `true` |
| `hasPermission = true` | `logs` | `true` |
| `hasTool = true` | `diff`（如果有 diffs）否则 `tools` | `true` |
| `hasAssistant = true` | `diff`（如果有 diffs）否则 `tools` | 不强制改 |
| `ok = false && timedOut` | `logs` | `true` |

手动验证：跑完 1-5 步后观察右侧页签是否自动跳到对应位置。

---

## 8. 编译 / 静态检查

- [ ] `Index.ets` 通过编译（重点检查 `@Link rightPanelTab: string` 在 AppShell 调用处已经传 `$rightPanelTab`）
- [ ] `AgentTranscript.ets` 通过编译（`ErrorBlock` builder 已定义）
- [ ] `ToolTimelinePanel.ets` 引用 `Theme.DANGER_DIM` 等常量都存在
- [ ] `OpenCodeClient.replySessionPermission` 方法签名匹配 `Index.{approve,reject,alwaysApprove}Permission` 的调用
- [ ] `ModelSelectionService.testModel` 引入 `agentResponsePoller` 而不产生循环依赖

---

## 9. 不在 M14 范围

明确**不**做、留给后续阶段：

- M15：文件树、文件搜索、Diff viewer 增强、Tools 折叠展开
- M16：Runtime 启停 UI、opencode 路径管理、Server 文案清理
- M17：Provider 诊断按钮、模型测试页重构
- M18：首次启动引导
- M19：HAP 打包与签名
- M20：稳定性 / 性能压测

---

## 10. 已知限制

- v1.x opencode server 不一定实现 `/session/:id/permissions/:requestID/reply`，
  客户端会自动 fallback 到 `/permission/:id/reply`，UI 无差别。
- `getSessionDiff` 在 server 不支持时（HTTP 404/405）自动 fallback 到 `getVcsDiff`。
- 当 `lastAssistantMessageId` 还没更新时，`getSessionDiff` 会被跳过直接走 vcs diff，
  这是设计如此（避免空 messageID 导致 400）。
