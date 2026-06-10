# OpenCode for HarmonyOS Laptop PRD

> 文档版本：V2.0  
> 阶段范围：鸿蒙笔记本原生 AI 编程客户端 + 本地 Runtime  
> 目标设备：HarmonyOS ARM 笔记本（MateBook ARM 芯片）  
> 核心目标：在鸿蒙笔记本上本地运行完整的 AI 编程闭环  
> 架构方向：全部本地化，不依赖远程 Runner

---

## 0. 项目一句话

**OpenCode for HarmonyOS Laptop 是一款运行在鸿蒙笔记本上的原生 AI 编程客户端，内置 OpenCode Runtime，在本机完成 AI 代码分析、文件修改、命令执行、Git 操作、测试构建等完整开发流程，无需连接外部服务器。**

架构全貌：

```text
鸿蒙笔记本原生客户端 (ArkTS / ArkUI)
    ↓
内置 OpenCode Runtime (opencode serve)
    ↓
本机开发环境
    ↓
代码仓库 / Git / Shell / 测试 / 构建 / 模型调用
```

核心原则：

- **客户端负责交互、展示、审批、Diff、任务管理。**
- **OpenCode Runtime 负责代码分析、Agent 执行、文件修改、命令执行、Git、测试、构建和模型调用。**
- **两者运行在同一台笔记本上，通过 localhost 通信。**

---

## 1. 项目结论

### 1.1 要做什么

> **把 OpenCode 改造成一个在鸿蒙笔记本上完全本地运行的原生 AI 编程环境。**

用户打开鸿蒙笔记本上的 App 后，应用自动启动内置的 OpenCode Runtime，然后在本机完成：

1. 自动启动和管理本地 OpenCode Runtime 进程；
2. 打开本地代码项目；
3. 创建 AI 编程会话；
4. 输入开发需求；
5. AI 分析代码、读取文件、搜索文件、修改代码、执行命令；
6. 审批高风险操作；
7. 查看代码 Diff；
8. 查看测试、构建、命令执行结果；
9. 停止、继续、重试任务；
10. 完成一次完整 AI 编程闭环。

### 1.2 不做什么

1. 不做远程 Runner 连接（不再有"添加远程服务器"概念）；
2. 不做 WebView 套壳；
3. 不替代 DevEco Studio；
4. 不优先做 ArkTS / ArkUI 专项 Agent；
5. 不优先做 DevEco 报错修复知识库；
6. 不优先做鸿蒙项目自动识别；
7. 不优先做企业管理后台；
8. 不优先做云端商业化平台。

### 1.3 最终定义

**OpenCode for HarmonyOS Laptop 是一个完全本地化的鸿蒙 AI 编程客户端。App 内置 OpenCode Runtime 二进制，启动时自动拉起 Runtime 进程，在本机完成代码修改、命令执行、Git 操作等所有开发任务。**

关键能力：

1. 内置 Runtime，开箱即用；
2. 能发起 AI 编程任务；
3. 能展示 AI 执行过程；
4. 能审批危险操作；
5. 能查看代码 Diff；
6. 能查看命令输出；
7. 能在鸿蒙笔记本上完成完整 AI 编程闭环。

---

## 2. 项目背景

OpenCode 是一个开源 AI 编程 Agent（TypeScript/Bun 项目），具备 AI 辅助代码阅读、修改、命令执行、Diff 生成、会话管理等能力。官方通过 `opencode serve` 启动 headless HTTP server，暴露 OpenAPI。

之前的设计（V1 PRD）将鸿蒙平板定位为纯客户端，通过远程连接外部 Runner 来执行开发任务。这个架构适合平板场景（算力有限、不适合本地执行），但不适合笔记本场景。

**V2 的变更理由：**

鸿蒙笔记本（MateBook ARM 芯片）与平板有本质区别：

- 有完整的本地文件系统，可以直接读写代码仓库；
- 有更强的计算能力，可以运行 Runtime 进程；
- 有完整的 Shell 环境，可以执行命令；
- 用户期望像使用普通 IDE 一样使用它，不需要额外配置远程服务器；
- 离线环境也应该能使用基础功能（模型调用仍需网络）。

因此 V2 的架构是：**App + 内置 Runtime = 完整本地开发环境。**

---

## 3. 产品目标

### 3.1 核心目标

> **在鸿蒙笔记本上实现开箱即用的本地 AI 编程环境。**

```text
打开 App
  ↓
自动启动内置 Runtime (opencode serve)
  ↓
Health check 通过
  ↓
打开本地项目目录
  ↓
创建 AI 会话
  ↓
输入编程任务
  ↓
AI 分析和修改代码
  ↓
用户审批高风险操作
  ↓
查看 Diff
  ↓
查看测试 / 构建 / 命令结果
  ↓
完成任务
```

### 3.2 产品目标

1. 鸿蒙笔记本原生客户端；
2. 内置 OpenCode Runtime（随包捆绑或首次启动自动下载）；
3. 自动启动和管理 Runtime 进程；
4. 本地项目管理（打开本地目录）；
5. 创建和管理 AI 编程会话；
6. 流式展示 AI 输出；
7. 展示工具调用过程；
8. 权限审批；
9. 代码 Diff 查看；
10. 命令输出查看；
11. 笔记本大屏布局适配；
12. 基础安全保护。

### 3.3 技术目标

1. HarmonyOS ArkTS 原生客户端；
2. 不破坏 OpenCode 原有 CLI / TUI / Desktop / IDE 使用方式；
3. 复用 OpenCode Server API（localhost 通信）；
4. 通过 Native C++ (NAPI) 模块管理 Runtime 子进程；
5. 内置 opencode 二进制，通过 rawfile 打包 + 启动时提取到 filesDir；
6. 为鸿蒙语义适配预留扩展点。

