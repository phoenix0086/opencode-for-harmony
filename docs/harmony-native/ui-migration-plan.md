## OpenCode Desktop 1:1 UI 迁移计划

基于 OpenCode Desktop v1.16.2 源码分析（packages/app + packages/ui），逐项对照鸿蒙原生客户端现状，制定分阶段迁移方案。

---

### 功能差距总览

| 功能模块 | OpenCode Desktop | 鸿蒙现状 | 差距 |
|---------|-----------------|---------|------|
| 布局框架 | 多 Tab Session + 侧边栏 + 可折叠面板 | AppShell 三栏布局 | 缺多 Tab、缺面板折叠 |
| 聊天渲染 | Markdown 流式渲染、代码高亮、think 指示器 | 纯文本 AgentTranscript | 需完整 Markdown 引擎 |
| 工具卡片 | bash/edit/write/read/grep/glob/webfetch 各有专属 UI | ToolTimelinePanel 简略时间线 | 需 7+ 种专用工具卡片 |
| 权限审批 | once / always / reject 三选项 + 模式匹配 | approve / reject 二选一 | 缺 always 选项 |
| Diff 查看 | session-diff 行级 + 文件级 + 注释 | DiffPanel 文件列表 + patch | 缺行级注释 |
| 会话管理 | 多会话 Tab、Fork、Share、重试 | SessionSidebar 列表 | 缺 Tab/Fork/Share |
| Provider 设置 | 完整 CRUD + 连接对话框 + 自定义表单 | M12 ProviderPage ✓ | 基本对齐 |
| Model 选择 | 弹窗选择器 + 搜索 + 分组 | ModelPage 基础版 | 需弹窗化 |
| MCP 服务器 | 选择器 + 状态显示 | 无 | 全新开发 |
| 设置中心 | General/Models/Providers/Servers/Keybinds | SettingsPage 简略版 | 需 5 个设置子页 |
| 文件引用 | @ 搜索文件 → 附带到 prompt | 无 | 全新开发 |
| Agent 切换 | Build/Plan 模式 Tab 切换 | 无 | 全新开发 |
| 终端集成 | xterm.js 嵌入式终端 | 无 | 需评估可行性 |
| 主题切换 | system / tokyonight / catppuccin + 自定义 | 仅 catppuccin | 缺切换器 |
| 自动更新 | 检测 + 提示 + 安装 | 无 | 低优先级 |
| Title Bar | 历史导航 + Tab 管理 + 状态弹窗 | 无独立 TitleBar | 需整合 |
| 调试栏 | debug-bar 调试信息 | 无 | 低优先级 |

---

### 阶段 1：聊天核心体验 (M13)

**目标**：让 Agent 对话达到 OpenCode Desktop 的视觉和信息密度。

#### 1.1 Markdown 流式渲染组件
- 新建 `MarkdownRenderer.ets` — 支持 GFM 表格、代码块、链接、列表
- 代码块：语言标签 + 行号 + 复制按钮
- 流式追加：`onChunk(text)` 接口，增量渲染
- 对照：`packages/ui/src/components/markdown.tsx`

#### 1.2 Agent 消息 Turn 组件
- 新建 `SessionTurn.ets` — 单条消息（用户/助手）的完整渲染
- 用户消息：Markdown + 文件附件标签
- 助手消息：Markdown + 工具调用卡片 + 思考状态
- 对照：`packages/ui/src/components/session-turn.tsx`

#### 1.3 思考状态指示器
- 新建 `ThinkingHeading.ets` — "Agent is thinking..." 动画
- 三种状态：thinking → acting(tool) → responding
- 对照：`packages/ui/src/components/thinking-heading.stories.tsx`

#### 1.4 基础工具卡片
- 新建 `BasicToolCard.ets` — 通用工具展示框架
- 状态：pending → running → success/error
- 可折叠展开详情
- 对照：`packages/ui/src/components/basic-tool.tsx`

#### 1.5 专用工具卡片
- `BashToolCard.ets` — 命令 + stdout/stderr 输出
- `EditToolCard.ets` — 文件路径 + 行级 diff
- `WriteToolCard.ets` — 文件路径 + 内容预览
- `ReadToolCard.ets` — 文件路径 + 内容摘要
- `GrepToolCard.ets` — 搜索模式 + 匹配结果
- `GlobToolCard.ets` — 文件模式 + 匹配文件列表
- `WebFetchToolCard.ets` — URL + 摘要

---

### 阶段 2：权限 + Agent 模式 (M14)

#### 2.1 增强权限审批栏
- 改造 `InlineApprovalBar.ets`
- 三按钮：once（仅本次）/ always（同类操作始终允许）/ reject
- 显示匹配模式（如 `git *` → allow）
- 对照：`packages/app/src/components/session/` 中的审批逻辑

#### 2.2 Agent 模式切换
- 在 ComposerBar 添加 Build/Plan Tab 切换
- Plan 模式：edit/bash 权限自动设为 ask
- Build 模式：全权限
- 状态显示在 ComposerBar 左侧
- 对照：OpenCode Tab 键切换 Plan/Build

#### 2.3 上下文用量显示
- 新建 `ContextUsage.ets` — 显示 token 消耗进度条
- 位置：ComposerBar 底部或 StatusBar
- 对照：`packages/app/src/components/session-context-usage.tsx`

