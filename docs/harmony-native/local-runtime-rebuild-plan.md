# HarmonyOS 本机 Runtime 重构方案

## 1. 背景和结论

当前 App 的“本机模式”会尝试从 `entry/src/main/resources/rawfile/opencode` 解压一个内置二进制到应用 `filesDir`，然后通过 native `ProcessBridge` 执行：

```bash
opencode serve --port 4096 --hostname 127.0.0.1
```

实测该内置文件是 Linux/musl ARM64 ELF：

```text
ELF 64-bit LSB executable, ARM aarch64, dynamically linked,
interpreter /lib/ld-musl-aarch64.so.1
```

这意味着它不是 HarmonyOS 原生 Runtime。设备上如果没有 `/lib/ld-musl-aarch64.so.1` 或不允许这种 ELF 运行，进程会 fork 成功但 exec 立即失败，UI 就会显示 `Start Failed` 或 `Runtime 进程已退出，启动失败`。

核心结论：

- 连接地址 `http://127.0.0.1:4096` 没错。
- 当前失败不是网络连接问题，而是本机 Runtime 二进制不能在 HarmonyOS 环境稳定执行。
- 如果没有官方可用的 HarmonyOS `opencode serve` 二进制，不能继续依赖“随包塞一个 Linux 版 opencode”作为主线。
- 应该重构一个 HarmonyOS 本机 Runtime，至少实现 App 当前需要的 OpenCode Server API 子集。

## 2. 目标

重构后的本机 Runtime 要满足：

1. App 不依赖外部电脑或局域网服务器。
2. 用户在设置里选择“本机模式”后，App 能直接启动或绑定本机 Runtime。
3. Provider、Model、Session、Prompt、Message、Permission、Diff 等基础能力可用。
4. Runtime 和 UI 使用同一套 Provider 配置，不再出现“Provider 参数没了、大模型没了”的状态断裂。
5. Runtime 错误、模型错误、工具调用错误能进入统一日志，不再只显示 `Start Failed`。

非目标：

- 第一阶段不追求完整复刻 upstream OpenCode 的全部能力。
- 第一阶段不实现插件市场、远程 workspace、完整 PTY、多端同步、自动升级。
- 第一阶段不继续尝试把 Linux/musl Bun 单文件二进制硬塞进 HarmonyOS 当最终方案。

## 3. 推荐路线

推荐采用三阶段路线：

| 阶段 | 名称 | 目标 | 结果 |
|---|---|---|---|
| P0 | 诊断和止血 | 明确显示本机 Runtime 为什么启动失败 | 用户知道是二进制不兼容，不再误判为 URL 错 |
| P1 | 嵌入式 ArkTS Runtime | 在 App 内实现最小可用 Runtime API | 本机聊天、Provider、Model、Session 可用 |
| P2 | Native/Service 化 Runtime | 把 Runtime 从页面状态拆出来，形成稳定后台服务 | 长会话、工具执行、文件操作、权限流稳定 |
| P3 | upstream 对齐 | 按 OpenCode api-v2 补齐高级能力 | 接近桌面 OpenCode 体验 |

当前已经完成一部分 P0：失败时收集 native stderr，并提示 `Linux/musl ELF`、`/lib/ld-musl-aarch64.so.1`、HarmonyOS 二进制不兼容等信息。

## 4. 方案选择

### 方案 A：继续内置 Linux/musl opencode

做法：

- 随包携带 `/lib/ld-musl-aarch64.so.1` 和缺失的动态库。
- 尝试 patch ELF interpreter 到应用私有目录。
- 继续通过 `ProcessBridge` fork/exec 启动。

问题：

- 当前 ELF interpreter 是绝对路径 `/lib/ld-musl-aarch64.so.1`，应用私有目录里的 loader 不会被自动使用。
- 即使用 `patchelf` 改 interpreter，也要验证 HarmonyOS 是否允许从应用目录执行该 loader。
- Bun/OpenCode 运行时依赖复杂，沙箱、证书、网络、文件权限、子进程能力都可能继续踩坑。
- 这条线维护成本高，不适合作为产品主线。

结论：

- 只保留为实验方案。
- 不建议继续投入为主线。

### 方案 B：编译 HarmonyOS 原生 opencode

做法：

- 把 upstream OpenCode 及其 Bun/Node 依赖编译成 HarmonyOS 可执行文件。
- 继续保留 `opencode serve` 进程模型。

问题：