---

## 4. 用户画像

### 4.1 鸿蒙笔记本开发者

典型用户：

- 使用 HarmonyOS ARM 笔记本（MateBook ARM）；
- 日常在笔记本上写代码；
- 希望有一个本地 AI 编程助手；
- 不想要额外配置远程服务器；
- 期望开箱即用。

核心需求：

1. 打开 App 就能用，不需要配置服务器；
2. 可以直接操作本地代码仓库；
3. 可以审批 AI 的文件修改和命令执行；
4. 可以看到 AI 修改了什么代码；
5. 离线环境可以使用基础功能（编辑、Diff 等）。

### 4.2 跨平台开发者

典型用户：

- 有鸿蒙笔记本，也有 Mac / Linux 电脑；
- 在不同设备间切换工作；
- 希望 AI 编程助手在鸿蒙笔记本上也能用；
- 重视数据隐私，倾向本地运行。

核心需求：

1. 本地运行，代码不离开设备；
2. 可以连接不同 LLM 提供商；
3. 可以管理多个本地项目；
4. 可以使用不同模型。

---

## 5. 产品范围

### 5.1 P0 必须实现

#### P0-1 内置 Runtime 管理

App 内置 OpenCode Runtime 二进制，自动管理其生命周期。

功能：

1. 启动时从 rawfile 提取 opencode 二进制到 filesDir；
2. 设置可执行权限（chmod 755）；
3. 通过 Native ProcessBridge 启动 `opencode serve` 进程；
4. 自动轮询 `/global/health` 等待启动完成；
5. 进程崩溃时自动重启；
6. App 退出时停止 Runtime 进程；
7. 支持手动停止 / 重启 Runtime；
8. 显示 Runtime 状态（启动中 / 运行中 / 已停止 / 异常）。

配置项：

- Runtime 端口（默认 4096）；
- 启动参数；
- 自动启动开关；
- 日志查看。

#### P0-2 Provider 和模型管理

用户可以配置 AI 模型提供商（Provider）。

**配置流程**：App 不直接调用 LLM API。用户在 App 中输入 Provider 的 API Key 后，客户端通过 Runtime API（`PUT /auth/:providerID`，body: `{ type: "api", key: "<apiKey>" }`）将认证信息写入 Runtime。后续所有 LLM 调用由 Runtime 负责，App 仅负责展示和交互。

功能：

1. 查看 Runtime 支持的 Provider 列表（`GET /provider`）；
2. 配置 API Key（`PUT /auth/:providerID`）；
3. 移除 API Key（`DELETE /auth/:providerID`）；
4. 查看已连接的 Provider（`GET /provider` → `connected`）；
5. 通过 Runtime 配置获取可用模型列表（`GET /config/providers`）；
6. 设置默认模型（`PATCH /config`）；
7. Provider 启用 / 禁用。

支持的 Provider 类型（由 Runtime 内置支持）：

- OpenAI 兼容 API（OpenAI、Azure、第三方）；
- Anthropic API；
- Google Gemini API；
- AWS Bedrock（降级为 Bearer Token 认证）；
- 自定义 OpenAI 兼容端点。

#### P0-3 项目管理

用户可以打开本地代码项目。

功能：

1. 通过文件选择器打开本地目录；
2. 自动检测 Git 仓库信息（分支、状态）；
3. 最近项目列表；
4. 项目切换；
5. 删除项目记录。

**多项目切换机制**：OpenCode Runtime 是单实例服务，通过请求头 `x-opencode-directory` 或查询参数 `?directory=` 来切换当前操作的项目目录。切换项目不需要重启 Runtime 进程，只需在后续 API 请求中携带新的目录参数即可。客户端维护一个"当前项目"状态，所有 API 请求自动附带对应目录。

展示信息：

- 项目名称（目录名）；
- 项目路径；
- Git 分支；
- Git 状态（clean / dirty）；
- 最近会话。

#### P0-4 会话列表

用户可以查看和管理 AI 编程会话列表。

展示信息：

- 会话标题；
- 所属项目；
- Agent 类型；
- 模型；
- 状态；
- 最近消息；
- 创建时间；
- 更新时间。

状态包括：

- 未开始；
- 运行中；
- 等待审批；
- 已完成；
- 已失败；
- 已停止。

#### P0-5 创建 AI 编程会话

用户可以在项目中创建新会话。

创建会话时可以选择：

- 项目；
- Agent（build / plan / 自定义）；
- 模型；
- 初始需求；
- 是否先进入计划模式；
- 是否允许自动执行低风险操作。

#### P0-6 AI 消息交互

会话页支持：

- 用户输入文本；
- 发送消息；
- 接收 AI 流式回复；
- Markdown 渲染；
- 代码块渲染（语法高亮）；
- 复制文本；
- 复制代码；
- 停止生成；
- 继续任务；
- 重试失败任务。

#### P0-7 工具调用展示

AI 调用工具时，必须展示过程。

工具调用包括：

- 读取文件；
- 搜索文件；
- 修改文件；
- 写入文件；
- 执行命令；
- 查看 Git 状态；
- 获取 Diff；
- 调用 LSP；
- 调用格式化；
- 调用测试命令。

展示信息：

- 工具名称；
- 操作对象；
- 参数摘要；
- 当前状态；
- 执行耗时；
- 输出摘要；
- 错误信息；
- 是否需要审批。

#### P0-8 权限审批

当 AI 要执行高风险操作时，必须让用户审批。

需要审批的操作：

1. 修改文件；
2. 新建文件；
3. 删除文件；
4. 执行 bash 命令；
5. 安装依赖；
6. Git commit；
7. Git push；
8. Git reset；
9. 批量修改；
10. 外部网络访问。

