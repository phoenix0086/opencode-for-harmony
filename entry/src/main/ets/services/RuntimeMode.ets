/**
 * RuntimeMode — unified runtime mode type for the HarmonyOS app.
 *
 * - 'local-embedded': In-process ArkTS Runtime (LocalRuntimeClient).
 *   No fork/exec of external binaries. Provider calls go directly
 *   through ArkTS HTTP client.
 *
 * - 'dev-pc': Connect to an `opencode serve` running on the user's
 *   development computer over LAN. Requires the server to be started
 *   manually on the dev machine.
 *
 * - 'remote': Connect to an `opencode serve` running on a remote server.
 *   Requires URL and optional auth credentials.
 */
export type RuntimeMode = 'local-embedded' | 'dev-pc' | 'remote'

/**
 * Map legacy mode strings to the new RuntimeMode.
 * Accepts both old ('local', 'dev-pc', 'remote') and new ('local-embedded') values.
 */
export function toRuntimeMode(raw: string): RuntimeMode {
  if (raw === 'local-embedded' || raw === 'local') return 'local-embedded'
  if (raw === 'dev-pc') return 'dev-pc'
  if (raw === 'remote') return 'remote'
  return 'local-embedded' // default
}

/**
 * Human-readable label for each mode (Chinese UI).
 */
export function runtimeModeLabel(mode: RuntimeMode): string {
  switch (mode) {
    case 'local-embedded': return '本机 Runtime'
    case 'dev-pc': return '开发电脑 / 局域网'
    case 'remote': return '远程服务器'
  }
}

/**
 * Whether the given mode requires an external server URL.
 */
export function needsServerUrl(mode: RuntimeMode): boolean {
  return mode === 'dev-pc' || mode === 'remote'
}

/** Normalize an external URL before validation and persistence. */
export function normalizeExternalRuntimeUrl(url: string): string {
  const value = url.trim()
  const match = value.match(/^(https?):\/\/([^:\/\s]+)(?::([0-9]{1,5}))?\/?$/i)
  if (match === null || match.length < 3) return value
  const protocol = match[1].toLowerCase()
  const host = match[2]
  const port = match.length > 3 && match[3] !== undefined && match[3].length > 0 ? `:${match[3]}` : ''
  return `${protocol}://${host}${port}`
}

/**
 * Validate a user-entered external Runtime URL before starting probes.
 * A missing host produces noisy retry loops and is never a usable endpoint.
 */
export function isValidExternalRuntimeUrl(url: string, mode: RuntimeMode): boolean {
  const value = url.trim()
  const match = value.match(/^https?:\/\/([^:\/\s]+)(?::([0-9]{1,5}))?\/?$/i)
  if (match === null || match.length < 2) return false
  const host = match[1]
  if (host.length === 0) return false
  if (mode === 'dev-pc' && (host === '127.0.0.1' || host === 'localhost' || host === '::1')) return false
  if (match.length > 2 && match[2] !== undefined && match[2].length > 0) {
    const port = Number(match[2])
    if (port < 1 || port > 65535) return false
  }
  return true
}