- OpenCode 当前强依赖 JS runtime、Node/Bun 生态、文件系统、子进程、PTY、插件加载。
- HarmonyOS NDK 能编译 C/C++，但不能直接保证 Bun/Node 生态完整可用。
- 编译链路很长，风险主要在 runtime 和 npm 包兼容性，而不是 OpenCode TypeScript 本身。

结论：

- 如果未来官方提供 HarmonyOS/ohos 目标，可以切回这个方案。
- 当前不应把项目进度押在这条线上。

### 方案 C：重构一个 HarmonyOS 本机 Runtime

做法：

- 不再把 upstream `opencode serve` 当必需进程。
- 在 HarmonyOS App 内实现一个 `LocalRuntimeService`。
- 对 UI 暴露与 OpenCode Server 类似的 API adapter。
- Provider 调用直接走 ArkTS HTTP 客户端。
- Session、Message、Config、Provider 存储走本地 storage/database。
- 文件和工具能力按 HarmonyOS 权限模型重做。

优点：

- 能真正实现“本机可用”。
- 不依赖 Linux ELF、Bun、Node、musl loader。
- 可以先实现 App 需要的 API 子集，再逐步对齐 upstream。
- Provider 配置和 UI 在同一应用内，状态一致性更好。

缺点：

- 需要重写 Runtime 核心逻辑。
- 上游新能力不能直接复用，需要映射和取舍。

结论：

- 这是推荐主线。

## 5. 目标架构

重构后建议分成四层：

```text
UI Pages / ViewModels
        |
        v
OpenCodeApiAdapter
        |
        +-----------------------------+
        |                             |
        v                             v
RemoteOpenCodeClient          LocalRuntimeClient
(连接电脑/远程 opencode)       (本机 Runtime facade)
                                      |
                                      v
                           LocalRuntimeService
                                      |
          +-------------+-------------+-------------+
          |             |             |             |
          v             v             v             v
 ProviderEngine   SessionStore   ToolEngine   PermissionEngine
```

关键点：

- UI 不直接关心当前是 remote 还是 local。
- `OpenCodeApiAdapter` 根据设置切换后端。
- 远程模式继续调用真实 `opencode serve`。
- 本机模式调用 `LocalRuntimeClient`，它在进程内模拟需要的 server API。
- 本机 Runtime 不一定真的开 HTTP 端口；除非 WebView 或调试需要，优先走进程内方法调用。

## 6. 模块拆分

### 6.1 RuntimeMode

新增统一运行模式：

```typescript
type RuntimeMode = 'local-embedded' | 'dev-pc' | 'remote'
```

含义：

- `local-embedded`：真正本机 Runtime，不 fork Linux opencode。
- `dev-pc`：开发电脑/局域网模式，连接电脑上的 `opencode serve`。
- `remote`：连接远程服务器。

需要把现有 `local` 改名或迁移为 `local-embedded`，避免继续让人误解为“启动 rawfile/opencode”。

### 6.2 LocalRuntimeService

新增核心服务，职责：

- 管理 Runtime 生命周期。
- 初始化 Provider 配置。
- 初始化默认 Session。
- 维护当前 workspace。
- 提供 health、config、provider、session、message、prompt 等方法。

建议接口：

```typescript
class LocalRuntimeService {
  start(config: LocalRuntimeConfig): Promise<RuntimeHealth>
  stop(): Promise<void>
  health(): Promise<RuntimeHealth>
  getConfig(): Promise<RuntimeConfig>
  updateConfig(patch: RuntimeConfigPatch): Promise<RuntimeConfig>
  listProviders(): Promise<ProviderList>
  setProviderAuth(providerID: string, auth: ProviderAuth): Promise<boolean>
  listSessions(): Promise<SessionInfo[]>
  createSession(input: CreateSessionInput): Promise<SessionInfo>
  listMessages(sessionID: string): Promise<MessageInfo[]>
  sendPrompt(sessionID: string, input: PromptInput): Promise<PromptResult>
}
```

### 6.3 LocalRuntimeClient

新增一个本地 client，让 `OpenCodeApiAdapter` 可以像调用 HTTP client 一样调用本机服务。

职责：

- 把 App 当前使用的 OpenCode API 转成 `LocalRuntimeService` 方法。
- 兼容 v1/v2 响应格式。
- 统一错误结构，比如 `InvalidRequestError`、`ProviderAuthError`、`ModelNotFoundError`。

这样可以避免 UI 层到处写：

```typescript
if (local) {
  ...
} else {
  ...
}
```

### 6.4 ProviderEngine

