# OpenCode for HarmonyOS Tablet 第一阶段 PRD

> 文档版本：V1.0  
> 阶段范围：第一阶段 / 移植能用 / 鸿蒙平板原生 AI 编程客户端  
> 目标设备：HarmonyOS 平板电脑  
> 核心目标：让用户可以在鸿蒙平板上使用 OpenCode 完成 AI 编程闭环  
> 不包含范围：鸿蒙语义深度适配、ArkTS/ArkUI 专项 Agent、DevEco 报错库、Android 转鸿蒙迁移、企业管理后台

---

## 0. 项目一句话

**OpenCode for HarmonyOS Tablet 是一款运行在鸿蒙平板电脑上的原生 AI 编程客户端，用户可以通过平板连接 OpenCode Server / Runner，在平板上发起 AI 编程任务、查看执行过程、审批高风险操作、查看代码 Diff 和命令输出，从而完成完整 AI 编程流程。**

第一阶段的目标不是把 OpenCode Core 完整塞进鸿蒙本地运行，而是先完成：

```text
鸿蒙平板原生客户端
    ↓
OpenCode Server / Runner
    ↓
真实开发环境
    ↓
代码仓库 / Git / Shell / 测试 / 构建 / 模型调用
```

也就是说：

- **鸿蒙平板端负责交互、展示、审批、Diff、任务管理。**
- **OpenCode Runner 端负责真实代码仓库、Agent 执行、文件修改、命令执行、Git、测试、构建和模型调用。**

---

## 1. 项目结论

### 1.1 第一阶段要做什么

第一阶段要做的是：

> **把 OpenCode 改造成一个能在鸿蒙平板电脑上使用的原生 AI 编程客户端。**

用户打开鸿蒙平板上的 App 后，可以连接一台运行 OpenCode 的开发机、服务器或远程 Runner，然后在平板上完成：

1. 添加和连接 Runner；
2. 查看可用项目；
3. 创建 AI 编程会话；
4. 输入开发需求；
5. 查看 AI 分析代码、读取文件、搜索文件、修改代码、执行命令的过程；
6. 审批高风险操作；
7. 查看代码 Diff；
8. 查看测试、构建、命令执行结果；
9. 停止、继续、重试任务；
10. 完成一次完整 AI 编程闭环。

### 1.2 第一阶段不做什么

第一阶段不做：

1. 不做完整手机/平板本地 IDE；
2. 不把 OpenCode Core 全部移植到鸿蒙本地运行；
3. 不做 WebView 套壳；
4. 不替代 DevEco Studio；
5. 不优先做 ArkTS / ArkUI 专项 Agent；
6. 不优先做 DevEco 报错修复知识库；
7. 不优先做鸿蒙项目自动识别；
8. 不优先做 Android 转鸿蒙迁移；
9. 不优先做企业管理后台；
10. 不优先做云端商业化平台。

### 1.3 第一阶段最终定义

**OpenCode for HarmonyOS Tablet 第一阶段，是将 OpenCode 改造成可在鸿蒙平板电脑上使用的原生 AI 编程客户端。**

第一阶段的关键不是“懂鸿蒙开发语义”，而是先实现：

1. 能连接 OpenCode Runner；
2. 能发起 AI 编程任务；
3. 能展示 AI 执行过程；
4. 能审批危险操作；
5. 能查看代码 Diff；
6. 能查看命令输出；
7. 能在鸿蒙平板上完成完整 AI 编程闭环。

---

## 2. 项目背景

OpenCode 是一个开源 AI 编程 Agent，具备 AI 辅助代码阅读、修改、命令执行、Diff 生成、会话管理等能力。其官方形态包括 terminal-based interface、desktop app 和 IDE extension，并且提供 `opencode serve` 方式启动 headless HTTP server，暴露 OpenAPI，供客户端调用。

这说明 OpenCode 本身具备多客户端架构基础。当前已有 TUI、桌面端、IDE 插件等客户端形态，因此新增一个 HarmonyOS Tablet 原生客户端在架构上是成立的。

但是，OpenCode 当前主要面向电脑端使用，终端 TUI 不适合鸿蒙平板触控交互，桌面端不能直接运行在鸿蒙平板上，WebView 套壳体验又不足以形成原生产品。因此需要针对鸿蒙平板重新设计客户端。

本项目第一阶段的机会是：

> **保留 OpenCode 的 Agent 执行能力，把交互层重做成鸿蒙平板原生产品。**

---

## 3. 产品目标

### 3.1 核心目标

第一阶段只追求一个核心目标：

> **在鸿蒙平板电脑上可用地运行 OpenCode AI 编程流程。**

这里的“可用”不是简单打开页面，而是要完成以下闭环：