审批动作：

- 允许一次；
- 拒绝；
- 本会话内允许；
- 查看详情；
- 要求 AI 重新规划；
- 停止任务。

#### P0-9 Diff 查看

用户可以查看 AI 修改后的代码 Diff。

展示内容：

- 文件列表；
- 新增 / 修改 / 删除状态；
- 新增行数；
- 删除行数；
- 行级 Diff；
- 代码高亮；
- 变更摘要；
- 复制 Diff。

笔记本布局：

- 左侧文件列表；
- 右侧 Diff 内容；
- 大文件折叠；
- 支持横向滚动；
- 支持字号调节。

#### P0-10 命令输出查看

用户可以查看命令执行结果。

展示内容：

- 命令；
- 工作目录；
- 开始时间；
- 执行耗时；
- stdout；
- stderr；
- exit code；
- 是否超时；
- 错误摘要；
- 复制输出。

#### P0-11 设置页

设置页包含：

- Runtime 管理（状态、日志、重启）；
- Provider 管理；
- 默认 Agent；
- 默认模型；
- 审批策略；
- 字号；
- 深浅色；
- 网络超时；
- 安全设置；
- 关于项目。

### 5.2 P1 增强项

P1 是争取实现但不影响 MVP 的能力：

1. 本地通知（任务完成、需要审批）；
2. 会话搜索；
3. 文件树浏览；
4. 只读文件查看；
5. 按文件回滚；
6. 按文件接受 / 拒绝修改；
7. 快捷提示词；
8. 图片上传（截图给 AI 看）；
9. 粘贴截图；
10. 错误日志导出；
11. Runtime 版本更新检查；
12. 自动更新 Runtime 二进制。

### 5.3 P2 后续能力

P2 不进入当前阶段：

1. 鸿蒙项目识别；
2. ArkTS / ArkUI 专属 Agent；
3. DevEco 报错修复；
4. module.json5 检查；
5. HarmonyOS 页面生成；
6. 企业后台；
7. 多用户协作；
8. 应用市场商业化订阅；
9. 平板 / 手机适配。

> **注意**：远程 Runner 连接已从 V2 PRD 中移除（参见 §1.2 "不做远程 Runner 连接"）。如果未来需要支持远程开发场景，将作为独立产品方向重新评估。

---

## 6. 核心用户流程

### 6.1 首次使用流程

```text
用户打开 App
  ↓
自动提取内置 opencode 二进制到 filesDir
  ↓
自动启动 Runtime (opencode serve)
  ↓
Health check 轮询
  ↓
Runtime 就绪
  ↓
进入欢迎页 / 引导配置 Provider
  ↓
配置 API Key 和模型
  ↓
打开第一个项目目录
  ↓
创建第一个 AI 编程会话
```

### 6.2 AI 编程流程

```text
进入项目
  ↓
创建会话
  ↓
输入需求：帮我修复这个 bug
  ↓
AI 分析项目
  ↓
AI 读取文件
  ↓
AI 给出修改方案
  ↓
AI 请求修改文件
  ↓
客户端弹出审批卡片
  ↓
用户批准
  ↓
AI 修改文件
  ↓
AI 运行测试
  ↓
用户查看命令输出
  ↓
用户查看 Diff
  ↓
任务完成
```

### 6.3 拒绝高风险操作流程

```text
AI 请求执行命令
  ↓
客户端显示高风险命令
  ↓
用户查看命令详情
  ↓
用户选择拒绝
  ↓
AI 收到拒绝结果
  ↓
AI 重新规划
  ↓
给出低风险替代方案
```

### 6.4 Runtime 异常恢复流程

```text
Runtime 进程崩溃
  ↓
客户端检测到 Health check 失败
  ↓
显示 "Runtime 异常" 提示
  ↓
自动尝试重启 Runtime
  ↓
重启成功 → 恢复使用
  ↓
重启失败 → 显示详细错误日志
  ↓
用户可手动重试或查看排查指南
```

---

## 7. 页面设计

### 7.1 笔记本布局原则

以鸿蒙笔记本为主。

设计原则：

1. 宽屏布局，充分利用横向空间；
2. 优先双栏 / 三栏布局；
3. 左侧导航栏 + 中间内容 + 右侧详情面板；
4. 会话和 Diff 不能挤在单列；
5. 大量日志默认折叠；
6. 审批卡片要醒目；
7. 代码查看要支持横向滚动和字号调节；
8. 常用操作放在工具栏。

### 7.2 首页 / 工作台

首页展示：

- Runtime 状态；
- 最近项目；
- 最近会话；
- 运行中任务；
- 待审批事项；
- 快速新建会话；
- 设置入口。

布局：

```text
┌─────────────────────────────────────────────┐
│ 顶部栏：OpenCode Harmony / Runtime 状态      │
├───────────────┬─────────────────────────────┤
│ 左侧导航       │ 工作台内容                    │
│ - 项目         │ - 最近任务                    │
│ - 会话         │ - 待审批                      │
│ - Runtime      │ - 最近项目                    │
│ - Provider     │ - 快速开始                    │
│ - 设置         │                              │
└───────────────┴─────────────────────────────┘
```

### 7.3 Runtime 管理页

功能：

- 查看 Runtime 状态（PID、版本、运行时长、内存占用）；
- 查看 Runtime 日志；
- 启动 / 停止 / 重启 Runtime；
- 配置 Runtime 端口；
- 查看 Runtime 二进制版本和路径；
- 更新 Runtime 二进制（P1）。

状态展示：

