# Runtime 原生验证报告

## 目标

验证鸿蒙 App 是否可以由外置连接 OpenCode Server 进展到内置管理 OpenCode Runtime。

## 阶段定义

### 阶段一：外置连接（当前实现）

用户手动在电脑上运行 `opencode serve`，鸿蒙 App 仅做连接检测和状态管理。

**实现状态：已完成**

- 健康检查：`GET /global/health`
- 自动重连：EventStreamClient 指数退避重连
- 状态显示：在线/离线/未知
- Runner 管理：添加/删除/切换

### 阶段二：App 启动本机 OpenCode

鸿蒙 App 检测已安装的 opencode 二进制并启动 serve 进程。

**验证结论：需要进一步测试**

需要在 HarmonyOS 真机或模拟器上验证：

1. ArkTS 是否能通过 `process` 模块执行外部命令
2. 是否能读取子进程 stdout/stderr
3. 是否能发送信号停止子进程
4. 沙箱权限是否允许
5. 端口冲突如何处理

**替代方案：**

- 使用 Native C++ (NAPI) 模块实现进程管理
- 使用 Extension Ability 做后台服务
- 使用 HAP 内置二进制 + 解压安装

### 阶段三：随包内置 Sidecar

鸿蒙 App 内置 OpenCode runtime 二进制文件。

**验证结论：不建议第一阶段尝试**

风险：

1. HarmonyOS 沙箱对可执行文件有严格限制
2. OpenCode runtime 依赖 Node.js/Bun，体积大
3. 需要处理多架构（ARM64）
4. 自动更新机制复杂
5. 可能违反应用市场审核规则

## 当前建议

**第一阶段 MVP：使用外置 OpenCode Server**

启动指南：

```bash
# 安装 OpenCode
curl -fsSL https://opencode.ai/install | bash

# 进入项目目录
cd /path/to/your/project

# 启动 Server（局域网可访问）
opencode serve --port 4096 --hostname 0.0.0.0

# 带密码保护
OPENCODE_SERVER_PASSWORD=your-password opencode serve --port 4096 --hostname 0.0.0.0
```

平板配置：

1. 确保平板和电脑在同一网络
2. 在"服务器"页面添加 Runner
3. 地址填电脑的局域网 IP
4. 端口填 4096
5. 密码填设置的密码（如果有）

## 下一步

1. 在 HarmonyOS 真机上测试进程执行能力
2. 评估 NAPI 进程管理方案
3. 如果可行，实现阶段二能力
4. 输出最终技术报告
