# Native Process Log Queue

## 为什么改

旧代码在 C++ reader thread 里直接调用 JS callback：

```text
reader thread → napi_call_function(callback)
```

这不安全，容易导致线程问题、崩溃或卡顿。

## 新方案

```text
reader thread
→ ProcessManager.appendLog(pid,line)
→ ArkTS ProcessBridge.drainLogs(pid)
→ UI 更新日志
```

## 接口

ArkTS：

```ts
ProcessBridge.drainLogs(pid): string[]
```

C++：

```cpp
std::vector<std::string> ProcessManager::drainLogs(int pid)
```

## 使用位置

`ServerSettingsPage.collectProcessLogs()` 会在：

```text
检测前
停止前
启动等待过程中
health 轮询过程中
```

主动收集日志。