本机 Runtime 最核心的是 Provider 调用能力。

第一阶段只做 OpenAI-compatible 协议，覆盖：

- OpenAI
- DeepSeek
- Moonshot/Kimi
- OpenRouter
- SiliconFlow
- 阿里 DashScope 的 OpenAI-compatible 路径
- 其它自定义 baseURL + API Key 的 provider

Provider 配置字段：

```typescript
interface LocalProviderConfig {
  id: string
  name: string
  enabled: boolean
  protocol: 'openai-compatible' | 'anthropic' | 'custom'
  baseURL: string
  apiKey: string
  apiKeyEnv?: string
  headers?: Record<string, string>
  models: LocalModelConfig[]
}
```

Model 配置字段：

```typescript
interface LocalModelConfig {
  id: string
  name: string
  contextLength?: number
  maxOutputTokens?: number
  supportsTools?: boolean
  supportsReasoning?: boolean
  supportsVision?: boolean
}
```

第一阶段的 chat completions 请求：

```http
POST {baseURL}/chat/completions
Authorization: Bearer {apiKey}
Content-Type: application/json
```

请求体：

```json
{
  "model": "model-id",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "stream": true
}
```

流式返回先支持 OpenAI SSE：

```text
data: {"choices":[{"delta":{"content":"..."}}]}
data: [DONE]
```

### 6.5 SessionStore

本机 Runtime 需要自己保存会话。

建议数据表/存储对象：

- `sessions`
- `messages`
- `message_parts`
- `tool_calls`
- `permissions`
- `runtime_config`
- `providers`
- `models`

最小字段：

```typescript
interface LocalSession {
  id: string
  title: string
  workspace: string
  providerID: string
  modelID: string
  createdAt: number
  updatedAt: number
}

interface LocalMessage {
  id: string
  sessionID: string
  role: 'user' | 'assistant' | 'system' | 'tool' | 'error'
  content: string
  status: 'pending' | 'streaming' | 'completed' | 'error' | 'aborted'
  createdAt: number
  updatedAt: number
  error?: string
}
```

第一阶段可以继续用当前 `StorageService`，但要加版本号和迁移逻辑。第二阶段建议切数据库，避免消息多了以后 JSON storage 卡顿。

### 6.6 Prompt 执行引擎

Prompt 执行流程：

1. 校验 session 存在。
2. 写入 user message。
3. 创建 assistant message，状态为 `streaming`。
4. 从 session 历史构造 provider messages。
5. 调用 `ProviderEngine.streamChat()`。
6. 每收到一个 delta，追加到 assistant message。
7. 发送 Runtime event 给 UI。
8. 完成后 assistant message 状态改为 `completed`。
9. 出错时状态改为 `error`，错误进入 message 和 logs。

本机模式下 `sendPrompt()` 不能再发 `{ prompt: "hi" }` 这种旧 payload，内部统一用对象：

```typescript
interface PromptInput {
  prompt: {
    text: string
  }
  model?: {
    providerID: string
    id: string
    variant?: string
  }
}
```

### 6.7 EventBus

本机 Runtime 需要事件流，否则 UI 只能轮询。

事件类型先实现：

```typescript
type RuntimeEvent =
  | { type: 'session.created', session: LocalSession }
  | { type: 'message.created', message: LocalMessage }
  | { type: 'message.updated', message: LocalMessage }
  | { type: 'message.completed', message: LocalMessage }
  | { type: 'message.error', message: LocalMessage, error: string }
  | { type: 'provider.updated', providerID: string }
  | { type: 'runtime.error', error: string }
```

远程模式继续走 SSE；本机模式可以走内存 event bus。

### 6.8 ToolEngine

工具能力不要第一天就完整复制 upstream。建议分三批：

第一批：

- read file
- list directory
- search text
- get workspace status

第二批：

- edit file
- apply patch
- shell command

第三批：

- terminal/PTY
- LSP
- git 高级操作
- plugin tool

所有写操作必须经过 `PermissionEngine`。

### 6.9 PermissionEngine

本机 Runtime 必须有权限层，因为模型会修改用户文件。

权限对象：

```typescript
interface PermissionRequest {
  id: string
  sessionID: string
  toolName: string
  summary: string
  payload: Record<string, Object>
  status: 'pending' | 'approved' | 'denied' | 'expired'
  createdAt: number
}
```

执行流程：

1. ToolEngine 请求危险操作。
2. PermissionEngine 创建 pending request。
3. UI 显示允许/拒绝。
4. 用户确认后继续执行。
5. 结果写回 tool message。

