# Provider / Model Smoke Test

## 准备

启动 OpenCode Server：

```bash
opencode serve --port 4096 --hostname 0.0.0.0
```

## DeepSeek 流程

1. 打开 App。
2. 进入“提供商”。
3. 点击 DeepSeek 的“连接”。
4. 确认预填：
   - providerId: deepseek-cn
   - baseURL: https://api.deepseek.com
   - models: deepseek-chat, deepseek-reasoner
5. 填 API Key。
6. 提交。
7. 预期：
   - 本地 ProviderRegistry 保存成功
   - PATCH /config 成功
   - PUT /auth/deepseek-cn 成功
   - GET /provider connected 包含 deepseek-cn
   - 跳转模型页
8. 在模型页设置：
   - default model: deepseek-cn/deepseek-chat
   - small_model: deepseek-cn/deepseek-chat

## Qwen 流程

1. 点击 Qwen 的“连接”。
2. 填 DashScope API Key。
3. 提交。
4. 设置 default model 为：
   - qwen-cn/qwen3-coder-plus

## 验收

```text
Provider 连接成功
模型页能看到模型
默认模型能保存
不展示 API Key 明文
OpenCode Server 能收到 config/auth 更新
```
