# OpenCode Harmony Native

鸿蒙 6.0 原生 AI 编程客户端，基于 OpenCode Server API。

## 项目概述

OpenCode Harmony Native 是面向鸿蒙 PC / 笔记本 / 平板用户的原生 AI 编程助手。它使用 ArkTS / ArkUI 构建原生 GUI，通过 HTTP/SSE 连接 OpenCode Server，并内置国内大模型 Provider Pack。

核心理念：

- **复用 OpenCode** 的 Agent Runtime / Server / Provider 能力
- **ArkTS / ArkUI 原生重写** 前端交互层
- **配置化接入** 国内大模型（DeepSeek、Qwen、GLM 等）

## 技术架构

```
HarmonyOS 原生 App (ArkTS / ArkUI)
  │
  │ HTTP / SSE / OpenAPI Client
  ▼
OpenCode Server (opencode serve)
  │
  ▼
OpenCode Agent Runtime
  │
  ▼
LLM Providers (DeepSeek / Qwen / GLM / Kimi / ...)
```

## 功能特性

- 服务器管理：添加、测试、切换 OpenCode Server 连接
- 会话管理：新建、继续、删除 AI 编程会话
- AI 编程交互：发送 Prompt，流式接收 Agent 回复
- 工具调用展示：实时展示 AI 执行工具的状态和结果
- 权限审批：bash/edit/write 等高风险操作需要用户确认
- 代码 Diff 查看：文件变更列表 + 行级 patch 查看
- Provider 管理：启用/禁用国内模型、配置 API Key、生成 opencode.json
- 设置：字号、主题、默认模型、审批策略

## 目录结构

```
entry/src/main/ets/
├── components/                    # IDE 布局组件 (M9)
│   ├── Theme.ets                  # Catppuccin Mocha 深色主题 token 系统
│   ├── AppShell.ets               # 三栏 IDE 布局容器
│   ├── TopStatusBar.ets           # 顶部状态栏 (项目/分支/模型/Server)
│   ├── LeftActivityBar.ets        # 左侧活动栏 (文字符号导航)
│   ├── SessionSidebar.ets         # 会话侧边栏 (240px)
│   ├── AgentTranscript.ets        # Agent 转录视图 (替代聊天气泡)
│   ├── ComposerBar.ets            # 底部多行输入栏
│   ├── ToolTimelinePanel.ets      # 右侧工具调用时间线
│   ├── DiffPanel.ets              # 文件变更查看器
│   ├── InlineApprovalBar.ets      # 内联权限审批
│   ├── FilePanel.ets              # 工作区文件浏览器
│   └── LogsPanel.ets              # 事件日志面板
├── models/
│   ├── Runner.ets                 # Server 连接模型
│   ├── Provider.ets               # CN Provider 模型
│   └── Event.ets                  # SSE 事件 + API 数据模型 (WithParts/Normalized)
├── services/
│   ├── OpenCodeClient.ets         # 完整 API 客户端 (含 normalize 层)
│   ├── EventStreamClient.ets      # SSE 事件流客户端 (轮询模式)
│   ├── ProviderRegistry.ets       # Provider 注册表
│   ├── RuntimeManager.ets         # Runtime 管理器
│   └── StorageService.ets         # 持久化服务
├── pages/
│   ├── Index.ets                  # 主入口 / 全局状态管理
│   ├── ProviderPage.ets           # Provider 配置 (深色主题)
│   ├── SettingsPage.ets           # 设置 (深色主题)
│   ├── ChatAgentPage.ets          # AI 编程会话 (简化)
│   ├── ServerConnectionPage.ets   # 服务器管理
│   ├── SessionPage.ets            # 会话列表
│   ├── WorkspacePage.ets          # 工作台
│   └── DiffReviewPage.ets         # 代码变更
├── entryability/
│   └── EntryAbility.ets
└── entrybackupability/
    └── EntryBackupAbility.ets
```

## 快速开始

### 前置条件

