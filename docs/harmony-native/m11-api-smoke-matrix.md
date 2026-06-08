# M11 API Smoke Matrix

Real smoke test against OpenCode Server v1.16.2, 2026-06-08.

| Module | Endpoint | Client Method | Expected Result | Status | Evidence / Notes |
|---|---|---|---|---|---|
| Health | GET /global/health | health() | healthy/version | PASS | `{"healthy":true,"version":"1.16.2"}` HTTP 200 |
| Config | GET /config | getConfig() | ConfigInfo | PASS | HTTP 200. Fields: `$schema`, `snapshot`, `autoupdate`, `plugin`, `agent`, `mode`, `command`, `username`. Note: `model`/`small_model` not in response — ConfigInfo model may need alignment |
| Config | PATCH /config | updateConfig() | ConfigInfo | SKIP | Needs valid config patch body |
| Provider | GET /provider | listProviders() | all/default/connected | PASS | HTTP 200. `{all:[...], connected:[...], defaults:{...}}`. Includes upstage, openai, anthropic, etc. |
| Provider Auth | GET /provider/auth | getAuthMethods() | Auth methods | PASS | HTTP 200. Returns auth methods per provider (oauth, api) |
| Auth | PUT /auth/:id | setAuth() | 200 | BLOCKED | Needs real provider API key; do not log key |
| Auth | DELETE /auth/:id | removeAuth() | 200 | BLOCKED | Requires prior auth setup |
| Project | GET /project/current | getCurrentProject() | Current project | PASS | HTTP 200. `{"id":"d9a31da...","worktree":".../ohopencode","vcs":"git"}` |
| Path | GET /path | getPaths() | PathInfo | PASS | HTTP 200. `home`, `state`, `config`, `worktree`, `directory` |
| File | GET /file?path= | listFiles() | File list | SKIP | Not tested this run |
| File | GET /file/content?path= | readFile() | File content | SKIP | Not tested this run |
| VCS | GET /vcs | getVcsInfo() | branch/default_branch | PASS | HTTP 200. `{"branch":"main","default_branch":"main"}` |
| VCS Status | GET /vcs/status | getVcsStatus() | VcsFileStatus[] | SKIP | Not tested this run |
| VCS Diff | GET /vcs/diff?mode=git | getVcsDiff("git") | FileDiff[] | PASS | HTTP 200. Array of `{file, patch}` for uncommitted changes |
| Session | GET /session | listSessions() | SessionInfo[] | PASS | HTTP 200. `[]` initially, populated after POST |
| Session | POST /session | createSession() | SessionInfo | PASS | HTTP 200. Created with `id`, `slug`, `projectID`, `title`, `cost`, `tokens` |
| Message | GET /session/:id/message | getMessages() | NormalizedMessage[] | PASS | HTTP 200. `[]` for new session |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | 204/200 | PASS | HTTP 204 with `{"parts":[{"type":"text","text":"..."}]}`. Note: field is `text` not `content` |
| Permission | GET /permission | listPermissions() | PermissionRequest[] | PASS | HTTP 200. `[]` when no pending permissions |
| Permission Reply | POST /permission/:id/reply | replyPermission() | 200 | BLOCKED | Needs pending permission request |
| Session Diff | GET /session/:id/diff?messageID= | getSessionDiff() | FileDiff[] | BLOCKED | HTTP 400 — messageID must start with "msg". Needs real assistant messageID |
| Agent | GET /agent | listAgents() | AgentInfo[] | PASS | HTTP 200. Agent list returned |
| Event | GET /event | getEventStreamUrl() | SSE reachable | SKIP | ArkTS uses polling compatibility mode |
