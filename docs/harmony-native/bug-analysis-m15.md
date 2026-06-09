# M15 Bug Analysis

这次同步后主入口切到了新的 `MainViewModel + HttpService + Index` 简化架构，之前的 AgentResponsePoller / AgentExecutionInspector 不一定接到了当前 UI 主流程。

主要问题：

1. 默认 Runtime 地址还是 `http://localhost:3000`，应该是 `http://127.0.0.1:4096`。
2. `Constants.API_MESSAGE = /message`，但 OpenCode 发送应走 `/session/:id/prompt_async`。
3. 发送后依赖 `/ws` 的 `message.complete`，如果事件不匹配就会一直 generating。
4. `loadSessions()` 和 `loadProviders()` 假设返回 `{sessions:[]}` / `{providers:[]}`，但 OpenCode 可能直接返回数组或 `{all:[], connected:[]}`。
5. error/tool part 没有可靠进入 UI，用户会误以为 AI 没响应。

本补丁通过轮询 `/session/:id/message` 让发送闭环稳定下来。