```text
添加 Runner
  ↓
连接 OpenCode Server
  ↓
选择项目
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

第一阶段产品目标：

1. 做出鸿蒙平板原生客户端；
2. 能连接 OpenCode Server / Runner；
3. 能展示项目列表；
4. 能创建和管理 AI 编程会话；
5. 能流式展示 AI 输出；
6. 能展示工具调用过程；
7. 能展示和处理权限审批；
8. 能展示代码 Diff；
9. 能展示命令输出；
10. 能适配鸿蒙平板大屏布局；
11. 能完成基础安全保护；
12. 能形成可持续迭代的技术架构。

### 3.3 技术目标

第一阶段技术目标：

1. 新增 HarmonyOS ArkTS 原生客户端；
2. 不破坏 OpenCode 原有 CLI / TUI / Desktop / IDE 使用方式；
3. 尽量复用 OpenCode Server API；
4. 必要时新增 Mobile Gateway 适配层；
5. 把复杂执行逻辑留在 Runner 端；
6. 平板端只负责交互、展示、审批和任务管理；
7. 为第二阶段鸿蒙语义适配预留扩展点。

---

## 4. 用户画像

### 4.1 个人开发者

典型用户：

- 有一台鸿蒙平板；
- 平时在电脑上写代码；
- 想在平板上远程控制 AI 编程任务；
- 不一定要在平板上手写大量代码；
- 更关心任务推进、审批和 Diff 查看。

核心需求：

1. 平板上可以发起 AI 编程任务；
2. 平板上可以查看 AI 正在做什么；
3. 平板上可以审批是否允许 AI 修改文件；
4. 平板上可以查看 AI 修改了哪些代码；
5. 出门后仍然可以管理 AI 编程任务。

### 4.2 小团队开发者

典型用户：

- 团队内部有共享开发机或服务器；
- 多人使用 AI 编程工具；
- 希望在平板上管理任务；
- 希望 AI 修改代码前可审查。

核心需求：

1. 可连接多个 Runner；
2. 可查看不同项目；
3. 可查看会话历史；
4. 可审批高风险操作；
5. 可避免 AI 误操作。

### 4.3 企业研发人员

第一阶段只做基础兼容，不做完整企业版。

企业用户第一阶段可用场景：

1. 连接企业内网 Runner；
2. 使用内部代码仓库；
3. 通过平板查看 AI 编程任务；
4. 通过审批防止高风险操作。

不包含：

1. 企业 SSO；
2. 组织架构；
3. 权限分组；
4. 审计后台；
5. 多租户管理。

---

## 5. 第一阶段产品范围

### 5.1 P0 必须实现

P0 是第一阶段必须实现的能力。

#### P0-1 Runner 连接

用户可以在鸿蒙平板上添加 OpenCode Runner。

Runner 可以是：

1. 本地电脑；
2. 局域网电脑；
3. 远程服务器；
4. 云开发机；
5. 企业内网服务器。

配置项：

- Runner 名称；
- 地址；
- 端口；
- 协议；
- 用户名；
- 密码 / Token；
- 是否启用 HTTPS；
- 是否允许自签证书；
- 连接测试；
- 保存配置；
- 删除配置。

#### P0-2 项目列表

连接 Runner 后，用户可以看到项目列表。

展示信息：

- 项目名称；
- 项目路径；
- Git 分支；
- 当前状态；
- 最近会话；
- 是否有运行中任务；
- 是否有待审批操作。

如果 OpenCode Server 第一阶段只能暴露当前项目，则允许简化为：

- 当前项目；
- 当前路径；
- 当前 Git 状态；
- 当前会话列表。

#### P0-3 会话列表

用户可以查看 AI 编程会话列表。

展示信息：

- 会话标题；
- 所属项目；
- Agent；
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

#### P0-4 创建 AI 编程会话

用户可以在项目中创建新会话。

创建会话时可以选择：

- 项目；
- Agent；
- 模型；
- 初始需求；
- 是否先进入计划模式；
- 是否允许自动执行低风险操作。

#### P0-5 AI 消息交互

会话页支持：

- 用户输入文本；
- 发送消息；
- 接收 AI 流式回复；
- Markdown 展示；
- 代码块展示；
- 复制文本；
- 复制代码；
- 停止生成；
- 继续任务；
- 重试失败任务。

#### P0-6 工具调用展示

AI 调用工具时，平板端必须展示过程。

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

#### P0-7 权限审批

当 AI 要执行高风险操作时，平板端必须让用户审批。

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
- 本项目内允许，P1；
- 查看详情；
- 要求 AI 重新规划；
- 停止任务。

#### P0-8 Diff 查看

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

平板大屏适配：

- 左侧文件列表；
- 右侧 Diff 内容；
- 大文件折叠；
- 支持横向滚动；
- 支持字号调节。

#### P0-9 命令输出查看

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

#### P0-10 设置页

设置页包含：

- Runner 管理；
- 默认 Agent；
- 默认模型；
- 审批策略；
- 字号；
- 深浅色；
- 网络超时；
- 安全设置；
- 关于项目。

### 5.2 P1 第一阶段增强项

P1 是第一阶段可以争取实现，但不影响 MVP 验收的能力。

1. 二维码配对 Runner；
2. 局域网自动发现；
3. 平板通知；
4. 多 Runner 切换；
5. 会话搜索；
6. 文件树浏览；
7. 只读文件查看；
8. 按文件回滚；
9. 按文件接受 / 拒绝修改；
10. 快捷提示词；
11. 图片上传；
12. 粘贴截图；
13. 系统分享进入；
14. 错误日志导出。

### 5.3 P2 后续能力

P2 不进入第一阶段。

1. 鸿蒙项目识别；
2. ArkTS / ArkUI 专属 Agent；
3. DevEco 报错修复；
4. module.json5 检查；
5. oh-package.json5 检查；
6. HarmonyOS 页面生成；
7. Android 转鸿蒙迁移；
8. 企业后台；
9. 多用户协作；
10. 云 Runner；
11. 应用市场商业化订阅。

---

## 6. 核心用户流程

### 6.1 首次使用流程

```text
用户打开 App
  ↓
进入欢迎页
  ↓
添加 Runner
  ↓
输入地址、端口、Token
  ↓
测试连接
  ↓
连接成功
  ↓
进入项目列表
  ↓
