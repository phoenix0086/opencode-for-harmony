# OpenCode Harmony — Smoke Matrix (M21-M23)

This document tracks the runtime API parity between the Harmony client and the
OpenCode Runtime, divided into three tiers:

- **api-v2** — full OpenCode server (port 4096, modern REST API)
- **legacy** — older server with `/session/...` endpoints
- **unknown** — server mode not yet detected

## Detection

Server mode is detected by probing `/api/health` first, falling back to
`/global/health` if v2 is not available. The detected mode is stored in
`MainViewModel.serverMode` and displayed in `StatusPopover` as a badge:

| Mode     | Label     | Color         | Background          |
| -------- | --------- | ------------- | ------------------- |
| api-v2   | `api-v2`  | `Theme.SUCCESS` | `Theme.SUCCESS_DIM` |
| legacy   | `legacy`  | `Theme.WARNING` | `Theme.WARNING_DIM` |
| unknown  | `-- (probing)` | `Theme.TEXT_MUTED` | `Theme.ACTIVE_BG`   |

## API Endpoint Coverage

| Endpoint                                              | api-v2 | legacy | Status          |
| ----------------------------------------------------- | :----: | :----: | --------------- |
| `GET /api/health`                                     |   ✓    |   -    | Working         |
| `GET /global/health`                                  |   -    |   ✓    | Working         |
| `GET /api/session` / `GET /session`                   |   ✓    |   ✓    | Normalized (M21) |
| `POST /api/session` / `POST /session`                 |   ✓    |   ✓    | Normalized (M21) |
| `GET /api/session/:id` / `GET /session/:id`           |   ✓    |   ✓    | Normalized (M21) |
| `POST /api/session/:id/prompt`                        |   ✓    |   -    | Working (M21)   |
| `POST /session/:id/prompt_async`                      |   -    |   ✓    | Working         |
| `POST /api/session/:id/wait`                          |   ✓    |   -    | Working (M21)   |
| `GET /api/session/:id/message` / `.../message`        |   ✓    |   ✓    | Normalized (M21) |
| `GET /api/session/:id/context`                        |   ✓    |   -    | Stub (M21)      |
| `GET /api/provider` / `GET /provider`                 |   ✓    |   ✓    | Working         |
| `GET /api/model`                                      |   ✓    |   -    | Empty (legacy)  |
| `GET /api/config` / `GET /config`                     |   ✓    |   ✓    | Working         |
| `PATCH /api/config` / `PATCH /config`                 |   ✓    |   ✓    | X-HTTP-Method-Override |
| `GET /api/fs/list` / `GET /file`                      |   ✓    |   ✓    | Working         |
| `POST /api/session/:id/abort`                         |   ✓    |   ✓    | Adapter (M23)   |
| `GET /api/permission/request`                         |   ✓    |   ✓    | Adapter + UI (M23) |
| `GET /api/permission/saved`                           |   ✓    |   -    | Adapter (M23)   |
| `DELETE /api/permission/saved/:id`                    |   ✓    |   -    | Adapter (M23)   |
| `POST /api/session/:id/permission/:rid/reply`         |   ✓    |   ✓    | Adapter + UI (M23) |
| `GET /api/session/:id/question`                       |   ✓    |   ✓    | Adapter + UI (M23) |
| `POST /api/session/:id/question/:rid/reply`           |   ✓    |   ✓    | Adapter + UI (M23) |
| `POST /api/session/:id/question/:rid/reject`          |   ✓    |   -    | Adapter + UI (M23) |
| `GET /api/command` / `GET /command`                   |   ✓    |   ✓    | Adapter (M23)   |
| `GET /api/skill` / `GET /skill`                       |   ✓    |   ✓    | Adapter (M23)   |
| `GET /api/event` / `GET /event`                       |   ✓    |   ✓    | URL ready (M23) |

## Chat UI Features (M22-M23)

