/**
 * 日期时间工具
 *
 * 核心问题：opencode server 在没收到 title 时会自动生成
 *   "New session - 2026-06-09T02:30:58.985Z"
 * 这是 UTC ISO 8601 字符串。HarmonyOS 设备在 Asia/Shanghai (UTC+8) 直接
 * 显示会让用户以为是凌晨 2:30 创建的，体感对不上。
 *
 * 这里的两个函数：
 * - formatLocalSessionTitle(): 在 app 端创建 session 时调用，传入
 *   本地时间字符串，server 就不会再自动生成 UTC 标题。
 * - formatServerTitle(): 渲染旧 session 时调用，检测 "New session - " + UTC
 *   后缀的格式，转成本地时间显示。
 */

const UTC_TITLE_PREFIX: string = 'New session - '

/**
 * 返回 "新会话 2026-06-09 10:30:58" 形式的本地时间标题
 */
export function formatLocalSessionTitle(prefix: string): string {
  const d: Date = new Date()
  const y: string = String(d.getFullYear())
  const mo: string = pad2(d.getMonth() + 1)
  const da: string = pad2(d.getDate())
  const h: string = pad2(d.getHours())
  const mi: string = pad2(d.getMinutes())
  const s: string = pad2(d.getSeconds())
  return `${prefix} ${y}-${mo}-${da} ${h}:${mi}:${s}`
}

function pad2(n: number): string {
  if (n < 10) return `0${n}`
  return `${n}`
}

/**
 * 将 server 返回的标题转成本地时间友好格式
 * - "New session - 2026-06-09T02:30:58.985Z" → "新会话 2026-06-09 10:30:58"
 * - 其它标题（如 model-test-xxx、用户自定义）原样返回
 *
 * 不使用 RegExp 构造器（ArkTS 严格模式会拒掉），改用 substring + indexOf 解析。
 */
export function formatServerTitle(title: string): string {
  if (title.length === 0) return title
  // 1) 必须以 "New session - " 开头
  const lower: string = title.toLowerCase()
  if (!lower.startsWith(UTC_TITLE_PREFIX.toLowerCase())) {
    return title
  }
  // 2) 截取 UTC 时间戳部分
  const ts: string = title.substring(UTC_TITLE_PREFIX.length)
  // 3) 期望格式: 2026-06-09T02:30:58(.985)Z，长度 19 或 24
  if (ts.length < 19) return title
  // 4) 校验 17 位都是数字 + T: 2026-06-09T02:30:58
  //    位置: YYYY-MM-DDTHH:MM:SS
  //           0123456789012345678
  for (let i: number = 0; i < 17; i++) {
    const c: string = ts.charAt(i)
    if (i === 10) {
      if (c !== 'T') return title
    } else if (i === 4 || i === 7) {
      if (c !== '-') return title
    } else if (i === 13 || i === 16) {
      if (c !== ':') return title
    } else if (c < '0' || c > '9') {
      return title
    }
  }
  // 5) 校验秒后面是 .xxxZ 或 直接 Z
  const rest: string = ts.substring(19)
  if (rest.length === 0) return title
  if (rest.charAt(0) !== '.' && rest.charAt(0) !== 'Z') return title
  if (rest.charAt(0) === '.') {
    if (rest.charAt(rest.length - 1) !== 'Z') return title
  }
  // 6) 解析出 Y/M/D/H/M/S
  const y: number = parseInt(ts.substring(0, 4))
  const mo: number = parseInt(ts.substring(5, 7))
  const da: number = parseInt(ts.substring(8, 10))
  const hUtc: number = parseInt(ts.substring(11, 13))
  const mi: number = parseInt(ts.substring(14, 16))
  const se: number = parseInt(ts.substring(17, 19))
  if (isNaN(y) || isNaN(mo) || isNaN(da) || isNaN(hUtc) || isNaN(mi) || isNaN(se)) {
    return title
  }
  // 7) 用 Date 构造再做时区换算，浏览器/ArkTS 都能正确处理
  const d: Date = new Date(Date.UTC(y, mo - 1, da, hUtc, mi, se))
  const ly: number = d.getFullYear()
  const lmo: number = d.getMonth() + 1
  const lda: number = d.getDate()
  const lh: number = d.getHours()
  const lmi: number = d.getMinutes()
  const ls: number = d.getSeconds()
  return `新会话 ${ly}-${pad2(lmo)}-${pad2(lda)} ${pad2(lh)}:${pad2(lmi)}:${pad2(ls)}`
}
