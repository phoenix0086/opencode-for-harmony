/**
 * 安全的错误对象转字符串工具
 *
 * 问题背景：ArkTS 中 `String(e)` 对 Error 对象返回 "[object Object]"，
 * 对 Record<string, Object> 类型也只会调用 Object.prototype.toString，
 * 用户看到的错误信息完全不可读。
 *
 * 用法：在所有错误 catch 块中：
 *   } catch (e) {
 *     Logger.error(`xxx 失败: ${errStr(e)}`)
 *   }
 *
 * 替换之前散落在 MainViewModel.errStr 和 OpenCodeClient.errorToString
 * 的两份重复实现。
 */
export function errStr(e: Object | undefined | null): string {
  if (e === undefined || e === null) return ''
  if (typeof e === 'string') return e
  // Error / BusinessError 对象有 message/code 字段
  if (typeof e === 'object') {
    const rec = e as Record<string, Object>
    const msg = rec['message']
    if (typeof msg === 'string' && msg.length > 0) {
      const code = rec['code']
      if (typeof code === 'number' && code !== 0) {
        return `code ${code}: ${msg}`
      }
      return msg
    }
    // 业务自定义 Result-style 错误对象
    const errField = rec['error']
    if (typeof errField === 'string' && errField.length > 0) return errField
    // 尝试 JSON 序列化，失败时回退到 String(e)
    try {
      const s = JSON.stringify(e)
      if (s && s.length > 0 && s !== '{}') return s
    } catch (_) {
      // ignore
    }
  }
  return String(e)
}