选择项目
  ↓
创建 AI 编程会话
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
平板端弹出审批卡片
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
平板端显示高风险命令
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

### 6.4 查看 Diff 流程

```text
任务产生文件修改
  ↓
会话页出现 Diff 卡片
  ↓
用户点击进入 Diff 页
  ↓
左侧查看文件列表
  ↓
右侧查看行级 Diff
  ↓
用户复制 / 审查 / 要求 AI 解释
```

---

## 7. 页面设计

### 7.1 平板布局原则

第一阶段以鸿蒙平板为主，不以手机为主。

设计原则：

1. 优先横屏；
2. 支持竖屏；
3. 优先双栏 / 三栏布局；
4. 会话和 Diff 不能挤在单列；
5. 大量日志默认折叠；
6. 审批卡片要醒目；
7. 代码查看要支持横向滚动；
8. 左侧导航、右侧内容；
9. 常用操作放在工具栏；
10. 不做终端式纯文本界面。

### 7.2 首页 / 工作台

首页展示：

- 当前 Runner；
- 连接状态；
- 最近项目；
- 最近会话；
- 运行中任务；
- 待审批事项；
- 快速新建会话；
- 设置入口。

布局：

```text
┌─────────────────────────────────────────────┐
│ 顶部栏：OpenCode Harmony / Runner 状态       │
├───────────────┬─────────────────────────────┤
│ 左侧导航       │ 工作台内容                    │
│ - 项目         │ - 最近任务                    │
│ - 会话         │ - 待审批                      │
│ - Runner       │ - 最近项目                    │
│ - 设置         │ - 快速开始                    │
└───────────────┴─────────────────────────────┘
```

### 7.3 Runner 管理页

功能：

- 添加 Runner；
- 编辑 Runner；
- 删除 Runner；
- 测试连接；
- 设置默认 Runner；
- 查看 Runner 状态。

字段：

- 名称；
- 地址；
- 端口；
- 协议；
- 用户名；
- 密码 / Token；
- 连接方式；
- 备注。

连接状态：

- 在线；
- 离线；
- 认证失败；
- 版本不兼容；
- 网络超时；
- 未知错误。

### 7.4 项目列表页

展示：

- 项目卡片；
- 项目路径；
- Git 分支；
- 最近会话；
- 当前状态；
- 待审批数量；
- 新建会话按钮。

平板布局：

```text
左侧：Runner / 项目筛选
右侧：项目卡片网格
```

### 7.5 会话列表页

展示：

- 会话标题；
- 项目；
- Agent；
- 模型；
- 状态；
- 最近消息；
- 更新时间。

支持：

- 按项目筛选；
- 按状态筛选；
- 搜索，P1；
- 继续会话；
- 删除本地记录，P1。

### 7.6 会话详情页

这是核心页面。

推荐三栏布局：

```text
┌──────────────┬─────────────────────────┬──────────────────┐
│ 会话列表      │ 消息与工具调用            │ 详情面板           │
│              │                         │                  │
│ Session A    │ User: 修复 bug           │ Diff / Tool / Log  │
│ Session B    │ AI: 正在分析...          │                  │
│ Session C    │ Tool: read file          │                  │
│              │ Tool: edit file          │                  │
└──────────────┴─────────────────────────┴──────────────────┘
```

竖屏时降级为双栏或单栏：

```text
会话列表 → 会话详情 → Diff 详情
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
- 附加上下文按钮；
- 快捷提示词，P1。

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

审批卡片示例：

```text
高风险操作：执行命令

命令：
npm install lodash

工作目录：
/workspace/demo

AI 说明：
需要安装 lodash 以实现当前功能。

风险：
会修改依赖文件，可能影响构建结果。

操作：
[允许一次] [拒绝] [查看详情]
```

### 7.8 Diff 页

平板双栏布局：

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
- 让 AI 解释，P1；
- 回滚，P1。

### 7.9 命令输出页

展示：

- 命令；
- stdout；
- stderr；
- exit code；
- 耗时；
- 复制按钮；
- 错误摘要；
- 重新执行，P1。

长日志处理：

- 默认只展示最后 200 行；
- 支持展开全部；
- 支持搜索，P1；
- 错误行高亮。

---

## 8. 技术架构

### 8.1 总体架构

第一阶段采用：

```text
HarmonyOS Tablet App
        ↓
Mobile API Adapter / SDK
        ↓
OpenCode Server
        ↓
OpenCode Runtime
        ↓
真实开发环境
        ↓