---

### 阶段 3：会话管理增强 (M15)

#### 3.1 会话 Tab 栏
- 在 SessionHeader 区域添加多 Tab 支持
- 每个 Tab 对应一个活跃 Session
- 支持关闭、重命名
- 对照：`packages/app/src/components/titlebar.tsx` 的 Tab 管理

#### 3.2 会话 Fork
- 在 Session 上下文菜单添加"Fork"选项
- 从当前消息创建分支会话
- 对照：`packages/app/src/components/dialog-fork.tsx`

#### 3.3 会话分享
- 调用 Server API 生成分享链接
- 显示分享状态（已分享/未分享）
- 对照：OpenCode `/share` 命令

#### 3.4 会话重试
- 在失败的助手消息上添加"重试"按钮
- 从该点重新发送
- 对照：`packages/ui/src/components/session-retry.tsx`

---

### 阶段 4：设置中心完整化 (M16)

#### 4.1 设置对话框框架
- 改造 `SettingsPage.ets` → 带侧边导航的设置对话框
- 5 个子页面：General / Models / Providers / Servers / Keybinds
- 对照：`packages/app/src/components/dialog-settings.tsx`

#### 4.2 Models 设置页
- 模型列表（按 Provider 分组）
- 启用/禁用单个模型
- 设置默认模型 / 小模型
- 模型搜索
- 对照：`packages/app/src/components/settings-models.tsx`

#### 4.3 Providers 设置页
- 已有 M12 ProviderPage，整合为设置子页
- 添加连接状态指示
- 对照：`packages/app/src/components/settings-providers.tsx`

#### 4.4 Servers 设置页
- MCP 服务器列表
- 启用/禁用 MCP 服务器
- 工具级别开关
- 对照：`packages/app/src/components/settings-servers.tsx`

#### 4.5 Keybinds 设置页
- 快捷键列表（可编辑）
- 对照：`packages/app/src/components/settings-keybinds.tsx`

#### 4.6 Model 选择弹窗
- 从 ComposerBar 点击模型名弹出
- 搜索 + Provider 分组
- 对照：`packages/app/src/components/dialog-select-model.tsx`

---

### 阶段 5：文件 + Diff 增强 (M17)

#### 5.1 @ 文件引用
- ComposerBar 输入 `@` 触发文件搜索
- 选中的文件显示为标签
- 文件内容附带发送
- 对照：`packages/app/src/components/dialog-select-file.tsx`

#### 5.2 Diff 行级注释
- DiffPanel 增加行级增删高亮
- 支持行号跳转
- 对照：`packages/ui/src/components/diff-changes.tsx`

#### 5.3 文件树增强
- FilePanel 添加文件类型图标
- 文件搜索过滤
- 对照：`packages/app/src/components/file-tree.tsx`

---

### 阶段 6：视觉对齐 (M18)

#### 6.1 主题切换器
- 支持 catppuccin / tokyonight / system
- 设置页添加主题选择
- Theme.ets 扩展为多主题

#### 6.2 Provider 图标
- 每个 Provider 显示品牌图标
- 新建 provider-icons 资源集
- 对照：`packages/ui/src/components/provider-icons/`

#### 6.3 Toast 通知
- 操作反馈 Toast（保存成功、复制成功等）
- 对照：`packages/ui/src/components/toast.tsx`

#### 6.4 动画过渡
- 工具卡片展开/收起动画
- 消息出现动画
- 对照：`packages/ui/src/components/text-reveal.tsx`

---

### 阶段 7：高级功能 (M19+)

#### 7.1 MCP 服务器管理
- 新建 `MCPPanel.ets`
- 服务器列表 + 状态指示
- 工具级开关
- 对照：`packages/app/src/components/dialog-select-mcp.tsx`

#### 7.2 Status Popover
- 连接状态弹窗（Server 信息、Token 消耗、活跃会话数）
- 对照：`packages/app/src/components/status-popover.tsx`

#### 7.3 目录选择器
- 项目/工作区切换
- 最近项目列表
- 对照：`packages/app/src/components/dialog-select-directory.tsx`

#### 7.4 终端集成（评估）
- HarmonyOS WebView 嵌入 xterm.js
- 或使用原生 Shell 组件
- 对照：`packages/app/src/components/terminal.tsx`

---

### 优先级排序

| 优先级 | 阶段 | 预计工作量 | 价值 |
|--------|------|-----------|------|
| P0 | M13 聊天核心 | 5-7 个文件 | 核心体验质的飞跃 |
| P1 | M14 权限+Agent | 3-4 个文件 | 安全+专业度 |
| P1 | M15 会话管理 | 4-5 个文件 | 多任务效率 |
| P2 | M16 设置中心 | 5-6 个文件 | 完整性 |
| P2 | M17 文件+Diff | 3-4 个文件 | 开发体验 |
| P3 | M18 视觉对齐 | 4-5 个文件 | 品牌一致性 |
| P3 | M19 高级功能 | 5+ 个文件 | 差异化 |

### 建议执行顺序

**M13 → M14 → M16 → M15 → M17 → M18 → M19**

M13 聊天核心是体验基础，M14 权限是安全刚需，M16 设置中心让应用可配置，M15 会话管理提升效率，后续按优先级递进。
