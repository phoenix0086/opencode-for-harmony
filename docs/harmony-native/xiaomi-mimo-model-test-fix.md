# 小米 MiMo API 显示报错的原因

截图里真正的错误是：

```text
OpenCode Server is not connected.
```

这不是小米 API Key 或小米模型 ID 本身报错。

当前逻辑是：

```text
ModelSettingsPage
→ 点击“测试”
→ ModelSelectionService.testModel()
→ 需要 activeRunner / OpenCode Server
→ 如果没有连接 opencode serve，就直接返回 Server not connected
```

也就是说：

```text
你已经把 MiMo 模型保存到了本地 ProviderRegistry，
所以模型页能看到 MiMo v2.5 / MiMo v2.5 Pro。
但它还没有同步到真实 OpenCode Server，
也没有通过 OpenCode Server 发起模型测试。
```

## 修复

本补丁修改了：

```text
ModelSelectionService.ets
ModelSettingsPage.ets
```

新的行为：

1. Server 未连接时：
   - 设默认 / 设 small 只保存本地
   - 明确提示“暂未同步到服务端”
   - 测试按钮提示“请先连接 OpenCode Server”

2. Server 已连接时：
   - 设默认 / 设 small 会 PATCH /config
   - 测试模型会先 PATCH /config model=modelRef
   - 然后创建临时 session
   - 发送 Say OK
```

## 正确测试步骤

```bash
opencode serve --port 4096 --hostname 0.0.0.0
```

然后在 App 的服务器页连接该 server。

再回到模型页测试：

```text
xiaomi-mimo/mimo-v2.5-pro
xiaomi-mimo/mimo-v2.5
```

如果还是失败，再看返回的 HTTP 错误和 OpenCode Server 日志。