代码仓库 / Git / Shell / 测试 / 构建
```

### 8.2 组件职责

#### 8.2.1 HarmonyOS Tablet App

负责：

1. 原生 UI；
2. Runner 配置；
3. 项目展示；
4. 会话展示；
5. 消息输入；
6. 流式输出展示；
7. 工具调用展示；
8. 审批操作；
9. Diff 查看；
10. 命令输出查看；
11. 本地设置；
12. 安全存储；
13. 平板布局适配。

技术栈：

- ArkTS；
- ArkUI；
- Stage 模型；
- Navigation；
- List / Grid；
- SideBar / Split Layout；
- Preferences；
- HTTP 请求；
- SSE 或 WebSocket；
- 本地安全存储；
- Markdown 渲染；
- Diff 渲染；
- 代码高亮。

#### 8.2.2 Mobile API Adapter

第一阶段可以有两种做法。

##### 方案 A：鸿蒙 App 直接调用 OpenCode Server API

优点：

- 改动少；
- POC 快；
- 可以快速验证。

缺点：

- ArkTS 侧要直接适配 OpenCode API；
- OpenCode API 变化会影响客户端；
- 移动端需要的数据可能不够聚合；
- 审批、Diff、工具调用状态可能需要额外封装。

适合：

- POC；
- 第一阶段前半段。

##### 方案 B：新增 Mobile Gateway

优点：

- API 更稳定；
- 适合移动端；
- 可以聚合数据；
- 可以做鉴权；
- 可以做事件转换；
- 可以做审批状态统一；
- 后续可支持 iOS / Android / Web 管理端；
- 可为企业版打基础。

缺点：

- 需要额外开发；
- 初期工作量更大。

推荐：

> **POC 用方案 A，MVP 用方案 B。**

#### 8.2.3 OpenCode Server / Runner

负责：

1. Agent 执行；
2. 模型调用；
3. 文件读写；
4. 命令执行；
5. Git 操作；
6. LSP；
7. Diff；
8. 会话状态；
9. 工具调用；
10. 权限策略。

Runner 运行位置：

- 开发者电脑；
- 局域网服务器；
- 云服务器；
- 企业内网机器；
- 容器环境。

---

## 9. OpenCode 技术框架怎么改

### 9.1 改造原则

第一阶段不重写 OpenCode Core。

改造原则：

1. 保留 OpenCode 原有 CLI / TUI / Desktop 能力；
2. 保留 OpenCode Server 作为执行核心；
3. 新增鸿蒙平板原生客户端；
4. 新增移动端适配层；
5. 所有高风险执行仍在 Runner 端；
6. 平板端不直接读写代码仓库；
7. 平板端不直接执行 shell；
8. 平板端不保存完整代码仓库；
9. 平板端只保存连接信息、会话摘要、用户偏好；
10. 第二阶段再做鸿蒙语义增强。

### 9.2 推荐仓库结构

有两种仓库组织方式。

#### 方案 A：在 OpenCode fork 中增加子项目

```text
opencode/
  packages/
    opencode-core/
    opencode-server/
    opencode-tui/
    opencode-web/
    mobile-gateway/
    mobile-sdk/
  apps/
    harmony-tablet/
```

优点：

- 和 OpenCode 改造绑定；
- 类型共享方便；
- 后续可统一构建。

缺点：

- 可能影响上游同步；
- HarmonyOS 工程结构和 Node monorepo 混在一起；
- DevEco Studio 体验可能一般。

#### 方案 B：单独建鸿蒙客户端仓库

```text
opencode-harmony-tablet/
  apps/
    harmony-tablet/
  packages/
    mobile-sdk/
    shared-types/
    gateway/
  docs/
    prd/
    api/
    deployment/
```

优点：

- 清晰；
- 不污染 OpenCode 主仓；
- 方便 DevEco Studio 开发；
- 可以独立发布；
- 方便未来做商业化。

缺点：

- 需要通过 API 与 OpenCode 同步；
- 类型共享要额外生成。

推荐：

> **第一阶段采用方案 B：单独建仓。**

等稳定后，再决定是否向 OpenCode fork 合并适配层。

### 9.3 技术改造模块

第一阶段需要新增四个模块：

```text
1. HarmonyOS 原生客户端
2. Mobile SDK
3. Mobile Gateway
4. Runner 启动与配对脚本
```

#### 9.3.1 HarmonyOS 原生客户端

目录建议：

```text
apps/harmony-tablet/
  AppScope/
  entry/
    src/main/ets/
      app/
        App.ets
        Route.ets

      pages/
        WelcomePage.ets
        RunnerListPage.ets
        RunnerSetupPage.ets
        HomePage.ets
        ProjectListPage.ets
        SessionListPage.ets
        SessionPage.ets
        ApprovalCenterPage.ets
        DiffPage.ets
        CommandOutputPage.ets
        SettingsPage.ets

      components/
        RunnerCard.ets
        ProjectCard.ets
        SessionCard.ets
        ChatMessage.ets
        ToolCallCard.ets
        ApprovalCard.ets
        DiffViewer.ets
        FileChangeList.ets
        CommandOutputCard.ets
        CodeBlock.ets
        StatusBadge.ets
        RiskBadge.ets
        SplitPane.ets
        TabletNavigation.ets

      services/
        ApiClient.ets
        RunnerService.ets
        ProjectService.ets
        SessionService.ets
        EventStreamService.ets
        ApprovalService.ets
        DiffService.ets
        CommandService.ets
        StorageService.ets
        SecurityService.ets
        SettingsService.ets

      models/
        Runner.ets
        Project.ets
        Session.ets
        Message.ets
        ToolCall.ets
        Approval.ets
        Diff.ets
        CommandOutput.ets
        Agent.ets
        Model.ets

      utils/
        format/
        diff/
        markdown/
        codeHighlight/
        logger/
        network/
        security/
```

#### 9.3.2 Mobile SDK

作用：

- 封装 OpenCode / Gateway API；
- 为 ArkTS 客户端提供类型；
- 处理 HTTP 请求；
- 处理鉴权；
- 处理 SSE / WebSocket；
- 处理错误码；
- 处理重连。

目录建议：

```text
packages/mobile-sdk/
  src/
    client.ts
    types.ts
    errors.ts
    events.ts
    auth.ts
    projects.ts
    sessions.ts
    approvals.ts
    diff.ts
    commands.ts
