## UI Parity Checklist — OpenCode IDE Layout

本文档追踪 ArkUI 页面从"移动端聊天气泡"到"OpenCode-like IDE/Agent Console"三栏布局的重构进度。

### 布局架构

```
┌─────────────────────────────────────────────────────────┐
│ TopStatusBar (28px)  [●] project / branch | model | url │
├────┬────────┬──────────────────────────────┬────────────┤
│    │        │                              │            │
│ A  │ Sess-  │  Center Content              │  Right     │
│ c  │ ion    │  (chat / diff / provider /   │  Panel     │
│ t  │ Side-  │   files / settings)          │  (tools /  │
│ i  │ bar    │                              │   diff /   │
│ v  │ 240px  │                              │   logs)    │
│ i  │        │                              │            │
│ t  │        │                              │  300px     │
│ y  │        │                              │            │
│ B  │        ├──────────────────────────────┤            │
│ a  │        │  ComposerBar                 │            │
│ r  │        │  (input + send/abort)        │            │
│48px│        │                              │            │
├────┴────────┴──────────────────────────────┴────────────┤
└─────────────────────────────────────────────────────────┘
```

### 组件清单

| # | Component | File | Status | Notes |
|---|-----------|------|--------|-------|
| 1 | Theme | `components/Theme.ets` | DONE | Catppuccin Mocha 深色 token 系统 |
| 2 | AppShell | `components/AppShell.ets` | DONE | 三栏容器, 已接入真实页面 |
| 3 | TopStatusBar | `components/TopStatusBar.ets` | DONE | 连接状态/项目/分支/模型/URL/Token |
| 4 | LeftActivityBar | `components/LeftActivityBar.ets` | DONE | 文字符号导航 + 动态连接指示器 |
| 5 | SessionSidebar | `components/SessionSidebar.ets` | DONE | 会话列表 + 新建按钮 |
| 6 | AgentTranscript | `components/AgentTranscript.ets` | DONE | 转录式消息展示 |
| 7 | ComposerBar | `components/ComposerBar.ets` | DONE | 多行输入 + 发送/中止 |
| 8 | ToolTimelinePanel | `components/ToolTimelinePanel.ets` | DONE | 工具调用时间线 |
| 9 | DiffPanel | `components/DiffPanel.ets` | DONE | 文件变更 A/M/D/R + patch |
| 10 | InlineApprovalBar | `components/InlineApprovalBar.ets` | DONE | 权限审批 allow/deny |
| 11 | FilePanel | `components/FilePanel.ets` | DONE | 工作区文件浏览器 |
| 12 | LogsPanel | `components/LogsPanel.ets` | DONE | 事件流日志 (颜色编码) |

### 页面适配

| Page | Status | Dark Theme | Notes |
|------|--------|------------|-------|
| Index.ets | DONE | YES | 全局状态管理, 驱动 AppShell |
| ProviderPage.ets | DONE | YES | 深色 Catppuccin 风格 |
| SettingsPage.ets | DONE | YES | 深色 Catppuccin 风格 |
| ChatAgentPage.ets | DONE | - | 简化为占位 |

### 功能检查

| Feature | Status | Notes |
|---------|--------|-------|
| 移除 80px emoji 导航 | DONE | 替换为 48px 文字符号 Activity Bar |
| 三栏布局 (Activity + Sidebar + Center + Right) | DONE | Row 嵌套 Column |
| 转录式消息展示 (替代聊天气泡) | DONE | TranscriptBlock 统一模型 |
| 紧凑工具时间线 | DONE | 右侧面板 tools tab |
| 内联权限审批 | DONE | AgentTranscript 内 PermissionBlock |
| Composer 底部固定 | DONE | layoutWeight 弹性布局 |
| 深色主题统一 (Catppuccin Mocha) | DONE | Theme.ets 集中管理 |
| toolEntries 去重 | DONE | Map dedup in loadMessages |
| 连接状态动态指示 | DONE | connected/connecting/disconnected 三色 |
| 右侧面板 logs tab | DONE | tools / diff / logs 三 tab |
| PlaceholderPanel 移除 | DONE | 全部替换为真实页面 |

### ArkTS 合规

| Check | Status |
|-------|--------|
| 零 untyped object literals | PASS |
| 零 any/unknown 类型 | PASS |
| 零 computed property names | PASS |
| 所有数组声明有显式类型 | PASS |
| 16 个 as 断言均有 fallback | PASS |
| 编译阻断性问题 | 0 |