```text
┌─────────────────────────────────────────────┐
│ Runtime 状态                                  │
│                                              │
│ ● 运行中                                      │
│ PID: 12345                                   │
│ 版本: 1.16.2                                 │
│ 端口: 4096                                   │
│ 运行时长: 2h 35m                              │
│ 路径: /data/.../files/opencode               │
│                                              │
│ [重启] [停止] [查看日志]                        │
└─────────────────────────────────────────────┘
```

### 7.4 Provider 管理页

功能：

- 添加 / 编辑 / 删除 Provider；
- 配置 API Key、Base URL；
- 连接测试（延迟测量）；
- 自动获取模型列表；
- 启用 / 禁用 Provider；
- 设置默认模型。

### 7.5 项目列表页

展示：

- 项目卡片；
- 项目路径；
- Git 分支；
- 最近会话；
- 当前状态；
- 新建会话按钮。

### 7.6 会话详情页

核心页面，推荐三栏布局：

```text
┌──────────────┬─────────────────────────┬──────────────────┐
│ 会话列表      │ 消息与工具调用            │ 详情面板           │
│              │                         │                  │
│ Session A    │ User: 修复 bug           │ Diff / Tool / Log │
│ Session B    │ AI: 正在分析...          │                  │
│ Session C    │ Tool: read file          │                  │
│              │ Tool: edit file          │                  │
│              │ Approval: 允许修改?       │                  │
└──────────────┴─────────────────────────┴──────────────────┘
```

会话页内容：

- 用户消息；
- AI 回复；
- 工具调用卡片；
- 审批卡片；
- Diff 卡片；
- 命令输出卡片；
- 错误提示；
- 任务状态栏。

底部输入区：

- 文本输入框；
- 发送按钮；
- 停止按钮；
- 附加上下文按钮。

### 7.7 审批中心页

展示所有待审批事项。

字段：

- 操作类型；
- 风险等级；
- 所属项目；
- 所属会话；
- 工具名称；
- AI 说明；
- 创建时间。

操作：

- 批准；
- 拒绝；
- 查看详情；
- 停止任务。

### 7.8 Diff 页

笔记本双栏布局：

```text
┌────────────────────┬────────────────────────────────┐
│ 文件列表             │ 行级 Diff                       │
│                    │                                │
│ + src/a.ts          │ - old line                      │
│ M src/b.ts          │ + new line                      │
│ D src/c.ts          │                                │
└────────────────────┴────────────────────────────────┘
```

功能：

- 文件列表；
- 文件状态；
- 行级 Diff；
- 代码高亮；
- 新增 / 删除标识；
- 大文件折叠；
- 复制；
- 让 AI 解释（P1）；
- 回滚（P1）。

### 7.9 命令输出页

展示：

- 命令；
- stdout；
- stderr；
- exit code；
- 耗时；
- 复制按钮；
- 错误摘要；
- 重新执行（P1）。

长日志处理：

- 默认只展示最后 200 行；
- 支持展开全部；
- 支持搜索（P1）；
- 错误行高亮。

---

## 8. 技术架构

### 8.1 总体架构

```text
HarmonyOS Laptop App (ArkTS / ArkUI)
    │
    ├── UI 层：页面、组件、交互
    ├── 业务层：ViewModel、Service
    ├── 通信层：HTTP Client → localhost:4096
    ├── 进程管理层：Native C++ ProcessBridge (fork/execvp)
    └── 内置 Runtime：opencode binary (rawfile → filesDir)
                ↓
        opencode serve (localhost:4096)
                ↓
        本机文件系统 / Git / Shell / LLM API
```

### 8.2 组件职责

#### 8.2.1 ArkTS 客户端

负责：

1. 原生 UI（ArkUI）；
2. Runtime 生命周期管理（启动、停止、重启、健康检查）；
3. Provider 和模型配置；
4. 项目管理（打开本地目录）；
5. 会话管理；
6. 消息收发和流式展示；
7. 工具调用展示；
8. 审批操作；
9. Diff 查看；
10. 命令输出查看；
11. 本地设置和安全存储；
12. 笔记本布局适配。

技术栈：

- ArkTS / ArkUI / Stage 模型；
- Navigation / List / Grid / SideBar；
- Preferences（本地安全存储）；
- HTTP 请求（localhost 通信）；
- SSE（事件流）；
- Markdown 渲染；
- Diff 渲染；
- 代码高亮。

#### 8.2.2 Native ProcessBridge

C++ NAPI 模块，负责管理 opencode 子进程：

- `fork()` + `execvp()` 启动进程；
- `pipe()` + `select()` 捕获 stdout/stderr；
- `kill()` 发送信号停止进程；
- `waitpid()` 等待进程退出；
- 日志缓冲和回调。

#### 8.2.3 内置 OpenCode Runtime

opencode 二进制通过以下方式分发：

1. **rawfile 打包**：编译时将 opencode 二进制放入 `resources/rawfile/opencode`；
2. **首次启动提取**：App 启动时从 rawfile 读取二进制，写入 `context.filesDir/opencode`；
3. **设置权限**：`chmod 755` 使其可执行；
4. **缓存机制**：已提取则跳过（通过 `fileIo.statSync` 检测）；
5. **绝对路径执行**：Native ProcessBridge 使用绝对路径调用，不依赖 PATH。

Runtime 启动参数：

```bash
{filesDir}/opencode serve --port 4096 --hostname 127.0.0.1
```

#### 8.2.4 LocalOpenCodeServerManager

ArkTS 服务类，统一管理 Runtime 生命周期：

- `init(context)`：初始化，提取二进制；
- `startServerProcess(config)`：启动 Runtime 进程；
- `stopServerProcess(pid)`：停止进程；
- `checkHealth(config)`：健康检查；
- `saveAndActivate(config)`：保存配置并激活连接；
- `findOpencodeBinary()`：查找二进制路径（filesDir > PATH 回退）。