```

注意：

ArkTS 不能简单照搬 Node 端 SDK，需要做适配：

1. 避免依赖 Node API；
2. 避免依赖浏览器专属 API；
3. 使用 HarmonyOS 网络能力；
4. 类型可以从 OpenAPI 生成后再转换；
5. SSE 需要在 ArkTS 中单独封装；
6. WebSocket 可以作为事件流备选方案。

#### 9.3.3 Mobile Gateway

作用：

- 给平板端提供稳定 API；
- 聚合 OpenCode Server 原始数据；
- 处理认证；
- 处理 Runner 配对；
- 处理事件流；
- 标准化工具调用；
- 标准化审批；
- 标准化 Diff；
- 隐藏 OpenCode 内部 API 变化。

目录建议：

```text
packages/gateway/
  src/
    index.ts
    config.ts
    auth/
      basicAuth.ts
      token.ts
      pair.ts
    opencode/
      client.ts
      adapter.ts
      events.ts
      sessions.ts
      projects.ts
      diff.ts
      approvals.ts
    routes/
      health.ts
      runners.ts
      projects.ts
      sessions.ts
      messages.ts
      events.ts
      approvals.ts
      diff.ts
      commands.ts
    security/
      risk.ts
      mask.ts
      policy.ts
    utils/
      logger.ts
      errors.ts
```

#### 9.3.4 Runner 启动与配对脚本

为了让用户更容易使用，需要提供 Runner 启动脚本。

示例：

```bash
opencode-harmony-runner start \
  --host 0.0.0.0 \
  --port 4096 \
  --project /path/to/project \
  --password your-password
```

或者：

```bash
OPENCODE_SERVER_PASSWORD=your-password opencode serve --hostname 0.0.0.0 --port 4096 --mdns
```

第一阶段至少提供文档说明：

1. 如何在电脑上启动 OpenCode Server；
2. 如何让鸿蒙平板连接；
3. 局域网 IP 怎么找；
4. 密码怎么设置；
5. 端口怎么开放；
6. 常见连接失败怎么排查。

---

## 10. API 设计

### 10.1 API 设计原则

第一阶段 API 设计原则：

1. 平板端不直接理解 OpenCode 内部复杂结构；
2. Gateway 给平板端返回移动端友好的数据；
3. 事件统一通过 SSE 或 WebSocket 推送；
4. 审批事件必须可被平板端处理；
5. Diff 数据要支持按文件加载；
6. 命令输出要支持分页或截断；
7. 错误码要统一；
8. 支持断线重连。

### 10.2 健康检查

```http
GET /mobile/health
```

返回：

```json
{
  "healthy": true,
  "version": "0.1.0",
  "runnerVersion": "1.16.2",
  "serverTime": 1780000000
}
```

### 10.3 Runner 能力

```http
GET /mobile/capabilities
```

返回：

```json
{
  "projects": true,
  "sessions": true,
  "streaming": true,
  "tools": true,
  "approval": true,
  "diff": true,
  "commands": true,
  "models": true,
  "agents": true
}
```

### 10.4 项目列表

```http
GET /mobile/projects
```

返回：

```json
[
  {
    "id": "project_001",
    "name": "demo-project",
    "path": "/workspace/demo-project",
    "branch": "main",
    "status": "idle",
    "pendingApprovals": 0,
    "runningSessions": 0,
    "updatedAt": 1780000000
  }
]
```

### 10.5 会话列表

```http
GET /mobile/sessions?projectId=project_001
```

返回：

```json
[
  {
    "id": "session_001",
    "projectId": "project_001",
    "title": "修复登录 bug",
    "agent": "build",
    "model": "claude-sonnet",
    "status": "running",
    "lastMessage": "正在分析 src/auth.ts",
    "createdAt": 1780000000,
    "updatedAt": 1780000000
  }
]
```

### 10.6 创建会话

```http
POST /mobile/sessions
```

请求：

```json
{
  "projectId": "project_001",
  "agent": "build",
  "model": "claude-sonnet",
  "title": "修复登录 bug",
  "initialMessage": "帮我修复登录失败的问题"
}
```

返回：

```json
{
  "id": "session_001",
  "projectId": "project_001",
  "status": "running"
}
```

### 10.7 发送消息

```http
POST /mobile/sessions/{sessionId}/messages
```

请求：

```json
{
  "content": "继续，先给我修改计划",
  "mode": "normal"
}
```

### 10.8 会话事件流

```http
GET /mobile/sessions/{sessionId}/events
```

事件类型：

```ts
type MobileSessionEvent =
  | { type: "message.delta"; data: MessageDelta }
  | { type: "message.done"; data: Message }
  | { type: "tool.start"; data: ToolCall }
  | { type: "tool.update"; data: ToolCall }
  | { type: "tool.done"; data: ToolCall }
  | { type: "approval.required"; data: ApprovalRequest }
  | { type: "approval.resolved"; data: ApprovalResult }
  | { type: "diff.updated"; data: DiffSummary }
  | { type: "command.output"; data: CommandOutput }
  | { type: "session.done"; data: SessionResult }
  | { type: "session.error"; data: ErrorInfo }
