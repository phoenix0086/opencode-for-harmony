# Provider / Model 功能重做文档

## 目标

把 Provider / Model 从“后台配置页”改为 OpenCode Desktop 风格的连接流程。

## 产品原则

```text
Provider 页 = 接入 API 服务商
Model 页 = 选择使用哪个模型
Config/Auth = 底层实现，不直接暴露给普通用户
```

## 用户流程

```text
设置 → 提供商 → 连接 → 自定义提供商弹窗 → 填信息 → 提交 → 写本地 + 写 OpenCode Server → 刷新 connected → 模型页选默认模型
```

## Provider 页

Provider 页展示两块：

1. 已连接的提供商
2. 热门提供商

热门提供商包括：

- DeepSeek
- 通义千问 / 阿里百炼
- 智谱 GLM
- Kimi / Moonshot
- MiniMax
- SiliconFlow
- 自定义 OpenAI Compatible

## Provider 连接弹窗

字段：

```text
providerId
displayName
baseURL
apiKey
models[]
headers[]
```

提交后执行：

```text
1. 校验字段
2. 保存 ProviderRegistry
3. PATCH /config 写 provider 配置
4. PUT /auth/:providerID 写 API Key
5. GET /provider 检查 connected
6. 成功后跳转 ModelSettingsPage
```

## Model 页

Model 页负责：

```text
1. 展示已连接 Provider 下的模型
2. 设置 default model
3. 设置 small_model
4. 测试模型
```

## 安全要求

```text
API Key 不明文显示
Header value 不明文显示
配置预览默认脱敏
日志不打印 API Key
Smoke Test 文档不记录 API Key
```