### 8.3 通信架构

客户端与 Runtime 通过 localhost HTTP 通信：

```text
ArkTS Client  ──HTTP──▶  localhost:4096 (opencode serve)
     │                         │
     ├── GET  /global/health   │
     ├── GET  /session         │
     ├── POST /session         │
     ├── GET  /session/:id     │
     ├── POST /session/:id/message      │
     ├── GET  /event (SSE)     │
     ├── POST /permission/:id/reply     │
     ├── PUT  /auth/:providerID         │
     └── GET  /session/:id/diff         │
```

所有通信均在 localhost，不经过网络，安全性高。

### 8.4 仓库结构

当前仓库：

```text
ohopencode/
  AppScope/
    app.json5

  entry/
    src/main/
      ets/
        app/
          App.ets

        pages/
          Index.ets              # 主入口，App Shell
          ProviderPage.ets       # Provider 管理
          RuntimePage.ets        # Runtime 状态
          ServerConfig.ets       # Runtime 配置
          ServerSettingsPage.ets # 服务器设置
          Settings.ets           # 全局设置
          ModelSettingsPage.ets  # 模型设置

        components/
          home/
            OpenCodeHomeLaunch.ets

        models/
          Provider.ets           # Provider 数据模型
          Runner.ets             # Runner 数据模型
          ChatMessage.ets        # 消息模型

        services/
          LocalOpenCodeServerManager.ets  # Runtime 管理
          ProcessBridge.ets               # Native 进程桥接
          ProviderRegistry.ets            # Provider 注册
          ProviderConnectionService.ets   # Provider 连接测试
          StorageService.ets              # 类型化存储
          OpenCodeClient.ets              # API 客户端

        service/
          StorageService.ets              # 简单 KV 存储

        viewmodel/
          MainViewModel.ets               # 主 ViewModel

        utils/
          Constants.ets
          DateTimeUtil.ets

      cpp/
        process_manager.cpp       # C++ 进程管理
        process_manager.h
        napi_init.cpp             # NAPI 绑定
        CMakeLists.txt

      resources/
        rawfile/
          opencode                # 内置 Runtime 二进制
          web/                    # Web 前端资源
```

---

## 9. Runtime 二进制兼容性

### 9.1 当前状态

opencode 是 TypeScript/Bun 项目，通过 `bun build --compile` 编译为原生二进制。npm 分发平台特定包：

- `opencode-linux-arm64`（glibc 动态链接）
- `opencode-linux-arm64-musl`（musl 动态链接）

当前 rawfile 中使用的是 `opencode-linux-arm64-musl`（138MB），ELF 64-bit ARM aarch64。

### 9.2 兼容性风险

HarmonyOS NEXT 不是 Linux，关键差异：

1. **动态链接器路径**：Linux musl 二进制依赖 `/lib/ld-musl-aarch64.so.1`，HarmonyOS NEXT 的 musl 链接器可能在其他路径；
2. **系统调用**：HarmonyOS NEXT 内核是微内核，POSIX 兼容性可能不完整；
3. **沙箱限制**：HarmonyOS 应用沙箱可能限制执行外部二进制。

已验证：

- Native C++ 模块可以使用 `fork()` 和 `execvp()`（POSIX API）；
- 进程管理（pipe、select、waitpid、kill）均可用；
- 文件 IO（open、write、close、stat、chmod）均可用。

待验证：

- `execvp()` 能否加载 Linux ELF 二进制；
- 动态链接器是否兼容；
- 沙箱是否允许执行 filesDir 下的二进制。

### 9.3 风险缓解策略

| 风险 | 缓解策略 |
|---|---|
| 动态链接器找不到 | 尝试 patchelf 修改 interpreter 路径，或捆绑 musl libc |
| ELF 格式不兼容 | 需要用 HarmonyOS NDK 从源码编译 opencode |
| 沙箱拒绝执行 | 检查 `ohos.permission.EXECUTE_SHELL_COMMAND` 权限 |
| 二进制体积过大（138MB） | 使用 UPX 压缩，或 strip 调试符号 |
| 版本更新困难 | P1：实现 Runtime 自动更新机制 |

### 9.4 备选方案

**方案 A（主方案）：Native ProcessBridge + 内置二进制**

这是当前实现采用的方案：

1. 将 `opencode-linux-arm64-musl` 编译产物打包到 `resources/rawfile/opencode`；
2. App 启动时提取到 `context.filesDir/opencode`；
3. 通过 C++ NAPI 模块（ProcessBridge）使用 `fork()` + `execvp()` 启动 `opencode serve`；
4. 客户端通过 localhost HTTP 与 Runtime 通信。

优势：架构简单，无外部依赖，开箱即用。
风险：二进制兼容性（§9.2）需要真机验证。

如果方案 A 在真机上遇到兼容性问题（动态链接器路径、沙箱限制等），依次尝试以下备选方案：

**方案 B：通过 HarmonyOS Shell 执行**

如果 HarmonyOS 提供了某种 Shell 或终端环境（如 DevEco 终端），可以通过 `child_process` 或类似 API 执行命令。

**方案 C：Bun for HarmonyOS**

如果 Bun 运行时未来支持 HarmonyOS，可以直接运行 opencode 的 TypeScript 源码，无需编译二进制。

**方案 D：远程模式作为降级**

保留远程 Runner 连接能力（P2），当本地 Runtime 不可用时降级到远程模式。

---

## 10. API 设计（Source-Verified）

> 以下端点均从 `OpenCodeClient.ets` 源码中提取，严格对齐 OpenCode v1.16.2 HTTP API。

### 10.1 通信方式