```

### 10.9 审批接口

```http
GET /mobile/approvals
POST /mobile/approvals/{approvalId}/approve
POST /mobile/approvals/{approvalId}/reject
POST /mobile/approvals/{approvalId}/approve-once
```

审批请求数据：

```json
{
  "id": "approval_001",
  "sessionId": "session_001",
  "type": "bash",
  "title": "执行命令",
  "description": "AI 想运行 npm test 验证修复结果",
  "riskLevel": "medium",
  "payload": {
    "command": "npm test",
    "cwd": "/workspace/demo-project"
  },
  "status": "pending"
}
```

### 10.10 Diff 接口

```http
GET /mobile/sessions/{sessionId}/diff
GET /mobile/sessions/{sessionId}/diff/files/{fileId}
```

Diff 摘要返回：

```json
{
  "sessionId": "session_001",
  "filesChanged": 3,
  "insertions": 45,
  "deletions": 12,
  "files": [
    {
      "id": "file_001",
      "path": "src/auth.ts",
      "status": "modified",
      "insertions": 20,
      "deletions": 5
    }
  ]
}
```

单文件 Diff 返回：

```json
{
  "fileId": "file_001",
  "path": "src/auth.ts",
  "status": "modified",
  "patch": "@@ -1,5 +1,8 @@\n..."
}
```

### 10.11 命令输出接口

```http
GET /mobile/sessions/{sessionId}/commands
GET /mobile/commands/{commandId}
```

返回：

```json
{
  "id": "cmd_001",
  "sessionId": "session_001",
  "command": "npm test",
  "cwd": "/workspace/demo-project",
  "status": "success",
  "stdout": "...",
  "stderr": "",
  "exitCode": 0,
  "startedAt": 1780000000,
  "endedAt": 1780000010
}
```

---

## 11. 数据模型

### 11.1 Runner

```ts
interface Runner {
  id: string
  name: string
  baseUrl: string
  protocol: "http" | "https"
  status: "online" | "offline" | "auth_failed" | "timeout" | "version_mismatch"
  version?: string
  lastConnectedAt?: number
  createdAt: number
  updatedAt: number
}
```

### 11.2 Project

```ts
interface Project {
  id: string
  name: string
  path: string
  branch?: string
  status: "idle" | "running" | "approval_required" | "error"
  pendingApprovals: number
  runningSessions: number
  lastSessionId?: string
  updatedAt: number
}
```

### 11.3 Session

```ts
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

```ts
interface Message {
  id: string
  sessionId: string
  role: "user" | "assistant" | "system" | "tool"
  content: string
  createdAt: number
}
```

### 11.5 ToolCall

```ts
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

```ts
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

```ts
interface DiffSummary {
  sessionId: string
  filesChanged: number
  insertions: number
  deletions: number
  files: DiffFile[]
}
```

### 11.8 DiffFile

```ts
interface DiffFile {
  id: string
  path: string
  status: "added" | "modified" | "deleted" | "renamed"
  insertions: number
  deletions: number
}
```

---

## 12. 安全策略

### 12.1 安全原则

第一阶段必须遵守：

1. 平板端不保存完整代码仓库；
2. 平板端不保存模型 API Key；
3. 平板端不直接执行命令；
4. 高风险操作必须审批；
5. Token 不明文展示；
6. Token 不进入日志；
7. 敏感信息默认脱敏；
8. Runner 连接必须可删除；
9. 支持断开连接；
10. 支持清空本地缓存。

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
rm -rf
sudo
chmod -R
chown -R
curl | bash
wget | bash
git reset --hard
git push --force
npm publish
pnpm publish
docker rm
docker system prune
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

平板端允许保存：

- Runner 名称；
- Runner 地址；
- Token / 密码的加密结果；
- 用户偏好；
- 最近会话摘要；
- UI 设置。

平板端不保存：

- 完整代码仓库；
- 完整项目文件；
- 模型 API Key；
- SSH 私钥；
- `.env` 明文；
- 数据库连接串；
- 企业密钥。

---

## 13. 非功能需求

### 13.1 性能

| 指标 | 要求 |
|---|---|
| App 冷启动 | 3 秒内进入首页 |
| Runner 连接测试 | 5 秒内返回结果或超时 |
| 会话消息发送反馈 | 1 秒内显示发送状态 |
| 流式输出首 token | 3 秒内出现，取决于模型 |
| 1000 条消息滚动 | 不明显卡顿 |
| 1MB Diff 展示 | 3 秒内完成首屏渲染 |
| 长日志展示 | 默认截断，避免卡死 |

### 13.2 稳定性

要求：

1. 网络断开要提示；
2. 断线后可重连；
3. 会话事件流断开后可恢复；
4. Runner 离线不应导致 App 崩溃；
5. 大 Diff 不应导致页面卡死；
6. 长命令输出不应导致内存暴涨；
7. Token 失效应提示重新认证。

### 13.3 兼容性

第一阶段主要适配：

1. HarmonyOS 平板；
2. 横屏；
3. 竖屏；
4. 深色模式；
5. 浅色模式。

后续再适配：

1. 手机；
2. 折叠屏；
3. PC 形态；
4. 多设备流转。

### 13.4 可维护性

要求：

1. API 层独立；
2. 业务服务层独立；
3. UI 组件化；
4. 模型类型集中管理；
5. Gateway 与 OpenCode 解耦；
6. 错误码统一；
7. 日志统一；
8. 方便后续增加鸿蒙专项能力。

---

## 14. 详细开发计划

### 14.1 阶段 0：技术验证

周期：1 周

目标：

验证鸿蒙原生 App 能连接 OpenCode Server，并完成最小会话。

任务：

1. 拉取 OpenCode；
2. 本地启动 OpenCode Server；
3. 确认 health API；
4. 确认项目 API；
5. 确认会话 API；
6. 确认事件流 API；
7. 创建 HarmonyOS ArkTS 工程；
8. 实现 Runner 配置页；
9. 实现连接测试；
10. 实现发送一条消息；
11. 实现接收 AI 回复；
12. 输出 API 差距清单。