第一阶段可以只支持读操作，写操作全部拒绝并提示“本机 Runtime 写文件能力未启用”。

## 7. API 兼容清单

第一阶段必须实现：

| API | 本机实现 | 用途 |
|---|---|---|
| `GET /global/health` | `LocalRuntimeService.health()` | 连接状态 |
| `GET /global/config` | `getConfig()` | 设置读取 |
| `PATCH /global/config` | `updateConfig()` | 设置保存 |
| `GET /provider` | `listProviders()` | Provider/Model 页面 |
| `PUT /auth/:providerID` | `setProviderAuth()` | 保存 API Key |
| `DELETE /auth/:providerID` | `removeProviderAuth()` | 删除 API Key |
| `GET /session` | `listSessions()` | 会话列表 |
| `POST /session` | `createSession()` | 新建会话 |
| `GET /session/:id/message` | `listMessages()` | 聊天记录 |
| `POST /session/:id/prompt_async` | `sendPrompt()` | 发送消息 |

第二阶段实现：

| API | 本机实现 | 用途 |
|---|---|---|
| `POST /session/:id/abort` | `abortPrompt()` | 停止生成 |
| `GET /session/:id/diff` | `getDiff()` | 文件变更 |
| `GET /event` | event bus adapter | 实时刷新 |
| `GET /file` | `readFile()` | 文件查看 |
| `POST /permission/:id/respond` | `respondPermission()` | 工具审批 |

第三阶段实现：

| API | 本机实现 | 用途 |
|---|---|---|
| `/pty/*` | native PTY 或降级 shell | 终端 |
| `/snapshot/*` | session snapshot store | 快照 |
| `/session/:id/compact` | context compaction | 压缩上下文 |
| `/session/:id/share` | 暂不支持或远程分享 | 分享 |
| `/plugin/*` | 本机 plugin registry | 插件 |

## 8. 现有代码修改点

### 8.1 `LocalOpenCodeServerManager`

保留 dev-pc/remote 管理能力，但不要把它作为本机 Runtime 主实现。

修改建议：

- 将当前 fork rawfile 的逻辑标记为 `experimentalSidecar`。
- 默认本机模式不再调用 `startServerProcess()`。
- 增加 `LocalRuntimeService.start()` 路径。
- UI 文案从“启动内置 Runtime”改成“启动本机 Runtime”。
- 如果用户启用 sidecar 实验模式，再显示 Linux/musl 兼容性警告。

### 8.2 `OpenCodeApiAdapter`

改成三路 adapter：

```typescript
class OpenCodeApiAdapter {
  private remoteClient: OpenCodeApiClient
  private localClient: LocalRuntimeClient

  async health() {
    return this.isLocalEmbedded()
      ? this.localClient.health()
      : this.remoteClient.health()
  }
}
```

所有 ViewModel 只能调 Adapter，不能直接调 `HttpService`、`OpenCodeApiClient`、`V2Client`。

### 8.3 `MainViewModel`

修改点：

- `connect()` 根据 Runtime mode 初始化 adapter。
- `autoStartAndConnect()` 本机模式走 `LocalRuntimeService.start()`。
- Provider 加载、Model 同步、Session 创建都走 adapter。
- 去掉本机模式下对 `127.0.0.1:4096` health 的强依赖。

### 8.4 `ProviderRegistry`

Provider 配置要变成 Runtime 单一事实源。

修改点：

- 默认 Provider 模板继续保留。
- 保存 API Key 后同步到 `LocalRuntimeService`。
- 本机模式下 `GET /provider` 返回 registry 里的 enabled providers。
- Model 页面从同一个 registry 读，不再依赖远程 server 返回。

### 8.5 Settings 页面

修改点：

- Server 页面增加三种清晰模式：
  - 本机 Runtime
  - 开发电脑/局域网
  - 远程服务器
- 本机 Runtime 页面不要求用户填 URL。
- URL 字段只在 dev-pc/remote 显示。
- 本机 Runtime 状态显示：
  - `未启动`
  - `启动中`
  - `运行中`
  - `模型配置缺失`
  - `Provider 认证失败`
  - `Runtime 内部错误`
- 保留“高级：尝试 sidecar opencode”开关，默认关闭。

## 9. 数据迁移

现有用户数据主要有：

- server config
- provider config
- model selection
- sessions/messages

迁移策略：