客户端通过 HTTP 与本地 Runtime 通信，基地址为 `http://127.0.0.1:{port}`。

项目切换通过两种方式实现：

- 请求头 `x-opencode-directory: /path/to/project`
- 查询参数 `?directory=/path/to/project`

所有 API 请求均自动附带当前项目目录。认证使用 HTTP Basic Auth（用户名 `opencode`，密码为 Token）。

事件流通过 SSE（Server-Sent Events）推送。

### 10.2 Health

```http
GET /global/health
```

返回：

```json
{
  "healthy": true,
  "version": "1.16.2"
}
```

### 10.3 Config

```http
GET    /config              → ConfigInfo（model, smallModel, provider, permission）
PATCH  /config              → ConfigInfo（更新配置）
GET    /config/providers    → Record<string, object>（Provider 配置模板）
```

### 10.4 Provider 与 Auth

```http
GET    /provider            → { all: ProviderPublicInfo[], default: Record, connected: string[] }
GET    /provider/auth       → Record<string, object>（可用认证方式）
PUT    /auth/:providerID    → body: { type: "api", key: "<apiKey>" } → boolean
DELETE /auth/:providerID    → boolean（移除认证）
```

> **重要**：App 不直接调用 LLM API。用户配置 Provider 的 API Key 后，通过 `PUT /auth/:providerID` 写入 Runtime，由 Runtime 负责调用 LLM。

### 10.5 Project

```http
GET    /project             → ProjectInfo[]
GET    /project/current     → ProjectInfo
```

### 10.6 Path / File

```http
GET    /path                        → { home, state, config, worktree, directory }
GET    /file?path=<encoded>         → { name, path, absolute, type, ignored }[]
GET    /file/content?path=<encoded> → FileContent
```

### 10.7 VCS

```http
GET    /vcs                 → { branch?, default_branch? }
GET    /vcs/status          → VcsFileStatus[]
GET    /vcs/diff?mode=git|branch → FileDiff[]
```

### 10.8 Session

```http
GET    /session                      → SessionInfo[]（?limit=N）
POST   /session                      → SessionInfo（body: { title? }）
GET    /session/:id                  → SessionInfo
DELETE /session/:id                  → boolean
PATCH  /session/:id                  → SessionInfo（更新标题等）
POST   /session/:id/abort            → boolean（中止任务）
POST   /session/:id/compact          → boolean（压缩上下文，v1 可能 404）
POST   /session/:id/fork             → SessionInfo（fork 会话，v1 可能 404）
```

### 10.9 Message

```http
GET    /session/:id/message          → WithParts[]（原始消息列表，?limit=N）
POST   /session/:id/message          → WithParts（同步发送，阻塞等待回复）
POST   /session/:id/prompt_async     → 204（异步发送，立即返回）
```

消息体格式：

```json
{
  "agent": "build",
  "parts": [{ "type": "text", "text": "用户输入内容" }]
}
```

### 10.10 Permission（审批）

```http
GET    /permission                   → PermissionRequest[]
POST   /permission/:requestID/reply  → body: { reply: "once"|"always"|"deny" } → boolean
POST   /session/:sessionID/permissions/:requestID/reply  → 会话级审批（v1 可能 404，回退到全局端点）
```

### 10.11 Question

```http
GET    /question?sessionID=<id>      → QuestionRequest[]
POST   /question/:requestID/reply    → body: { optionIDs: string[] } → boolean
```

### 10.12 Diff

```http
GET    /session/:id/diff?messageID=<id> → FileDiff[]
```

### 10.13 Agent / Command / Skill

```http
GET    /agent                → AgentInfo[]
GET    /command              → CommandInfo[]
GET    /skill                → SkillInfo[]
```

### 10.14 MCP / LSP / Formatter

```http
GET    /mcp                  → McpServer[]
GET    /lsp                  → LspStatus[]
GET    /formatter            → FormatterStatus[]
```

### 10.15 Instance

```http
POST   /instance/dispose     → boolean（释放 Runtime 实例）
```

### 10.16 SSE 事件流

```http
GET    /event                → SSE stream（全局事件流，附带 directory 参数）
```

事件类型由 Runtime 定义，客户端通过 SSE 监听会话进度、工具调用、审批请求等实时事件。

---

## 11. 数据模型

### 11.1 Provider

```typescript
interface Provider {
  id: string
  name: string
  type: "openai" | "anthropic" | "gemini" | "bedrock" | "custom"
  baseUrl: string
  apiKey: string
  models: string[]
  defaultModel: string
  enabled: boolean
  authStatus: "valid" | "invalid" | "missing" | "unknown"
  lastTestedAt?: number
}
```

### 11.2 Project

```typescript
interface Project {
  id: string
  name: string
  path: string
  branch?: string
  gitStatus?: string
  lastSessionId?: string
  updatedAt: number
}
```

### 11.3 Session

```typescript
interface Session {
  id: string
  projectId: string
  title: string
  agent: string
  model: string
  status: "idle" | "running" | "approval_required" | "done" | "error" | "stopped"
  lastMessage?: string
  createdAt: number
  updatedAt: number
}
```

### 11.4 Message

```typescript
interface Message {
  id: string
  sessionId: string
  role: "user" | "assistant" | "system" | "tool"
  content: string
  createdAt: number
}
```

### 11.5 ToolCall

```typescript
interface ToolCall {
  id: string
  sessionId: string
  name: string
  status: "pending" | "running" | "success" | "error" | "approval_required" | "cancelled"
  inputSummary: string
  outputSummary?: string
  riskLevel: "low" | "medium" | "high"
  startedAt?: number
  endedAt?: number
}
```

### 11.6 Approval