交付物：

- POC App；
- 技术验证报告；
- API 差距清单；
- 风险清单。

验收：

- 鸿蒙平板 App 可安装；
- 可输入 Runner 地址；
- 可连接 OpenCode Server；
- 可发送消息；
- 可接收回复。

### 14.2 阶段 1：平板原生框架

周期：2 周

目标：

完成平板原生客户端基础框架。

任务：

1. 首页工作台；
2. Runner 管理；
3. 项目列表；
4. 会话列表；
5. 页面路由；
6. 平板双栏布局；
7. 本地存储；
8. 安全存储；
9. 深浅色；
10. 基础错误提示；
11. 网络请求封装；
12. 模型类型定义。

交付物：

- 可用 App 框架；
- Runner 管理；
- 项目 / 会话页面；
- 基础设置页。

验收：

- 主 UI 为 ArkTS / ArkUI 原生实现；
- 不使用 WebView 作为主界面；
- 可管理 Runner；
- 可查看项目；
- 可查看会话。

### 14.3 阶段 2：AI 会话和流式输出

周期：2 周

目标：

完成 AI 编程会话核心交互。

任务：

1. 创建会话；
2. 发送消息；
3. 接收流式输出；
4. Markdown 渲染；
5. 代码块渲染；
6. 停止任务；
7. 重试任务；
8. 会话状态同步；
9. Agent 选择；
10. 模型选择；
11. 事件流重连；
12. 错误状态展示。

交付物：

- 完整会话页；
- 可用 AI 对话；
- 可流式展示输出。

验收：

- 用户能在平板上发起 AI 编程任务；
- AI 回复可以流式展示；
- 用户可以停止任务；
- 用户可以继续历史会话。

### 14.4 阶段 3：工具调用和审批

周期：2-3 周

目标：

完成 AI 编程安全闭环。

任务：

1. 工具调用事件解析；
2. 工具调用卡片；
3. 审批请求卡片；
4. 审批中心；
5. 批准 / 拒绝 API；
6. 风险等级；
7. 高风险命令识别；
8. 文件修改审批；
9. 命令执行审批；
10. 审批结果同步；
11. 审批失败处理；
12. 操作日志。

交付物：

- 工具调用展示；
- 权限审批流程；
- 风险提示。

验收：

- AI 修改文件前可审批；
- AI 执行命令前可审批；
- 用户拒绝后 AI 不应继续执行该操作；
- 审批状态能实时同步到会话页。

### 14.5 阶段 4：Diff 和命令输出

周期：2 周

目标：

完成代码修改审查能力。

任务：

1. Diff 摘要接口；
2. 单文件 Diff 接口；
3. 文件变更列表；
4. 行级 Diff Viewer；
5. 代码高亮；
6. 大文件折叠；
7. 命令输出卡片；
8. 命令详情页；
9. stdout / stderr 展示；
10. exit code 展示；
11. 日志截断；
12. 复制能力。

交付物：

- Diff 页；
- 命令输出页；
- 代码审查能力。

验收：

- 用户能看清 AI 改了哪些文件；
- 用户能查看行级变更；
- 用户能查看测试和构建输出；
- 大 Diff 不导致页面卡死。

### 14.6 阶段 5：稳定性和发布准备

周期：1-2 周

目标：

完成第一阶段可用版本。

任务：

1. 真机测试；
2. 横竖屏测试；
3. 弱网测试；
4. Runner 离线测试；
5. Token 失效测试；
6. 大会话测试；
7. 大 Diff 测试；
8. 崩溃修复；
9. UI 细节优化；
10. 安装包构建；
11. 使用文档；
12. 部署文档。

交付物：

- 第一阶段 Beta 包；
- 测试报告；
- 用户使用文档；
- Runner 部署文档。

验收：

- 可在鸿蒙平板上稳定完成 AI 编程闭环；
- 核心功能无阻塞 bug；
- 有完整使用说明。

---

## 15. 总排期

| 阶段 | 周期 | 目标 |
|---|---:|---|
| 阶段 0：技术验证 | 1 周 | 跑通鸿蒙 App 连接 OpenCode |
| 阶段 1：平板原生框架 | 2 周 | 完成基础 App 框架 |
| 阶段 2：AI 会话和流式输出 | 2 周 | 完成 AI 编程会话 |
| 阶段 3：工具调用和审批 | 2-3 周 | 完成安全操作闭环 |
| 阶段 4：Diff 和命令输出 | 2 周 | 完成代码审查能力 |
| 阶段 5：稳定和发布 | 1-2 周 | 形成可用 Beta |

总周期：

**8-10 周完成 MVP。**

如果团队较小，可能需要：

**10-12 周。**

---

## 16. 人员配置

### 16.1 最小团队

| 角色 | 人数 | 职责 |
|---|---:|---|
| 产品经理 | 1 | PRD、流程、验收 |
| HarmonyOS 工程师 | 1 | ArkTS / ArkUI 客户端 |
| TypeScript 工程师 | 1 | Gateway / OpenCode API 适配 |
| 测试 | 0.5 | 真机测试、回归 |
| UI 设计 | 0.5 | 平板布局和视觉 |

### 16.2 推荐团队

| 角色 | 人数 |
|---|---:|
| 产品经理 | 1 |
| HarmonyOS 工程师 | 2 |
| TypeScript / Node 工程师 | 1-2 |
| UI/UX 设计师 | 1 |
| QA | 1 |

---

## 17. 验收标准

