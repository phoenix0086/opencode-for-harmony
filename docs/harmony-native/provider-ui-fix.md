# Provider UI Fix Implementation Notes

## 建议先做

1. 覆盖 3 个文件。
2. 清理 DevEco build。
3. 重新构建。
4. 打开 Provider 页面测试。

## 注意

如果之前 App 已运行过，旧 Provider 列表可能在本地 preferences 中。
需要卸载 App 或调用 `storageService.clearAll()` 清缓存。

## 表单示例

DeepSeek：

```text
Provider ID: deepseek-cn
显示名称: DeepSeek
基础 URL: https://api.deepseek.com
API Key: sk-xxxx
模型:
  deepseek-chat / DeepSeek Chat
```

Qwen：

```text
Provider ID: qwen-cn
显示名称: 通义千问
基础 URL: https://dashscope.aliyuncs.com/compatible-mode/v1
模型:
  qwen-plus / Qwen Plus
```