```typescript
interface Approval {
  id: string
  sessionId: string
  toolCallId?: string
  type: "edit" | "write" | "delete" | "bash" | "git" | "network" | "dependency"
  title: string
  description: string
  payload: unknown
  riskLevel: "low" | "medium" | "high"
  status: "pending" | "approved" | "rejected" | "expired"
  createdAt: number
}
```

### 11.7 DiffSummary

```typescript
interface DiffSummary {
  sessionId: string
  filesChanged: number
  insertions: number
  deletions: number
  files: DiffFile[]
}
```

### 11.8 DiffFile

```typescript
interface DiffFile {
  id: string
  path: string
  status: "added" | "modified" | "deleted" | "renamed"
  insertions: number
  deletions: number
}
```

### 11.9 CommandOutput

```typescript
interface CommandOutput {
  id: string
  sessionId: string
  command: string
  workDir: string
  stdout: string
  stderr: string
  exitCode: number
  startedAt: number
  endedAt?: number
  duration?: number
  timedOut: boolean
  errorSummary?: string
}
```

### 11.10 RuntimeConfig

```typescript
interface RuntimeConfig {
  port: number               // 默认 4096
  hostname: string           // 默认 "127.0.0.1"
  binaryPath: string         // filesDir 下的 opencode 路径
  autoStart: boolean         // App 启动时自动启动 Runtime
  autoRestart: boolean       // 崩溃时自动重启
  logEnabled: boolean        // 启用 Runtime 日志
  logMaxLines: number        // 日志最大行数
  args: string[]             // 额外启动参数
}
```

---

## 12. 安全策略

### 12.1 安全原则

1. 高风险操作必须审批；
2. API Key 加密存储，不明文展示；
3. API Key 不进入日志；
4. 敏感信息默认脱敏；
5. Runtime 只绑定 localhost，不对外暴露；
6. 支持清空本地缓存。

### 12.2 默认审批策略

| 操作 | 默认策略 |
|---|---|
| 读取文件 | 允许 |
| 搜索文件 | 允许 |
| 查看 Git 状态 | 允许 |
| 修改文件 | 询问 |
| 新建文件 | 询问 |
| 删除文件 | 询问 |
| 执行命令 | 询问 |
| 安装依赖 | 询问 |
| Git commit | 询问 |
| Git push | 询问 |
| Git reset | 询问 |
| 外部网络访问 | 询问 |

### 12.3 高风险命令识别

高风险命令示例：

```bash
rm -rf, sudo, chmod -R, chown -R
curl | bash, wget | bash
git reset --hard, git push --force
npm publish, docker rm, docker system prune
kubectl delete
```

处理方式：

1. 红色风险提示；
2. 展示命令全文；
3. 展示工作目录；
4. 展示 AI 解释；
5. 默认不允许自动执行；
6. 用户必须手动批准。

### 12.4 本地数据安全

App 允许保存：

- Provider 配置（加密 API Key）；
- 项目路径；
- 用户偏好；
- 最近会话摘要；
- UI 设置。

App 不保存：

- SSH 私钥；
- `.env` 明文；
- 数据库连接串。

### 12.5 HarmonyOS 权限声明

当前 `module.json5` 已声明的权限：

| 权限 | 用途 |
|---|---|
| `ohos.permission.INTERNET` | localhost HTTP 通信（Runtime API）和 SSE 事件流 |
| `ohos.permission.GET_WIFI_INFO` | 获取网络状态信息 |

V2 本地开发环境可能需要额外申请的权限：

| 权限（待评估） | 用途 | 必要性 |
|---|---|---|
| `ohos.permission.READ_MEDIA` 或文件访问权限 | 读取项目代码文件 | 待验证 — filesDir 内操作可能不需要 |
| `ohos.permission.WRITE_MEDIA` 或文件写入权限 | AI 修改代码文件 | 待验证 — Runtime 进程可能有独立权限 |
| `ohos.permission.EXECUTE_SHELL_COMMAND` | Runtime 执行 Shell 命令 | 高概率需要 |
| `ohos.permission.READ_FILE` | 文件选择器打开项目目录 | 待验证 |

> **注意**：HarmonyOS NEXT 的权限模型与 Android 不同，部分权限可能通过应用沙箱自动授权。需要在阶段 0（Runtime 本地化验证）中逐一验证实际所需权限，避免过度申请导致应用商店审核被拒。

---

## 13. 非功能需求

### 13.1 性能

| 指标 | 要求 |
|---|---|
| App 冷启动 | 3 秒内进入首页 |
| Runtime 启动 | 10 秒内 Health check 通过 |
| 会话消息发送反馈 | 1 秒内显示发送状态 |
| 流式输出首 token | 3 秒内出现（取决于模型） |
| 1000 条消息滚动 | 不明显卡顿 |
| 1MB Diff 展示 | 3 秒内完成首屏渲染 |
| 长日志展示 | 默认截断，避免卡死 |

### 13.2 稳定性

1. Runtime 崩溃要自动检测并提示重启；
2. 会话事件流断开后可恢复；
3. Runtime 异常不应导致 App 崩溃；
4. 大 Diff 不应导致页面卡死；
5. 长命令输出不应导致内存暴涨。

### 13.3 兼容性

当前适配：

1. HarmonyOS ARM 笔记本；
2. 宽屏布局；
3. 深色模式；
4. 浅色模式。

后续适配：

1. 平板；
2. 手机；
3. 折叠屏；
4. x86 笔记本。

---

## 14. 开发计划

### 14.1 阶段 0：Runtime 本地化验证

周期：1 周

目标：验证鸿蒙笔记本能运行内置 opencode Runtime。

**已完成工作：**

