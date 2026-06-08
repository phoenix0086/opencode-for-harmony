# OpenCode Upstream API Mapping

Comprehensive reference for the OpenCode server HTTP API, SSE event system, authentication, and SDK client.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Authentication](#authentication)
- [Workspace Routing](#workspace-routing)
- [API Composition](#api-composition)
- [Global Routes](#global-routes)
- [Control Routes](#control-routes)
- [Control Plane Routes](#control-plane-routes)
- [Event / SSE Routes](#event--sse-routes)
- [Session Routes](#session-routes)
- [Config Routes](#config-routes)
- [Provider Routes](#provider-routes)
- [Permission Routes](#permission-routes)
- [Question Routes](#question-routes)
- [Instance Routes](#instance-routes)
- [File Routes](#file-routes)
- [MCP Routes](#mcp-routes)
- [Project Routes](#project-routes)
- [Project Copy Routes](#project-copy-routes)
- [PTY Routes](#pty-routes)
- [Sync Routes](#sync-routes)
- [Workspace Routes](#workspace-routes)
- [Experimental Routes](#experimental-routes)
- [TUI Routes](#tui-routes)
- [Reference Routes](#reference-routes)
- [SSE / Event Stream Format](#sse--event-stream-format)
- [Event Type Registry](#event-type-registry)
- [Error Types](#error-types)
- [SDK Client](#sdk-client)
- [Desktop App Integration](#desktop-app-integration)
- [Session Lifecycle](#session-lifecycle)

---

## Architecture Overview

The OpenCode server is built on Effect's `HttpApi` framework. The API is composed of multiple `HttpApi` groups that are assembled in `/packages/opencode/src/server/routes/instance/httpapi/api.ts`.

**Top-level composition:**

```
OpenCodeHttpApi
  +-- RootHttpApi           (global + control + control-plane routes)
  |     +-- ControlApi
  |     +-- ControlPlaneApi
  |     +-- GlobalApi
  +-- EventApi              (instance SSE stream)
  +-- InstanceHttpApi       (all instance-scoped routes)
  |     +-- ConfigApi
  |     +-- ExperimentalApi
  |     +-- FileApi
  |     +-- InstanceApi
  |     +-- McpApi
  |     +-- ProjectApi
  |     +-- ProjectCopyApi
  |     +-- PtyApi
  |     +-- QuestionApi
  |     +-- PermissionApi
  |     +-- ProviderApi
  |     +-- ReferenceApi
  |     +-- SessionApi
  |     +-- SyncApi
  |     +-- TuiApi
  |     +-- WorkspaceApi
  +-- Api                   (from @opencode-ai/server)
  +-- PtyConnectApi         (WebSocket upgrade route)
```

The server listens on a configurable hostname/port (default `127.0.0.1:4096`). An OpenAPI spec is served at `GET /doc`.

**Source files:**
- API composition: `/packages/opencode/src/server/routes/instance/httpapi/api.ts`
- Server bootstrap: `/packages/opencode/src/server/server.ts`
- Route/handler wiring: `/packages/opencode/src/server/routes/instance/httpapi/server.ts`
- Public OpenAPI transform: `/packages/opencode/src/server/routes/instance/httpapi/public.ts`

---

## Authentication

**Mechanism: HTTP Basic Auth**

The server uses HTTP Basic Authentication. Credentials are configured via environment variables:

| Environment Variable | Description | Default |
|---|---|---|
| `OPENCODE_SERVER_PASSWORD` | Server password | (none -- if unset, auth is disabled) |
| `OPENCODE_SERVER_USERNAME` | Server username | `"opencode"` |

**How it works:**

1. If `OPENCODE_SERVER_PASSWORD` is not set or is empty, **all requests are authorized** (auth is bypassed).
2. If a password is configured, the server expects an `Authorization: Basic <base64>` header where the decoded value is `username:password`.
3. Alternatively, credentials can be passed as a query parameter: `?auth_token=<base64(username:password)>`.
4. Failed authentication returns `401 Unauthorized` with a `WWW-Authenticate: Basic realm="Secure Area"` header.

**Desktop app usage:** The desktop app spawns the server as a sidecar (utility process) and passes a randomly generated `password` to it. Health checks use `GET /global/health` with the Basic auth header.

**PTY WebSocket connections** have a separate ticket-based auth path: a short-lived connect token can be obtained via `POST /pty/:ptyID/connect-token` and passed as a query parameter on the WebSocket URL, bypassing Basic auth.

**Source:** `/packages/opencode/src/server/auth.ts`, `/packages/opencode/src/server/routes/instance/httpapi/middleware/authorization.ts`

---

## Workspace Routing

Most instance-scoped endpoints accept two optional query parameters for workspace routing:

| Query Parameter | Type | Description |
|---|---|---|
| `directory` | `string` | Project directory path (fallback: `x-opencode-directory` header or `process.cwd()`) |
| `workspace` | `string` | Workspace ID for routing to remote/workspace-specific instances |

The `WorkspaceRoutingMiddleware` resolves the target instance:
- **Local**: request is handled directly with the resolved directory and workspace context.
- **Remote**: request is proxied to a remote workspace target via HTTP (or WebSocket upgrade for PTY).
- **Missing workspace**: returns 500 with text error.
- **Invalid workspace**: returns 400 with `InvalidRequestError`.

The SDK client sets `x-opencode-directory` header on creation and rewrites it to `?directory=` query param on GET/HEAD requests via a request interceptor.

**Source:** `/packages/opencode/src/server/routes/instance/httpapi/middleware/workspace-routing.ts`

---

## API Composition

### RootHttpApi (no instance context required)

Middleware: `SchemaErrorMiddleware`, `Authorization`

### InstanceHttpApi (requires instance context)

Middleware: `SchemaErrorMiddleware`, `InstanceContextMiddleware`, `WorkspaceRoutingMiddleware`, `Authorization`

### EventApi (SSE, requires instance context)

Middleware: `InstanceContextMiddleware`, `WorkspaceRoutingMiddleware`, `Authorization`

### PtyConnectApi (WebSocket, requires instance context)

Middleware: `InstanceContextMiddleware`, `WorkspaceRoutingMiddleware`, `PtyConnectAuthorization`

---

## Global Routes

**Group:** `global`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/global.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/global/health` | `global.health` | Health check | -- | `{ healthy: true, version: string }` |
| `GET` | `/global/event` | `global.event` | Global SSE event stream | -- | `text/event-stream` (see [GlobalEvent format](#global-event-stream)) |
| `GET` | `/global/config` | `global.config.get` | Get global config | -- | `ConfigV1.Info` |
| `PATCH` | `/global/config` | `global.config.update` | Update global config | Body: `ConfigV1.Info` | `ConfigV1.Info` |
| `POST` | `/global/dispose` | `global.dispose` | Dispose all instances | -- | `boolean` |
| `POST` | `/global/upgrade` | `global.upgrade` | Upgrade OpenCode | Body: `{ target?: string }` | `{ success: true, version: string }` or `{ success: false, error: string }` |

---

## Control Routes

**Group:** `control`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/control.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `PUT` | `/auth/:providerID` | `auth.set` | Set auth credentials for a provider | Params: `providerID`. Body: `Auth.Info` | `boolean` |
| `DELETE` | `/auth/:providerID` | `auth.remove` | Remove auth credentials | Params: `providerID` | `boolean` |
| `POST` | `/log` | `app.log` | Write a log entry | Query: `directory?`, `workspace?`. Body: `{ service, level, message, extra? }` | `boolean` |

**Log body schema:**
```typescript
{
  service: string        // Service name
  level: "debug" | "info" | "error" | "warn"
  message: string        // Log message
  extra?: Record<string, unknown>  // Additional metadata
}
```

---

## Control Plane Routes

**Group:** `controlPlane`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/control-plane.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `POST` | `/experimental/control-plane/move-session` | `experimental.controlPlane.moveSession` | Move session to another project | Body: `MoveSession.Input` | No content |

---

## Event / SSE Routes

**Group:** `event`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/event.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/event` | `event.subscribe` | Instance SSE event stream | Query: `directory?`, `workspace?` | `text/event-stream` |

See [SSE / Event Stream Format](#sse--event-stream-format) for details.

---

## Session Routes

**Group:** `session`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/session.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/session` | `session.list` | List sessions | Query: `directory?`, `workspace?`, `scope?`, `path?`, `roots?`, `start?`, `search?`, `limit?` | `Session.Info[]` |
| `GET` | `/session/status` | `session.status` | Get all session statuses | Query: `directory?`, `workspace?` | `Record<string, SessionStatus.Info>` |
| `GET` | `/session/:sessionID` | `session.get` | Get session | Params: `sessionID`. Query: `directory?`, `workspace?` | `Session.Info` |
| `GET` | `/session/:sessionID/children` | `session.children` | Get child (forked) sessions | Params: `sessionID` | `Session.Info[]` |
| `GET` | `/session/:sessionID/todo` | `session.todo` | Get session todos | Params: `sessionID` | `Todo.Info[]` |
| `GET` | `/session/:sessionID/diff` | `session.diff` | Get file diff for session | Params: `sessionID`. Query: `directory?`, `workspace?`, + `SessionSummary.DiffInput` fields | `Snapshot.FileDiff[]` |
| `GET` | `/session/:sessionID/message` | `session.messages` | List messages | Params: `sessionID`. Query: `directory?`, `workspace?`, `limit?`, `before?` | `SessionV1.WithParts[]` |
| `GET` | `/session/:sessionID/message/:messageID` | `session.message` | Get single message | Params: `sessionID`, `messageID` | `SessionV1.WithParts` |
| `POST` | `/session` | `session.create` | Create session | Body: `Session.CreateInput` (optional, can be empty) | `Session.Info` |
| `DELETE` | `/session/:sessionID` | `session.delete` | Delete session | Params: `sessionID` | `boolean` |
| `PATCH` | `/session/:sessionID` | `session.update` | Update session | Params: `sessionID`. Body: `{ title?, metadata?, permission?, time? }` | `Session.Info` |
| `POST` | `/session/:sessionID/fork` | `session.fork` | Fork session | Params: `sessionID`. Body: `ForkPayload` (omits `sessionID`) | `Session.Info` |
| `POST` | `/session/:sessionID/abort` | `session.abort` | Abort session | Params: `sessionID` | `boolean` |
| `POST` | `/session/:sessionID/init` | `session.init` | Initialize AGENTS.md | Params: `sessionID`. Body: `{ modelID, providerID, messageID }` | `boolean` |
| `POST` | `/session/:sessionID/share` | `session.share` | Share session | Params: `sessionID` | `Session.Info` |
| `DELETE` | `/session/:sessionID/share` | `session.unshare` | Unshare session | Params: `sessionID` | `Session.Info` |
| `POST` | `/session/:sessionID/summarize` | `session.summarize` | Summarize session | Params: `sessionID`. Body: `{ providerID, modelID, auto? }` | `boolean` |
| `POST` | `/session/:sessionID/message` | `session.prompt` | Send message (sync) | Params: `sessionID`. Body: `PromptPayload` | `SessionV1.WithParts` |
| `POST` | `/session/:sessionID/prompt_async` | `session.prompt_async` | Send message (async) | Params: `sessionID`. Body: `PromptPayload` | No content (202) |
| `POST` | `/session/:sessionID/command` | `session.command` | Send command | Params: `sessionID`. Body: `CommandPayload` | `SessionV1.WithParts` |
| `POST` | `/session/:sessionID/shell` | `session.shell` | Run shell command | Params: `sessionID`. Body: `ShellPayload` | `SessionV1.WithParts` |
| `POST` | `/session/:sessionID/revert` | `session.revert` | Revert message | Params: `sessionID`. Body: `RevertPayload` | `Session.Info` |
| `POST` | `/session/:sessionID/unrevert` | `session.unrevert` | Restore reverted messages | Params: `sessionID` | `Session.Info` |
| `POST` | `/session/:sessionID/permissions/:permissionID` | `permission.respond` | Respond to permission (deprecated) | Params: `sessionID`, `permissionID`. Body: `{ response: PermissionV1.Reply }` | `boolean` |
| `DELETE` | `/session/:sessionID/message/:messageID` | `session.deleteMessage` | Delete message | Params: `sessionID`, `messageID` | `boolean` |
| `DELETE` | `/session/:sessionID/message/:messageID/part/:partID` | `part.delete` | Delete message part | Params: `sessionID`, `messageID`, `partID` | `boolean` |
| `PATCH` | `/session/:sessionID/message/:messageID/part/:partID` | `part.update` | Update message part | Params: `sessionID`, `messageID`, `partID`. Body: `SessionV1.Part` | `SessionV1.Part` |

**Update body schema:**
```typescript
{
  title?: string
  metadata?: Session.Metadata
  permission?: PermissionV1.Ruleset
  time?: {
    archived?: Session.ArchivedTimestamp
  }
}
```

---

## Config Routes

**Group:** `config`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/config.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/config` | `config.get` | Get configuration | Query: `directory?`, `workspace?` | `ConfigV1.Info` |
| `PATCH` | `/config` | `config.update` | Update configuration | Body: `ConfigV1.Info` | `ConfigV1.Info` |
| `GET` | `/config/providers` | `config.providers` | List configured providers | Query: `directory?`, `workspace?` | `Provider.ConfigProvidersResult` |

---

## Provider Routes

**Group:** `provider`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/provider.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/provider` | `provider.list` | List all providers | Query: `directory?`, `workspace?` | `Provider.ListResult` |
| `GET` | `/provider/auth` | `provider.auth` | Get auth methods | Query: `directory?`, `workspace?` | `ProviderAuth.Methods` |
| `POST` | `/provider/:providerID/oauth/authorize` | `provider.oauth.authorize` | Start OAuth flow | Params: `providerID`. Body: `ProviderAuth.AuthorizeInput` | `ProviderAuth.Authorization` or `undefined` |
| `POST` | `/provider/:providerID/oauth/callback` | `provider.oauth.callback` | Handle OAuth callback | Params: `providerID`. Body: `ProviderAuth.CallbackInput` | `boolean` |

**Provider auth errors:** `BadRequest`, `ProviderAuthOauthMissing`, `ProviderAuthOauthCodeMissing`, `ProviderAuthOauthCallbackFailed`, `ProviderAuthValidationFailed`

---

## Permission Routes

**Group:** `permission`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/permission.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/permission` | `permission.list` | List pending permissions | Query: `directory?`, `workspace?` | `PermissionV1.Request[]` |
| `POST` | `/permission/:requestID/reply` | `permission.reply` | Reply to permission request | Params: `requestID`. Body: `{ reply: PermissionV1.Reply, message?: string }` | `boolean` |

---

## Question Routes

**Group:** `question`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/question.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/question` | `question.list` | List pending questions | Query: `directory?`, `workspace?` | `Question.Request[]` |
| `POST` | `/question/:requestID/reply` | `question.reply` | Answer a question | Params: `requestID`. Body: `{ answers: Question.Answer[] }` | `boolean` |
| `POST` | `/question/:requestID/reject` | `question.reject` | Reject a question | Params: `requestID` | `boolean` |

---

## Instance Routes

**Group:** `instance`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/instance.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `POST` | `/instance/dispose` | `instance.dispose` | Dispose instance | Query: `directory?`, `workspace?` | `boolean` |
| `GET` | `/path` | `path.get` | Get paths | Query: `directory?`, `workspace?` | `{ home, state, config, worktree, directory }` |
| `GET` | `/vcs` | `vcs.get` | Get VCS info | Query: `directory?`, `workspace?` | `Vcs.Info` |
| `GET` | `/vcs/status` | `vcs.status` | Get VCS file status | Query: `directory?`, `workspace?` | `Vcs.FileStatus[]` |
| `GET` | `/vcs/diff` | `vcs.diff` | Get VCS diff | Query: `directory?`, `workspace?`, `mode`, `context?` | `Vcs.FileDiff[]` |
| `GET` | `/vcs/diff/raw` | `vcs.diff.raw` | Get raw VCS diff patch | Query: `directory?`, `workspace?` | `text/x-diff; charset=utf-8` |
| `POST` | `/vcs/apply` | `vcs.apply` | Apply VCS patch | Body: `Vcs.ApplyInput` | `Vcs.ApplyResult` |
| `GET` | `/command` | `command.list` | List commands | Query: `directory?`, `workspace?` | `Command.Info[]` |
| `GET` | `/agent` | `app.agents` | List agents | Query: `directory?`, `workspace?` | `Agent.Info[]` |
| `GET` | `/skill` | `app.skills` | List skills | Query: `directory?`, `workspace?` | `Skill.Info[]` |
| `GET` | `/lsp` | `lsp.status` | Get LSP status | Query: `directory?`, `workspace?` | `LSP.Status[]` |
| `GET` | `/formatter` | `formatter.status` | Get formatter status | Query: `directory?`, `workspace?` | `Format.Status[]` |

**VCS diff query:**
- `mode`: Vcs.Mode (required) -- determines diff mode
- `context`: optional non-negative integer for context lines

**VCS apply error:** `VcsApplyError` with `reason: "non-git" | "not-clean"`

---

## File Routes

**Group:** `file`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/file.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/find` | `find.text` | Search text (ripgrep) | Query: `directory?`, `workspace?`, `pattern` | `Ripgrep.SearchMatch[]` |
| `GET` | `/find/file` | `find.files` | Find files | Query: `directory?`, `workspace?`, `query`, `dirs?`, `type?`, `limit?` | `string[]` (file paths) |
| `GET` | `/find/symbol` | `find.symbols` | Find symbols (LSP) | Query: `directory?`, `workspace?`, `query` | `LSP.Symbol[]` |
| `GET` | `/file` | `file.list` | List files/dirs | Query: `directory?`, `workspace?`, `path` | `FileNode[]` |
| `GET` | `/file/content` | `file.read` | Read file content | Query: `directory?`, `workspace?`, `path` | `FileContent` |
| `GET` | `/file/status` | `file.status` | Get git file status | Query: `directory?`, `workspace?` | `File[]` |

**FileNode schema:**
```typescript
{ name: string, path: string, absolute: string, type: "file" | "directory", ignored: boolean }
```

**FileContent schema:**
```typescript
{
  type: "text" | "binary"
  content: string
  diff?: string
  patch?: { oldFileName, newFileName, oldHeader?, newHeader?, hunks: [{ oldStart, oldLines, newStart, newLines, lines: string[] }], index? }
  encoding?: "base64"
  mimeType?: string
}
```

**File (status) schema:**
```typescript
{ path: string, added: number, removed: number, status: "added" | "deleted" | "modified" }
```

---

## MCP Routes

**Group:** `mcp`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/mcp.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/mcp` | `mcp.status` | Get MCP server status | Query: `directory?`, `workspace?` | `Record<string, MCP.Status>` |
| `POST` | `/mcp` | `mcp.add` | Add MCP server | Body: `{ name: string, config: ConfigMCPV1.Info }` | `Record<string, MCP.Status>` |
| `POST` | `/mcp/:name/auth` | `mcp.auth.start` | Start MCP OAuth | Params: `name` | `{ authorizationUrl: string, oauthState: string }` |
| `POST` | `/mcp/:name/auth/callback` | `mcp.auth.callback` | Complete MCP OAuth | Params: `name`. Body: `{ code: string }` | `MCP.Status` |
| `POST` | `/mcp/:name/auth/authenticate` | `mcp.auth.authenticate` | Full OAuth flow (opens browser) | Params: `name` | `MCP.Status` |
| `DELETE` | `/mcp/:name/auth` | `mcp.auth.remove` | Remove MCP OAuth creds | Params: `name` | `{ success: true }` |
| `POST` | `/mcp/:name/connect` | `mcp.connect` | Connect MCP server | Params: `name` | `boolean` |
| `POST` | `/mcp/:name/disconnect` | `mcp.disconnect` | Disconnect MCP server | Params: `name` | `boolean` |

---

## Project Routes

**Group:** `project`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/project.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/project` | `project.list` | List projects | Query: `directory?`, `workspace?` | `Project.Info[]` |
| `GET` | `/project/current` | `project.current` | Get current project | Query: `directory?`, `workspace?` | `Project.Info` |
| `POST` | `/project/git/init` | `project.initGit` | Initialize git repo | Query: `directory?`, `workspace?` | `Project.Info` |
| `PATCH` | `/project/:projectID` | `project.update` | Update project | Params: `projectID`. Body: `{ name?, icon?, commands? }` | `Project.Info` |
| `GET` | `/project/:projectID/directories` | `project.directories` | List project directories | Params: `projectID` | `ProjectV2.Directories` |

---

## Project Copy Routes

**Group:** `projectCopy`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/project-copy.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `POST` | `/experimental/project/:projectID/copy` | `experimental.projectCopy.create` | Create project copy | Params: `projectID`. Query: `workspace?`. Body: `{ strategy, directory, name, context }` | `ProjectCopy.Copy` |
| `DELETE` | `/experimental/project/:projectID/copy` | `experimental.projectCopy.remove` | Remove project copy | Params: `projectID`. Query: `workspace?`. Body: `{ directory, force }` | No content |
| `POST` | `/experimental/project/:projectID/copy/refresh` | `experimental.projectCopy.refresh` | Refresh project copies | Params: `projectID` | No content |

---

## PTY Routes

**Group:** `pty` and `pty-connect`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/pty.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/pty/shells` | `pty.shells` | List available shells | Query: `directory?`, `workspace?` | `{ path, name, acceptable }[]` |
| `GET` | `/pty` | `pty.list` | List PTY sessions | Query: `directory?`, `workspace?` | `Pty.Info[]` |
| `POST` | `/pty` | `pty.create` | Create PTY session | Body: `Pty.CreateInput` | `Pty.Info` |
| `GET` | `/pty/:ptyID` | `pty.get` | Get PTY session | Params: `ptyID` | `Pty.Info` |
| `PUT` | `/pty/:ptyID` | `pty.update` | Update PTY session | Params: `ptyID`. Body: `Pty.UpdateInput` | `Pty.Info` |
| `DELETE` | `/pty/:ptyID` | `pty.remove` | Remove PTY session | Params: `ptyID` | `boolean` |
| `POST` | `/pty/:ptyID/connect-token` | `pty.connectToken` | Create WebSocket token | Params: `ptyID` | `PtyTicket.ConnectToken` |
| `GET` | `/pty/:ptyID/connect` | `pty.connect` | WebSocket connect | Params: `ptyID`. Query: `directory?`, `workspace?`, `cursor?`, `ticket?` | WebSocket upgrade |

The `pty.connect` route uses `PtyConnectAuthorization` middleware which allows either Basic auth or a valid connection ticket in the query string.

---

## Sync Routes

**Group:** `sync`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/sync.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `POST` | `/sync/start` | `sync.start` | Start workspace sync | Query: `directory?`, `workspace?` | `boolean` |
| `POST` | `/sync/replay` | `sync.replay` | Replay sync events | Body: `{ directory: string, events: ReplayEvent[] }` | `{ sessionID: string }` |
| `POST` | `/sync/steal` | `sync.steal` | Steal session into workspace | Body: `{ sessionID: string }` | `{ sessionID: string }` |
| `POST` | `/sync/history` | `sync.history.list` | List sync events | Body: `Record<string, number>` (aggregateID -> lastSeq) | `HistoryEvent[]` |

**ReplayEvent schema:**
```typescript
{ id: string, aggregateID: string, seq: number, type: string, data: Record<string, unknown> }
```

---

## Workspace Routes

**Group:** `workspace`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/workspace.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/experimental/workspace/adapter` | `experimental.workspace.adapter.list` | List adapters | Query: `directory?`, `workspace?` | `WorkspaceAdapterEntry[]` |
| `GET` | `/experimental/workspace` | `experimental.workspace.list` | List workspaces | Query: `directory?`, `workspace?` | `Workspace.Info[]` |
| `POST` | `/experimental/workspace` | `experimental.workspace.create` | Create workspace | Body: `CreatePayload` (omits `projectID`) | `Workspace.Info` |
| `POST` | `/experimental/workspace/sync-list` | `experimental.workspace.syncList` | Sync workspace list | -- | No content |
| `GET` | `/experimental/workspace/status` | `experimental.workspace.status` | Get connection status | Query: `directory?`, `workspace?` | `Workspace.ConnectionStatus[]` |
| `DELETE` | `/experimental/workspace/:id` | `experimental.workspace.remove` | Remove workspace | Params: `id` | `Workspace.Info` or `undefined` |
| `POST` | `/experimental/workspace/warp` | `experimental.workspace.warp` | Warp session to workspace | Body: `{ id: string | null, sessionID, copyChanges }` | No content |

---

## Experimental Routes

**Group:** `experimental`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/experimental.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/experimental/console` | `experimental.console.get` | Get console provider state | Query: `directory?`, `workspace?` | `{ consoleManagedProviders: string[], activeOrgName?, switchableOrgCount }` |
| `GET` | `/experimental/console/orgs` | `experimental.console.listOrgs` | List console orgs | Query: `directory?`, `workspace?` | `{ orgs: ConsoleOrgOption[] }` |
| `POST` | `/experimental/console/switch` | `experimental.console.switchOrg` | Switch console org | Body: `{ accountID, orgID }` | `boolean` |
| `GET` | `/experimental/tool` | `tool.list` | List tools | Query: `directory?`, `workspace?`, `provider`, `model` | `{ id, description, parameters }[]` |
| `GET` | `/experimental/tool/ids` | `tool.ids` | List tool IDs | Query: `directory?`, `workspace?` | `string[]` |
| `GET` | `/experimental/worktree` | `worktree.list` | List worktrees | Query: `directory?`, `workspace?` | `string[]` |
| `POST` | `/experimental/worktree` | `worktree.create` | Create worktree | Body: `Worktree.CreateInput` | `Worktree.Info` |
| `DELETE` | `/experimental/worktree` | `worktree.remove` | Remove worktree | Body: `Worktree.RemoveInput` | `boolean` |
| `POST` | `/experimental/worktree/reset` | `worktree.reset` | Reset worktree | Body: `Worktree.ResetInput` | `boolean` |
| `GET` | `/experimental/session` | `experimental.session.list` | List sessions (cross-project) | Query: `directory?`, `workspace?`, `roots?`, `start?`, `cursor?`, `search?`, `limit?`, `archived?` | `Session.GlobalInfo[]` |
| `POST` | `/experimental/session/:sessionID/background` | `experimental.session.background` | Background subagents | Params: `sessionID` | `boolean` |
| `GET` | `/experimental/resource` | `experimental.resource.list` | List MCP resources | Query: `directory?`, `workspace?` | `Record<string, MCP.Resource>` |

---

## TUI Routes

**Group:** `tui`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/tui.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `POST` | `/tui/append-prompt` | `tui.appendPrompt` | Append to prompt | Body: `{ text: string }` | `boolean` |
| `POST` | `/tui/open-help` | `tui.openHelp` | Open help dialog | -- | `boolean` |
| `POST` | `/tui/open-sessions` | `tui.openSessions` | Open sessions dialog | -- | `boolean` |
| `POST` | `/tui/open-themes` | `tui.openThemes` | Open themes dialog | -- | `boolean` |
| `POST` | `/tui/open-models` | `tui.openModels` | Open models dialog | -- | `boolean` |
| `POST` | `/tui/submit-prompt` | `tui.submitPrompt` | Submit prompt | -- | `boolean` |
| `POST` | `/tui/clear-prompt` | `tui.clearPrompt` | Clear prompt | -- | `boolean` |
| `POST` | `/tui/execute-command` | `tui.executeCommand` | Execute command | Body: `{ command: string }` | `boolean` |
| `POST` | `/tui/show-toast` | `tui.showToast` | Show toast | Body: `TuiEvent.ToastShow.data` | `boolean` |
| `POST` | `/tui/publish` | `tui.publish` | Publish TUI event | Body: `TuiPublishPayload` (union) | `boolean` |
| `POST` | `/tui/select-session` | `tui.selectSession` | Select session | Body: `TuiEvent.SessionSelect.data` | `boolean` |
| `GET` | `/tui/control/next` | `tui.control.next` | Get next TUI request | Query: `directory?`, `workspace?` | `TuiRequest` |
| `POST` | `/tui/control/response` | `tui.control.response` | Submit TUI response | Body: `unknown` | `boolean` |

**TuiPublishPayload union types:**
- `{ type: "tui.prompt.append", properties: { text: string } }`
- `{ type: "tui.command.execute", properties: { command: string } }`
- `{ type: "tui.toast.show", properties: { ... } }`
- `{ type: "tui.session.select", properties: { ... } }`

---

## Reference Routes

**Group:** `reference`
**Source:** `/packages/opencode/src/server/routes/instance/httpapi/groups/reference.ts`

| Method | Path | Identifier | Description | Request | Response |
|--------|------|------------|-------------|---------|----------|
| `GET` | `/reference` | `reference.list` | List configured references | Query: `directory?`, `workspace?` | `ReferenceDescriptor[]` |

**ReferenceDescriptor union:**
```typescript
{ name: string, kind: "local", path: string }
| { name: string, kind: "git", repository: string, path: string, branch?: string }
| { name: string, kind: "invalid", repository?: string, message: string }
```

---

## SSE / Event Stream Format

There are **two SSE endpoints**:

### Instance Event Stream: `GET /event`

- **Content-Type:** `text/event-stream`
- **Headers:** `Cache-Control: no-cache, no-transform`, `X-Accel-Buffering: no`, `X-Content-Type-Options: nosniff`

**Wire format:** Standard SSE with `event: message` and JSON-encoded `data`:

```
event: message
data: {"id":"evt_01JXXX","type":"server.connected","properties":{}}

event: message
data: {"id":"evt_01JXXX","type":"session.created","properties":{...}}

event: message
data: {"id":"evt_01JXXX","type":"server.heartbeat","properties":{}}
```

**Behavior:**
1. On connect, immediately emits `server.connected` event.
2. Then streams instance-scoped events filtered by `directory` and `workspaceID`.
3. Merges in a heartbeat event (`server.heartbeat`) every 10 seconds.
4. Stream terminates when `server.instance.disposed` event is received for the instance's directory.

### Global Event Stream: `GET /global/event`

Same SSE format, but events are wrapped with a `payload` envelope:

```
event: message
data: {"payload":{"id":"evt_01JXXX","type":"server.connected","properties":{}}}

event: message
data: {"directory":"/path/to/project","payload":{"id":"evt_01JXXX","type":"session.created","properties":{...}}}

event: message
data: {"payload":{"id":"evt_01JXXX","type":"server.heartbeat","properties":{}}}
```

**GlobalEvent schema:**
```typescript
{
  directory: string
  project?: string
  workspace?: string
  payload: Event | InstanceDisposed | SyncEvent
}
```

Where `SyncEvent` wraps sync events with:
```typescript
{
  type: "sync"
  id: string
  syncEvent: {
    type: string          // versioned type like "session.created.v1"
    id: string
    seq: number
    aggregateID: string
    data: { ... }
  }
}
```

---

## Event Type Registry

All events follow the structure: `{ id: string, type: string, properties: { ... } }`

### Server Events

| Type | Description |
|------|-------------|
| `server.connected` | Emitted on SSE connect |
| `server.heartbeat` | Emitted every 10 seconds as keepalive |
| `server.instance.disposed` | Instance disposed (terminates instance SSE) |
| `global.disposed` | Global dispose (all instances) |

### Session Events (from `@opencode-ai/core`)

| Type | Description |
|------|-------------|
| `session.created` | New session created |
| `session.updated` | Session metadata updated |
| `session.deleted` | Session deleted |
| `session.message.updated` | Message in session updated |
| `session.message.removed` | Message removed from session |
| `session.part.updated` | Message part updated |
| `session.part.removed` | Message part removed |

### Session Events (from `opencode`)

| Type | Description |
|------|-------------|
| `session.agent.switched` | Agent switched within session |
| `session.model.switched` | Model switched within session |
| `session.moved` | Session moved to another project |
| `session.prompted` | User sent a prompt |
| `session.admitted` | Session admitted (from waiting queue) |
| `session.promoted` | Session promoted |
| `session.interrupt.requested` | Interrupt requested |
| `session.context.updated` | Context updated |
| `session.synthetic` | Synthetic session event |
| `session.run.started` | Session run started |
| `session.run.ended` | Session run ended |
| `session.llm.started` | LLM call started |
| `session.llm.ended` | LLM call ended |
| `session.llm.delta` | LLM streaming delta |
| `session.tool.started` | Tool execution started |
| `session.tool.delta` | Tool execution delta |
| `session.tool.ended` | Tool execution ended |
| `session.tool.called` | Tool called by LLM |
| `session.tool.progress` | Tool execution progress |
| `session.tool.success` | Tool execution succeeded |
| `session.tool.failed` | Tool execution failed |
| `session.retried` | Session retried |
| `session.diff` | Session diff computed |
| `session.error` | Session error occurred |
| `session.compacted` | Session compacted/summarized |
| `session.status` | Session status changed |
| `session.idle` | Session became idle |
| `session.message.part.delta` | Message part streaming delta |

### Permission Events

| Type | Description |
|------|-------------|
| `permission.asked` | Permission request created |
| `permission.replied` | Permission replied to |
| `permission.v2.asked` | Permission v2 request |
| `permission.v2.replied` | Permission v2 reply |

### Question Events

| Type | Description |
|------|-------------|
| `question.asked` | Question asked |
| `question.replied` | Question answered |
| `question.rejected` | Question rejected |
| `question.v2.asked` | Question v2 asked |
| `question.v2.replied` | Question v2 replied |
| `question.v2.rejected` | Question v2 rejected |

### Provider / Auth Events

| Type | Description |
|------|-------------|
| `auth.added` | Auth credentials added |
| `auth.removed` | Auth credentials removed |
| `auth.switched` | Auth switched |
| `catalog.model.updated` | Model catalog updated |
| `models-dev.refreshed` | Models dev refreshed |

### PTY Events

| Type | Description |
|------|-------------|
| `pty.created` | PTY session created |
| `pty.updated` | PTY session updated |
| `pty.exited` | PTY session exited |
| `pty.deleted` | PTY session deleted |

### MCP Events

| Type | Description |
|------|-------------|
| `mcp.tools.changed` | MCP tools changed |
| `mcp.browser.open.failed` | MCP browser open failed |

### VCS / Project Events

| Type | Description |
|------|-------------|
| `vcs.branch.updated` | VCS branch updated |
| `project.updated` | Project info updated |
| `project-copy.updated` | Project copy updated |
| `plugin.added` | Plugin added |

### File System Events

| Type | Description |
|------|-------------|
| `filesystem.edited` | File edited |
| `filesystem.watcher.updated` | File watcher update |

### Other Events

| Type | Description |
|------|-------------|
| `todo.updated` | Todo list updated |
| `command.executed` | Command executed |
| `ide.installed` | IDE extension installed |
| `lsp.updated` | LSP server updated |
| `installation.updated` | Installation updated |
| `installation.update.available` | Update available |
| `worktree.ready` | Worktree ready |
| `worktree.failed` | Worktree failed |
| `workspace.ready` | Workspace ready |
| `workspace.failed` | Workspace failed |
| `workspace.status` | Workspace status changed |

### TUI Events (for `/tui/publish`)

| Type | Description |
|------|-------------|
| `tui.prompt.append` | Append to TUI prompt |
| `tui.command.execute` | Execute TUI command |
| `tui.toast.show` | Show TUI toast |
| `tui.session.select` | Select TUI session |

---

## Error Types

All errors follow a tagged error pattern with `name` and `data` fields. HTTP status is set via `httpApiStatus`.

### Generic Errors

| Name | HTTP Status | Fields |
|------|-------------|--------|
| `BadRequest` | 400 | (built-in Effect) |
| `InvalidRequestError` | 400 | `message`, `kind?`, `field?` |
| `UnauthorizedError` | 401 | `message` |
| `ForbiddenError` | 403 | `message` |
| `ConflictError` | 409 | `message`, `resource?` |
| `UpstreamError` | 502 | `message`, `service?`, `status?` |
| `ServiceUnavailableError` | 503 | `message`, `service?` |
| `TimeoutError` | 504 | `message`, `operation?` |
| `UnknownError` | 500 | `message`, `ref?` |

### Domain Errors

| Name | HTTP Status | Fields |
|------|-------------|--------|
| `NotFoundError` | 404 | `{ name: "NotFoundError", data: { message } }` |
| `ProviderNotFoundError` | 404 | `providerID`, `message` |
| `ModelNotFoundError` | 404 | `providerID`, `modelID`, `suggestions[]`, `message` |
| `SessionNotFoundError` | 404 | `sessionID`, `message` |
| `MessageNotFoundError` | 404 | `sessionID`, `messageID`, `message` |
| `SessionBusyError` | 409 | `sessionID`, `message` |
| `QuestionNotFoundError` | 404 | `requestID`, `message` |
| `PermissionNotFoundError` | 404 | `requestID`, `message` |
| `McpServerNotFoundError` | 404 | `name`, `message` |
| `PtyNotFoundError` | 404 | `ptyID`, `message` |
| `PtyForbiddenError` | 403 | `message` |
| `ProjectNotFoundError` | 404 | `projectID`, `message` |
| `InvalidCursorError` | 400 | `message` |
| `VcsApplyError` | 400 | `message`, `reason: "non-git" \| "not-clean"` |
| `WorkspaceWarpError` | 400 | `message` |
| `WorkspaceCreateError` | 400 | `message` |
| `WorktreeError` | 400 | `name` (tagged), `message` |
| `ProjectCopyError` | 400 | `message`, `forceRequired?` |
| `MoveSessionError` | 400 | `message` |
| `ProviderAuthApiError` | 400 | `providerID?`, `field?`, `message?`, `kind?` |
| `McpUnsupportedOAuthError` | 400 | `error` |

**Standard error response format:**
```json
{
  "name": "NotFoundError",
  "data": {
    "message": "Session not found"
  }
}
```

---

## SDK Client

**Package:** `/packages/sdk/js/`
**Generated by:** `@hey-api/openapi-ts`

### Client Structure

The SDK exports `OpencodeClient` as the main class with nested resource groups:

```typescript
import { createOpencodeClient } from "@opencode-ai/sdk"

const client = createOpencodeClient({
  baseUrl: "http://localhost:4096",
  directory: "/path/to/project",  // optional, sets x-opencode-directory header
  headers: {                       // optional, e.g. for auth
    Authorization: "Basic ..."
  }
})

// Resource groups:
client.global       // .event()
client.project      // .list(), .current()
client.pty          // .list(), .create(), .get(), .update(), .remove(), .connect()
client.config       // .get(), .update(), .providers()
client.tool         // .ids(), .list()
client.instance     // .dispose()
client.path         // .get()
client.vcs          // .get()
client.session      // .list(), .create(), .status(), .delete(), .get(), .update(),
                    // .children(), .todo(), .init(), .fork(), .abort(),
                    // .share(), .unshare(), .diff(), .summarize(),
                    // .messages(), .prompt(), .message(), .promptAsync(),
                    // .command(), .shell(), .revert(), .unrevert()
client.command      // .list()
client.provider     // .list(), .auth(), .oauth.authorize(), .oauth.callback()
client.find         // .text(), .files(), .symbols()
client.file         // .list(), .read(), .status()
client.app          // .log(), .agents()
client.mcp          // .status(), .add(), .connect(), .disconnect(),
                    // .auth.remove(), .auth.start(), .auth.callback(), .auth.authenticate()
client.lsp          // .status()
client.formatter    // .status()
client.tui          // .appendPrompt(), .openHelp(), .openSessions(), .openThemes(),
                    // .openModels(), .submitPrompt(), .clearPrompt(), .executeCommand(),
                    // .showToast(), .publish(), .control.next(), .control.response()
client.auth         // .set()
client.event        // .subscribe()
```

### SDK Client Configuration

```typescript
createOpencodeClient(config?: {
  baseUrl?: string           // Server URL
  directory?: string         // Project directory (sets x-opencode-directory header)
  headers?: Record<string, string>  // Extra headers (e.g. Authorization)
  fetch?: typeof fetch       // Custom fetch implementation
})
```

**Request interceptor:** The client rewrites `x-opencode-directory` header to `?directory=` query parameter for GET/HEAD requests.

### Server Lifecycle (SDK)

```typescript
import { createOpencodeServer, createOpencode } from "@opencode-ai/sdk"

// Start server process:
const server = await createOpencodeServer({
  hostname: "127.0.0.1",   // default
  port: 4096,              // default
  signal: abortSignal,
  timeout: 5000,           // default
  config: { ... }          // OpenCode config passed as OPENCODE_CONFIG_CONTENT env var
})
// server.url = "http://127.0.0.1:4096"
// server.close()

// Or use convenience wrapper that creates both server and client:
const { client, server } = await createOpencode({ port: 4096 })
```

The SDK spawns `opencode serve` as a child process and parses stdout for the listening URL.

---

## Desktop App Integration

**Source:** `/packages/desktop/src/main/server.ts`

The Electron desktop app spawns the OpenCode server as an Electron utility process (sidecar):

1. **Spawning:** `utilityProcess.fork(sidecar.js)` with env and stdio pipes.
2. **Start message:** Sends `{ type: "start", hostname, port, password, userDataPath }` to the sidecar.
3. **Ready signal:** Waits for `{ type: "ready" }` message from sidecar (60s timeout).
4. **Health check:** Polls `GET /global/health` with Basic auth header until healthy.
5. **Stop:** Sends `{ type: "stop" }` message, kills process after 6s timeout if not exited.
6. **Default URL:** Stored in electron-store under `DEFAULT_SERVER_URL_KEY`.

**Environment variables set by desktop:**
- `OPENCODE_EXPERIMENTAL_ICON_DISCOVERY=true`
- `OPENCODE_EXPERIMENTAL_FILEWATCHER=true`
- `OPENCODE_CLIENT=desktop`
- `XDG_STATE_HOME` (set to userDataPath on Linux)

---

## Session Lifecycle

### 1. Create Session

```
POST /session
Body: (optional) Session.CreateInput
Response: Session.Info { id, title, directory, ... }
```

### 2. Send a Message (Synchronous)

```
POST /session/:sessionID/message
Body: PromptPayload (from SessionPrompt.PromptInput minus sessionID)
Response: SessionV1.WithParts { info: AssistantMessage, parts: Part[] }
```

This is a blocking call -- the response is returned once the AI finishes processing.

### 3. Send a Message (Asynchronous)

```
POST /session/:sessionID/prompt_async
Body: PromptPayload
Response: No content (returns immediately)
```

Use SSE event stream to receive updates as the AI processes.

### 4. Get Messages

```
GET /session/:sessionID/message
Query: limit?, before?
Response: SessionV1.WithParts[]
```

### 5. Monitor via SSE

```
GET /event?directory=...&workspace=...
Response: text/event-stream
```

Key events during a session lifecycle:
- `session.created` -- new session
- `session.updated` -- metadata changes
- `session.prompted` -- user sent a prompt
- `session.run.started` / `session.run.ended` -- run lifecycle
- `session.llm.started` / `session.llm.delta` / `session.llm.ended` -- LLM streaming
- `session.tool.called` / `session.tool.started` / `session.tool.ended` -- tool execution
- `session.status` / `session.idle` -- status transitions
- `session.part.updated` / `session.part.removed` -- message part changes
- `session.message.updated` / `session.message.removed` -- message changes
- `permission.asked` -- AI needs permission to proceed
- `question.asked` -- AI asks the user a question

### 6. Respond to Permission Request

```
POST /permission/:requestID/reply
Body: { reply: PermissionV1.Reply, message?: string }
Response: boolean
```

Or use the deprecated session-scoped endpoint:
```
POST /session/:sessionID/permissions/:permissionID
Body: { response: PermissionV1.Reply }
```

### 7. Answer Question

```
POST /question/:requestID/reply
Body: { answers: Question.Answer[] }
Response: boolean
```

### 8. Abort / Revert

```
POST /session/:sessionID/abort      -- stop ongoing processing
POST /session/:sessionID/revert     -- revert a specific message (undo file changes)
POST /session/:sessionID/unrevert   -- restore all reverted messages
```

### 9. Fork / Share / Summarize

```
POST /session/:sessionID/fork       -- fork at a specific message
POST /session/:sessionID/share      -- create shareable link
DELETE /session/:sessionID/share    -- remove shareable link
POST /session/:sessionID/summarize  -- AI-compact the session
```

### 10. Delete Session

```
DELETE /session/:sessionID
Response: boolean
```

---

## Additional Endpoints

### OpenAPI Documentation

```
GET /doc
Response: OpenAPI 3.x JSON spec (Content-Type: application/json)
```

This is the auto-generated OpenAPI specification with legacy compatibility transforms applied.

### Web UI

All unmatched routes (`/*`) fall through to the embedded web UI static file server, unless `OPENCODE_DISABLE_EMBEDDED_WEB_UI` is set.

---

## Source File Index

| Path | Purpose |
|------|---------|
| `packages/opencode/src/server/server.ts` | Server bootstrap, listen, mDNS |
| `packages/opencode/src/server/auth.ts` | Basic auth credentials and validation |
| `packages/opencode/src/server/event.ts` | Server-level event definitions |
| `packages/opencode/src/server/cors.ts` | CORS configuration |
| `packages/opencode/src/server/tui-event.ts` | TUI event definitions |
| `packages/opencode/src/server/routes/instance/httpapi/api.ts` | API composition (root + instance) |
| `packages/opencode/src/server/routes/instance/httpapi/server.ts` | Route/handler wiring and layers |
| `packages/opencode/src/server/routes/instance/httpapi/public.ts` | Public OpenAPI spec transform |
| `packages/opencode/src/server/routes/instance/httpapi/errors.ts` | Error type definitions |
| `packages/opencode/src/server/routes/instance/httpapi/lifecycle.ts` | Instance dispose middleware |
| `packages/opencode/src/server/routes/instance/httpapi/groups/*.ts` | Route group definitions |
| `packages/opencode/src/server/routes/instance/httpapi/handlers/*.ts` | Handler implementations |
| `packages/opencode/src/server/routes/instance/httpapi/middleware/*.ts` | Middleware implementations |
| `packages/sdk/js/src/client.ts` | SDK client factory |
| `packages/sdk/js/src/server.ts` | SDK server lifecycle |
| `packages/sdk/js/src/gen/sdk.gen.ts` | Auto-generated SDK methods |
| `packages/desktop/src/main/server.ts` | Desktop sidecar management |
