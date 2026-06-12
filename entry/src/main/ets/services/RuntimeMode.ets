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