- ✅ rawfile 打包方案实现（`LocalOpenCodeServerManager.ets` → `extractBundledBinary`）；
- ✅ opencode-linux-arm64-musl 二进制获取并放入 rawfile（138MB）；
- ✅ Native C++ ProcessBridge 框架（`process_manager.cpp`，fork/execvp/pipe/select）；
- ✅ App Shell 入口（`Index.ets`，`aboutToAppear` 中调用 `init(context)`）；
- ✅ 代码已提交（commit `bc46ddc`）。

**待验证任务：**

1. 确认 opencode-linux-arm64-musl 二进制在 HarmonyOS NEXT 上的可执行性（动态链接器 `/lib/ld-musl-aarch64.so.1` 是否可用）；
2. 验证真机 rawfile 提取 → filesDir 写入 → chmod 755 流程；
3. 验证 ProcessBridge fork+execvp 能启动 opencode serve；
4. 验证 health check 通过；
5. 验证 API 通信正常；
6. 输出兼容性报告和风险评估。

交付物：

- Runtime 本地化 POC；
- 兼容性报告；
- 风险清单。

验收：

- App 可安装；
- Runtime 可自动启动；
- Health check 通过；
- 可通过 API 发送和接收消息。

### 14.2 阶段 1：客户端框架

周期：2 周

目标：完成笔记本客户端基础框架。

**已完成工作：**

- ✅ Runtime 管理页（`RuntimePage.ets`）；
- ✅ Provider 管理页（`ProviderPage.ets`）；
- ✅ Provider 注册服务（`ProviderRegistry.ets`）；
- ✅ Provider 连接测试（`ProviderConnectionService.ets`）；
- ✅ 页面路由（Navigation）；
- ✅ 本地存储（`StorageService.ets` x2）；
- ✅ API 客户端（`OpenCodeClient.ets`，已对齐 v1.16.2 API）。

**待实现任务：**

1. 首页工作台布局优化；
2. 项目列表（本地目录选择器）；
3. 会话列表页面；
4. 笔记本宽屏三栏布局；
5. 深浅色主题切换；
6. 基础错误提示和加载状态。

交付物：

- 可用 App 框架；
- Runtime 管理；
- Provider 管理；
- 项目 / 会话页面；
- 基础设置页。

### 14.3 阶段 2：AI 会话和流式输出

周期：2 周

目标：完成 AI 编程会话核心交互。

任务：

1. 创建会话；
2. 发送消息；
3. 接收流式输出（SSE）；
4. Markdown 渲染；
5. 代码块渲染（语法高亮）；
6. 停止 / 重试任务；
7. 会话状态同步；
8. Agent 选择；
9. 模型选择；
10. 事件流重连；
11. 错误状态展示。

### 14.4 阶段 3：工具调用和审批

周期：2-3 周

目标：完成 AI 编程安全闭环。

任务：

1. 工具调用事件解析和卡片展示；
2. 审批请求卡片；
3. 审批中心；
4. 批准 / 拒绝 API；
5. 风险等级展示；
6. 高风险命令识别；
7. 审批结果同步；
8. 操作日志。

### 14.5 阶段 4：Diff 和命令输出

周期：2 周

目标：完成代码修改审查能力。

任务：

1. Diff 摘要和单文件 Diff 展示；
2. 行级 Diff Viewer；
3. 代码高亮；
4. 大文件折叠；
5. 命令输出卡片；
6. stdout / stderr / exit code 展示；
7. 日志截断和复制。

### 14.6 阶段 5：稳定性和发布

周期：1-2 周

目标：完成可用版本。

任务：

1. 真机测试；
2. Runtime 稳定性测试（长时间运行、崩溃恢复）；
3. 大会话和大 Diff 测试；
4. 崩溃修复；
5. UI 细节优化；
6. 安装包构建；
7. 使用文档。

---

## 15. 总排期

| 阶段 | 周期 | 目标 |
|---|---:|---|
| 阶段 0：Runtime 本地化验证 | 1 周 | 验证内置 Runtime 可在鸿蒙笔记本运行 |
| 阶段 1：客户端框架 | 2 周 | 完成基础 App 框架 |
| 阶段 2：AI 会话和流式输出 | 2 周 | 完成 AI 编程会话 |
| 阶段 3：工具调用和审批 | 2-3 周 | 完成安全操作闭环 |
| 阶段 4：Diff 和命令输出 | 2 周 | 完成代码审查能力 |
| 阶段 5：稳定和发布 | 1-2 周 | 形成可用版本 |

总周期：**10-12 周。**

---

## 16. 与 V1 PRD 的主要变更

| 维度 | V1（平板 + 远程） | V2（笔记本 + 本地） |
|---|---|---|
| 目标设备 | HarmonyOS 平板 | HarmonyOS ARM 笔记本 |
| 架构 | 客户端 → 远程 Runner | 客户端 + 内置 Runtime |
| Runtime 位置 | 外部电脑 / 服务器 | 本机 filesDir |
| 通信方式 | 局域网 / 远程 HTTP | localhost HTTP |
| 用户配置 | 需要配置 Runner 地址 | 开箱即用，自动启动 |
| 代码仓库 | 在 Runner 端 | 在本机 |
| 命令执行 | 在 Runner 端 | 在本机 |
| Git 操作 | 在 Runner 端 | 在本机 |
| 离线能力 | 不可用（依赖网络） | 基础功能可用（模型调用仍需网络） |
| 安全模型 | 网络通信 + Token | localhost 通信，无需网络 |
| Mobile Gateway | 可能需要 | 不需要（直接调用 OpenCode API） |
| Runner 管理 | 核心功能 | 不存在（改为 Runtime 管理） |
| Provider 管理 | 在 Runner 端配置 | 在 App 内配置 |
