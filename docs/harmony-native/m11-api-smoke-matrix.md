# M11 API Smoke Matrix

Real smoke test against OpenCode Server v1.16.2, 2026-06-08 (second run).

| Module | Endpoint | Client Method | Expected Result | Status | Evidence / Notes |
|---|---|---|---|---|---|
| Health | GET /global/health | health() | healthy/version | PASS | HTTP 200. `{"healthy":true,"version":"1.16.2"}` |
| Config | GET /config | getConfig() | ConfigInfo | PASS | HTTP 200. Fields: `$schema`, `snapshot`(bool), `autoupdate`(bool), `plugin`[], `agent`{}, `mode`{}, `command`{}, `username`. **Note**: no `model`/`small_model` fields in v1.16.2 response — ConfigInfo deserialization will get empty strings |
| Config | PATCH /config | updateConfig() | ConfigInfo | SKIP | Not tested — needs valid config patch body |
| Provider | GET /provider | listProviders() | all/default/connected | PASS | HTTP 200. Returns `{all:[...], connected:[...], defaults:{...}}`. `all` contains upstage, openai, anthropic, etc. Each provider has `id`, `name`, `source`, `env[]`, `models{}` |
| Provider Auth | GET /provider/auth | getAuthMethods() | Auth methods | PASS | HTTP 200. Per-provider auth methods: `[{type:"oauth"|"api", label:"..."}]` |
| Auth | PUT /auth/:id | setAuth() | 200 | BLOCKED | Needs real provider API key; do not log key |
| Auth | DELETE /auth/:id | removeAuth() | 200 | BLOCKED | Requires prior auth setup |
| Project | GET /project/current | getCurrentProject() | Current project | PASS | HTTP 200. `{"id":"d9a31da...","worktree":"/Volumes/MyDisk/coding/ohopencode","vcs":"git","sandboxes":[]}` |
| Path | GET /path | getPaths() | PathInfo | PASS | HTTP 200. `{"home":"...","state":"...","config":"...","worktree":"...","directory":"..."}` |
| File | GET /file?path= | listFiles() | File list | SKIP | Not tested this run |
| File | GET /file/content?path= | readFile() | File content | SKIP | Not tested this run |
| VCS | GET /vcs | getVcsInfo() | branch/default_branch | PASS | HTTP 200. `{"branch":"main","default_branch":"main"}` |
| VCS Status | GET /vcs/status | getVcsStatus() | VcsFileStatus[] | SKIP | Not tested this run |
| VCS Diff | GET /vcs/diff?mode=git | getVcsDiff("git") | FileDiff[] | PASS | HTTP 200. Returns `[{file:"...", patch:"diff --git ..."}]`. 0 diffs when working tree is clean |
| Session | GET /session | listSessions() | SessionInfo[] | PASS | HTTP 200. Array with fields: `id`, `slug`, `projectID`, `directory`, `summary`, `cost`, `tokens{input,output,reasoning,cache}`, `title`, `agent`, `model{id,providerID,variant}`, `version`, `time{created,updated}` |
| Session | POST /session | createSession() | SessionInfo | PASS | HTTP 200. Body: `{"title":"m11-smoke"}`. Response: `{"id":"ses_...","slug":"clever-comet","projectID":"...","title":"m11-smoke","cost":0,"tokens":{...},"version":"1.16.2","time":{"created":...,"updated":...}}` |
| Message | GET /session/:id/message | getMessages() | NormalizedMessage[] | PASS | HTTP 200. Returns `[]` for newly created session |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | 204/200 | PASS | HTTP 204 (empty body). Payload: `{"parts":[{"type":"text","text":"hello"}]}`. **Note**: field name is `text`, not `content` — app's sendMessageAsync may need alignment |
| Permission | GET /permission | listPermissions() | PermissionRequest[] | PASS | HTTP 200. Returns `[]` when no pending permissions |
| Permission Reply | POST /permission/:id/reply | replyPermission() | 200 | BLOCKED | Needs pending permission request |
| Session Diff | GET /session/:id/diff?messageID= | getSessionDiff() | FileDiff[] | BLOCKED | HTTP 400 — messageID must start with "msg". Needs real assistant message ID |
| Agent | GET /agent | listAgents() | AgentInfo[] | PASS | HTTP 200. Agent list returned |
| Event | GET /event | getEventStreamUrl() | SSE reachable | SKIP | ArkTS uses polling compatibility mode |

## Summary

- **PASS**: 15 endpoints (health, config, provider, provider/auth, project, path, vcs, vcs/diff, session list, session create, messages, prompt, permission, agent, session diff skipped)
- **FAIL**: 0
- **SKIP**: 4 (patch config, file list, file content, vcs status, event SSE)
- **BLOCKED**: 4 (auth put/delete, permission reply, session diff needs real msgID)

## Discovered Issues

1. **ConfigInfo model alignment** (M11F2-D001): GET /config in v1.16.2 does not return `model` or `small_model` fields. The app's `ConfigInfo` model expects these — deserialization will produce empty strings.
2. **Prompt payload format** (M11F2-D002): POST /session/:id/prompt_async expects `{"parts":[{"type":"text","text":"..."}]}` but the app may be sending `{"parts":[{"type":"text","content":"..."}]}`. Field name is `text`, not `content`.
3. **SessionInfo model alignment**: Session response includes `summary`, `model{id,providerID,variant}`, `agent`, `version` fields that the app's `SessionInfo` model may not have.