### 17.1 第一阶段最终验收流程

用户在鸿蒙平板上应能完成：

1. 安装 App；
2. 添加 Runner；
3. 成功连接 Runner；
4. 查看项目；
5. 创建 AI 编程会话；
6. 输入需求；
7. AI 能读取项目并返回分析；
8. AI 能请求修改代码；
9. 平板端能显示审批；
10. 用户能批准或拒绝；
11. AI 执行修改；
12. 用户能查看 Diff；
13. 用户能查看命令输出；
14. 用户能停止或重试任务；
15. 任务完成后能查看会话历史。

### 17.2 功能验收

| 模块 | 验收要求 |
|---|---|
| Runner | 可添加、编辑、删除、测试连接 |
| 项目 | 可展示项目或当前工作区 |
| 会话 | 可创建、继续、停止、重试 |
| 消息 | 可发送文本，可流式展示 AI 回复 |
| 工具 | 可展示 AI 工具调用过程 |
| 审批 | 可批准 / 拒绝高风险操作 |
| Diff | 可展示文件列表和行级变更 |
| 命令 | 可展示 stdout / stderr / exit code |
| 设置 | 可配置默认 Agent、模型、主题 |
| 安全 | Token 不明文展示，高风险操作不自动执行 |

### 17.3 原生体验验收

必须满足：

1. 主界面不是 WebView；
2. 使用 ArkTS / ArkUI；
3. 支持平板横屏；
4. 支持平板竖屏；
5. 支持双栏布局；
6. 支持深浅色；
7. 支持触控操作；
8. 长文本和大 Diff 不明显卡顿。

---

## 18. 风险与应对

### 18.1 OpenCode API 变化风险

风险：

OpenCode Server API 变化可能导致鸿蒙客户端不可用。

应对：

1. 固定支持的 OpenCode 版本；
2. 新增 Mobile Gateway；
3. Gateway 内部适配 OpenCode API；
4. 鸿蒙 App 只依赖 Mobile API；
5. 增加版本检查。

### 18.2 平板端显示复杂代码风险

风险：

Diff 和长日志在平板上展示困难。

应对：

1. 文件列表 + 单文件 Diff；
2. 默认折叠大文件；
3. 日志默认截断；
4. 支持横向滚动；
5. 支持字号调节；
6. 支持只看变更片段。

### 18.3 安全风险

风险：

AI 可能执行危险命令或错误修改文件。

应对：

1. 默认审批；
2. 高风险命令识别；
3. 删除文件必须审批；
4. Git 操作必须审批；
5. 依赖安装必须审批；
6. 审批结果可追踪。

### 18.4 本地运行误区

风险：

团队尝试把 OpenCode Core 完整塞进鸿蒙本地，导致项目失控。

应对：

1. 第一阶段明确不做本地 Core；
2. Runner 负责执行；
3. 平板端负责交互；
4. 后续再评估本地轻量能力。

### 18.5 WebView 套壳风险

风险：

为了快，做成 WebView 套壳，产品体验差。

应对：

1. 主界面必须 ArkTS / ArkUI；
2. WebView 只能用于文档预览；
3. 会话、审批、Diff 必须原生实现。

---

## 19. 第一阶段交付物

必须交付：

1. HarmonyOS 平板 App 安装包；
2. OpenCode Runner 启动说明；
3. Mobile Gateway，若采用；
4. Mobile API 文档；
5. 使用手册；
6. 测试报告；
7. 已知问题清单；
8. 后续路线图。

---

## 20. 后续路线，但不进入第一阶段

第二阶段可以做：

1. 鸿蒙项目识别；
2. ArkTS / ArkUI Agent；
3. DevEco 报错修复；
4. HarmonyOS 项目模板；
5. 鸿蒙页面生成；
6. module.json5 检查；
7. oh-package.json5 检查；
8. 折叠屏适配建议。

第三阶段可以做：

1. 企业版；
2. 私有模型；
3. SSO；
4. 审计后台；
5. 多人协作；
6. GitLab / Gitee 集成；
7. CI/CD 集成；
8. 云 Runner。

---

## 21. 参考依据

1. OpenCode 官方文档：OpenCode 是开源 AI coding agent，提供 terminal-based interface、desktop app 和 IDE extension。  
   URL: https://opencode.ai/docs/

2. OpenCode Server 官方文档：`opencode serve` 会启动 headless HTTP server，并暴露 OpenAPI endpoint；TUI 本身是 client，server 暴露 OpenAPI 3.1，支持多客户端和程序化交互。  
   URL: https://opencode.ai/docs/server/

3. OpenHarmony ArkTS UI 开发文档：ArkTS 声明式 UI 开发范式用于构建 UI、组件、布局、状态管理、导航、动画和交互等能力。  
   URL: https://gitee.com/openharmony/docs/blob/master/zh-cn/application-dev/ui/arkts-ui-development-overview.md

---

## 22. 最终定版描述

第一阶段立项标题建议：

> **OpenCode for HarmonyOS Tablet 第一阶段：鸿蒙平板原生 AI 编程客户端**

核心技术决策写死：

1. **第一阶段不做 OpenCode Core 本地化移植，采用鸿蒙原生客户端 + OpenCode Runner 执行端架构。**
2. **第一阶段不做鸿蒙语义增强，先完成 AI 编程基础闭环：会话、工具、审批、Diff、命令输出。**

一句话总结：

> **第一阶段先做到“移植能用”，让鸿蒙平板成为 OpenCode 的原生 AI 编程操作台。**