1. 读取旧 `LocalServerConfig.mode`。
2. 如果是 `local`，迁移为 `local-embedded`。
3. 如果旧配置里 host 是 `127.0.0.1`，不要再把它显示为必须连接的 URL。
4. Provider 旧配置迁移到 `LocalProviderConfig`。
5. 默认模型从 `provider/model` 字符串拆成：

```typescript
{
  providerID: 'provider',
  id: 'model'
}
```

6. 如果拆分失败，清空默认模型并提示用户重新选择。

## 10. 实施步骤

### Step 1：固定运行模式和 adapter 边界

交付：

- 新增 `RuntimeMode`。
- 新增 `LocalRuntimeClient` 空实现。
- `OpenCodeApiAdapter` 支持 local/remote 分流。
- UI 不再直接用 `HttpService` 读取 Provider/Session。

验收：

- dev-pc/remote 连接能力不退化。
- 本机模式不再尝试连接 `127.0.0.1:4096`。
- 点击本机模式显示 `LocalRuntimeService not implemented` 或最小 health，而不是 `Start Failed`。

### Step 2：实现本机 health/config/provider/model

交付：

- `LocalRuntimeService.health()`。
- `getConfig/updateConfig()`。
- `listProviders()`。
- `setProviderAuth/removeProviderAuth()`。
- Provider 和 Model 页面恢复显示。

验收：

- 不启动外部 server，也能在 Provider 页面看到默认供应商。
- 保存 API Key 后刷新不丢。
- Model 页面能按 Provider 分组显示模型。

### Step 3：实现本机会话和消息存储

交付：

- `listSessions/createSession/deleteSession`。
- `listMessages`。
- 本机 session/message 存储。
- 新建 session 后 UI 能切换。

验收：

- 断网状态下可以新建本机会话。
- 重启 App 后会话还在。
- 当前模型和会话绑定正确。

### Step 4：实现 OpenAI-compatible 流式模型调用

交付：

- `ProviderEngine.streamChat()`。
- OpenAI-compatible SSE parser。
- `sendPrompt()`。
- assistant message 流式更新。
- 错误写入 message。

验收：

- 配置 DeepSeek/OpenAI-compatible 后，本机模式能发送 `hi` 并收到回复。
- 模型 API Key 错误时显示明确错误。
- Prompt payload 不再出现 `Expected object, got "hi"`。

### Step 5：实现 abort 和事件流

交付：

- 每次生成有 `AbortController` 或等价取消令牌。
- `abortSession()` 能停止当前请求。
- 本机 event bus 推送 message delta。

验收：

- 生成中点击停止，网络请求取消。
- UI 不需要完整轮询也能刷新消息。

### Step 6：实现最小工具能力

交付：

- read file
- list directory
- search text
- workspace summary
- tool message 展示

验收：

- 模型可以读取当前 workspace 的文件。
- 读文件错误能返回给模型和 UI。
- 超出 workspace 的路径被拒绝。

### Step 7：实现权限和写文件

交付：

- PermissionEngine。
- apply patch/edit file。
- 用户审批弹窗。
- diff 展示。

验收：

- 模型写文件前必须弹审批。
- 拒绝后不会修改文件。
- 批准后写入文件，并能在 Diff 页面看到变化。

### Step 8：清理 sidecar 旧路径

交付：

- `rawfile/opencode` 从默认包移除，或移动到 experimental 资源。
- `LocalOpenCodeServerManager.startServerProcess()` 只服务 sidecar 实验模式。
- 文档明确 sidecar 不是默认本机 Runtime。

验收：

- 普通用户不会再遇到 Linux/musl ELF 的 `Start Failed`。
- 本机模式默认可用。

## 11. 风险和处理

| 风险 | 影响 | 处理 |
|---|---|---|
| ArkTS HTTP streaming 支持不足 | 不能流式显示回复 | 第一版退化为非流式，第二版用 native HTTP 或 WebSocket bridge |
| Provider 协议差异 | 部分模型不可用 | 第一阶段只支持 OpenAI-compatible，Anthropic 等后续补 |
| 本地存储性能不足 | 长会话卡顿 | 第二阶段迁移数据库 |
| 文件权限受限 | 工具能力不可用 | 明确 workspace 选择和授权边界 |
| 上游 API 变化 | adapter 失配 | adapter 层做兼容，UI 不直接依赖具体 endpoint |
| 工具写文件风险 | 用户文件被误改 | 写操作全部走 PermissionEngine |

## 12. 验收矩阵

### 本机 Runtime 基础