1. 安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/) (API 12+)
2. 在电脑上安装并运行 OpenCode Server:
   ```bash
   curl -fsSL https://opencode.ai/install | bash
   cd /path/to/your/project
   opencode serve --port 4096 --hostname 0.0.0.0
   ```

### 开发

1. 用 DevEco Studio 打开本项目
2. 同步依赖 (ohpm install)
3. 运行到模拟器或真机

### 连接 OpenCode Server

1. 在"服务器"页面点击"添加"
2. 填入 Server 地址（如 `127.0.0.1` 或局域网 IP）
3. 填入端口（默认 `4096`）
4. 如有密码，填入密码
5. 点击"测试"验证连接
6. 点击"使用"设为当前 Server

## 国内 Provider Pack

首批支持 9 个国内供应商：

| Provider | 环境变量 |
|----------|----------|
| DeepSeek | DEEPSEEK_API_KEY |
| 通义千问 / 阿里百炼 | DASHSCOPE_API_KEY |
| 智谱 GLM | BIGMODEL_API_KEY |
| Kimi / Moonshot | MOONSHOT_API_KEY |
| MiniMax | MINIMAX_API_KEY |
| 火山方舟 | VOLCENGINE_API_KEY |
| 百度千帆 | QIANFAN_API_KEY |
| SiliconFlow | SILICONFLOW_API_KEY |
| 自定义 OpenAI Compatible | CUSTOM_API_KEY |

在 Provider 页面可启用/禁用、配置 API Key、生成 `opencode.json` 配置。

## 文档

- [API 映射文档](docs/harmony-native/api-mapping.md) - OpenCode Server 完整 API 参考
- [Provider 系统文档](docs/harmony-native/provider-system.md) - Provider 配置和模型系统
- [Runtime 验证报告](docs/harmony-native/runtime-native-verification.md) - 进程管理能力评估
- [UI Parity Checklist](docs/harmony-native/ui-parity-checklist.md) - IDE 布局重构检查清单
- [Smoke Test Guide](docs/harmony-native/smoke-test.md) - 运行时联调测试手册
- [M11 API Smoke Matrix](docs/harmony-native/m11-api-smoke-matrix.md) - M11 端点验证矩阵
- [M11 Demo Script](docs/harmony-native/m11-demo-script.md) - 演示录屏流程
- [M11 下一步方案](docs/harmony-native/m11-next-step-plan.md) - 真机闭环验证方案
- [平板 PRD](docs/opencode_harmony_tablet_prd.md) - 产品需求文档

## 开发阶段

| 阶段 | 状态 | 内容 |
|------|------|------|
| M0: 上游研究 | ✅ | clone OpenCode, 分析 API, 导出 OpenAPI spec |
| M1: Provider Pack | ✅ | CN Provider 模型、注册表、配置生成 |
| M2: App 骨架 | ✅ | 7 个页面组件、导航中枢 |
| M3: OpenCodeClient | ✅ | 基于真实 API 的完整客户端 |
| M4: Session + Chat | ✅ | 会话管理、消息交互、流式展示 |
| M5: Event Stream | ✅ | SSE 客户端、工具卡片、权限审批 |
| M6: Diff Viewer | ✅ | 文件变更列表、patch 查看 |
| M7: RuntimeManager | ✅ | 连接检测、健康检查、启动指南 |
| M8: 打包文档 | ✅ | README、API 文档、验证报告 |
| M9: AppShell Wiring | ✅ | 三栏 IDE 联调、真实页面接入、深色主题统一 |
| M10: API 联调修复 | ✅ | OpenCodeClient 对齐真实 OpenAPI spec、normalize 层、13 项 endpoint 修正 |
| M11: 闭环验证准备 | ✅ | 轮询状态机、结构化日志、diff messageID 策略、ArkTS 审计 |

## 安全策略

- API Key 不写入仓库、不出现在日志
- Server 默认连接 `127.0.0.1`，局域网访问需用户主动配置
- bash / edit / write 默认需要用户审批
- 本地不保存完整代码仓库
- Token 不明文展示

## 许可

基于 OpenCode 开源项目 fork，遵循原项目许可证。