| Feature | Status | Notes |
| ------- | ------ | ----- |
| Error messages | ✅ Done | Red background, monospace |
| Tool call display | ✅ Done | Tool name + status badge |
| System messages | ✅ Done | Centered, italic |
| Streaming indicator | ✅ Done | "(streaming...)" |
| Stop button | ✅ Done | Appears when generating |
| Server mode badge | ✅ Done | api-v2/legacy in header |
| Permission dock | ✅ Done | Allow/Always/Reject |
| Question dock | ✅ Done | Options + Reject |
| Turn alignment | ✅ Done | activeTurnId prevents stale polls |
| Send lock | ✅ Done | Prevents concurrent sends |

## Dead Code (M25 cleanup)

| File | Status | Action |
| ---- | ------ | ------ |
| `LocalRuntimeManager.ets` | Dead code | Delete |
| `LocalOpenCodeRuntimeService.ets` | Only RuntimePage | Migrate to ServerManager |
| `LocalProcessBridge.ets` | Only RuntimeService | Delete after migration |

## Capability Flags

The `OpenCodeCapabilities.detect()` result returns a `Capabilities` object:

```typescript
interface Capabilities {
  fs: boolean              // /api/fs/list available
  sessionPrompt: boolean   // can send prompt
  sessionWait: boolean     // can wait for completion
  sessionContext: boolean  // can read context
  permissionSaved: boolean // permission persistence
  questionReject: boolean  // can reject questions
  connector: boolean       // connectors API
  eventStream: boolean     // SSE event stream
  command: boolean         // commands API
  skill: boolean           // skills API
  pty: boolean             // PTY (always false in M21)
  mcp: boolean             // MCP (always false in M21)
}
```

In legacy mode, `sessionPrompt` and `sessionWait` are set to `true` for
backward compat (legacy uses `prompt_async` + polling).

## Adapter Architecture

`OpenCodeApiAdapter` is the unified facade that `MainViewModel` calls.
It routes to the right URL prefix based on detected mode:

```
MainViewModel → OpenCodeApiAdapter → /api/... (v2) | /session/... (legacy)
```

Each method has a mode-aware branch:

```typescript
async listSessions(): Promise<SessionInfo[]> {
  if (this.mode === 'api-v2') {
    const data = await this.get<{ data: Object[] }>('/api/session');
    return this.normalizeSessions(data.data ?? []);
  }
  const arr = await this.get<Object[]>('/session');
  return this.normalizeSessions(arr ?? []);
}
```

## Turn Alignment (m20)

`sendMessage` uses `activeTurnId` to discard stale polls from previous turns:

1. Each `sendMessage` call generates a new `turnId`
2. `waitForExecutionAfterIndex(sessionId, userIndex, turnId)` checks
   `this.activeTurnId === turnId` on every poll iteration
3. If the user sent a new message, `activeTurnId` changes, and the old
   poll returns immediately with `r.ok = false`
4. `userIndex` is found by matching the user text in raw messages,
   so the assistant is only detected AFTER the current user

## Testing Notes

To verify parity locally:

1. Start OpenCode server: `cd ~/work && opencode serve --port 4096 --hostname 0.0.0.0`
2. Launch the Harmony app, set Host = `192.168.1.72`, Port = `4096`
3. Open Status Popover — should show `api-v2` badge (green)
4. Send a test message — turn alignment should work even if user sends
   multiple messages in quick succession
5. Switch server to legacy mode (downgrade) — badge should switch to
   `legacy` (yellow), chat still works with polling fallback

## Files Touched (M21)

- `entry/src/main/ets/services/OpenCodeCapabilities.ets` (new)
- `entry/src/main/ets/services/OpenCodeApiAdapter.ets` (new)
- `entry/src/main/ets/viewmodel/MainViewModel.ets` (route via adapter)
- `entry/src/main/ets/components/StatusPopover.ets` (mode badge)
- `entry/src/main/ets/components/AppShell.ets` (pass serverMode prop)
- `entry/src/main/ets/pages/Index.ets` (serverMode state)