- App 首次启动默认进入本机 Runtime。
- 不填 URL 也能显示 Runtime `running`。
- Provider 页面有默认供应商。
- Model 页面有默认模型。
- 保存 Provider API Key 后重启不丢。

### 聊天

- 新建 session 成功。
- 发送普通文本成功。
- assistant 回复能显示。
- 网络错误能显示具体 provider 错误。
- API Key 错误能提示认证失败。
- 模型不存在能提示模型配置错误。

### 状态一致性

- Settings 选择的默认模型就是 Chat 使用的模型。
- Provider 禁用后不会出现在模型选择里。
- 切换模型后新消息使用新模型。

### 兼容远程

- dev-pc 模式仍能连接电脑上的 `opencode serve`。
- remote 模式仍能连接远程服务器。
- local/remote 切换后不会串用旧 URL。

## 13. 推荐任务拆分

建议按以下 PR/任务拆：

1. `runtime-mode-adapter-boundary`
   - 新 RuntimeMode。
   - Adapter 分流。
   - UI 模式文案调整。

2. `local-runtime-provider-config`
   - LocalRuntimeService skeleton。
   - Provider/Model 本地读取和保存。

3. `local-runtime-session-store`
   - 本机会话和消息存储。

4. `local-runtime-openai-compatible-chat`
   - OpenAI-compatible 调用。
   - Prompt 执行。
   - 错误处理。

5. `local-runtime-events-abort`
   - Event bus。
   - Abort。

6. `local-runtime-tools-readonly`
   - 只读工具。

7. `local-runtime-permission-write-tools`
   - 权限审批。
   - 写文件和 diff。

8. `sidecar-experimental-cleanup`
   - sidecar 降级为实验功能。
   - 移除默认 Linux/musl 依赖。

## 14. 最终建议

不要再把“启动不了”当成连接 bug 修。当前本机模式失败的根因是 Runtime 形态错了：App 需要的是 HarmonyOS 本机 Runtime，而不是 Linux/musl `opencode serve`。

最稳妥的路线是：

1. 保留远程 `opencode serve` 作为兼容模式。
2. 把本机模式重构为进程内 `LocalRuntimeService`。
3. 第一阶段只实现 Provider、Model、Session、Prompt、Message。
4. 第二阶段再加事件、abort、只读工具。
5. 第三阶段再加写文件、权限、diff、PTY、插件。

这样可以最快让"我要用本机"可用，同时避免继续被二进制兼容性卡住。

---

## 15. 实施进度

| Step | 任务 | 状态 | 说明 |
|------|------|------|------|
| 1 | RuntimeMode + Adapter 分流 | ✅ | `local-embedded` / `dev-pc` / `remote` 三路分流 |
| 2 | Provider/Model 本地管理 | ✅ | ProviderRegistry 同步 + 本地存储 |
| 3 | Session/Message 存储 | ✅ | StorageService 持久化 |
| 4 | OpenAI-compatible 调用 | ✅ | 非流式调用 + 错误处理 |
| 5 | Abort + 事件总线 | ✅ | 生成中可取消 + 事件推送 |
| 6 | 只读工具 | ✅ | 文件读取、目录列表、文本搜索 |
| 7 | 权限引擎 + 写文件 | ✅ | 权限审批 + 写文件保护 |
| 8 | Sidecar 清理 | ✅ | 默认 local-embedded，sidecar 标记为实验 |

### 架构总结

```text
UI (Index.ets / AppShell)
    ↓
MainViewModel
    ↓
OpenCodeApiAdapter (isLocal → localRuntimeClient)
    ↓
LocalRuntimeClient → LocalRuntimeService
    ↓
ProviderEngine (OpenAI-compatible HTTP)
SessionStore (StorageService)
ToolEngine (File read/write with permission)
PermissionEngine (approve/deny flow)
EventBus (message lifecycle events)
```

### 关键文件

| 文件 | 职责 |
|------|------|
| `LocalRuntimeTypes.ets` | 所有类型定义 |
| `LocalRuntimeService.ets` | 进程内 Runtime 核心 |
| `LocalRuntimeClient.ets` | 包装 LocalRuntimeService 给 Adapter |
| `RuntimeMode.ets` | RuntimeMode 类型和工具函数 |
| `OpenCodeApiAdapter.ets` | 统一 API 适配器（28 个方法三路分流） |

### 下一步优化

1. 流式响应（SSE parsing）
2. 工具调用（模型触发 read_file/write_file）
3. 上下文管理（消息窗口、token 计数）
4. 数据库存储（替代 JSON StorageService）
5. 插件系统

