# M11 API Smoke Matrix

Real smoke test against OpenCode Server v1.16.2, 2026-06-08 (third run — agent flow test).

| Module | Endpoint | Client Method | Expected Result | Status | Evidence / Notes |
|---|---|---|---|---|---|
| Health | GET /global/health | health() | healthy/version | PASS | HTTP 200. `{"healthy":true,"version":"1.16.2"}` |
| Config | GET /config | getConfig() | ConfigInfo | PASS | HTTP 200. Fields: `$schema`, `snapshot`(bool), `autoupdate`(bool), `plugin`[], `agent`{}, `mode`{}, `command`{}, `username`. **Note**: no `model`/`small_model` fields in v1.16.2 response — ConfigInfo gets empty strings |
| Config | PATCH /config | updateConfig() | ConfigInfo | SKIP | Not tested — needs valid config patch body |
| Provider | GET /provider | listProviders() | all/default/connected | PASS | HTTP 200. Returns `{all:[...], connected:[...], defaults:{...}}`. Each provider has `id`, `name`, `source`, `env[]`, `models{}` |
| Provider Auth | GET /provider/auth | getAuthMethods() | Auth methods | PASS | HTTP 200. Per-provider auth methods: `[{type:"oauth"\|"api", label:"..."}]` |
| Auth | PUT /auth/:id | setAuth() | 200 | BLOCKED | Needs real provider API key; do not log key |
| Auth | DELETE /auth/:id | removeAuth() | 200 | BLOCKED | Requires prior auth setup |
| Project | GET /project/current | getCurrentProject() | Current project | PASS | HTTP 200. `{"id":"d9a31da...","worktree":"...","vcs":"git","sandboxes":[]}` |
| Path | GET /path | getPaths() | PathInfo | PASS | HTTP 200. `{"home":"...","state":"...","config":"...","worktree":"...","directory":"..."}` |
| File | GET /file?path= | listFiles() | File list | SKIP | Not tested this run |
| File | GET /file/content?path= | readFile() | File content | SKIP | Not tested this run |
| VCS | GET /vcs | getVcsInfo() | branch/default_branch | PASS | HTTP 200. `{"branch":"main","default_branch":"main"}` |
| VCS Status | GET /vcs/status | getVcsStatus() | VcsFileStatus[] | SKIP | Not tested this run |
| VCS Diff | GET /vcs/diff?mode=git | getVcsDiff("git") | FileDiff[] | PASS | HTTP 200. Returns `[{file:"...", patch:"diff --git ..."}]` |
| Session | GET /session | listSessions() | SessionInfo[] | PASS | HTTP 200. Fields: `id`, `slug`, `projectID`, `directory`, `summary`, `cost`, `tokens{}`, `title`, `agent`, `model{id,providerID,variant}`, `version`, `time{}` |
| Session | POST /session | createSession() | SessionInfo | PASS | HTTP 200. `{"id":"ses_158f60ccfffe...","slug":"playful-meadow","projectID":"global","title":"m11-agent-flow-test","cost":0,"tokens":{},"version":"1.16.2"}` |
| Message | GET /session/:id/message | getMessages() | WithParts[] | PASS | HTTP 200. Full round-trip verified: 5 messages after 2 prompts. Structure: `{info:{id,role,sessionID,agent,modelID,providerID,...}, parts:[{type,text,callID,tool,state,...}]}`. Part types seen: `text`, `tool`, `reasoning`, `step-start`, `step-finish` |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | 204/200 | PASS | HTTP 204. Full round-trip: sent "Say hello" → assistant replied "Hello." in ~3s. Then sent file-write prompt → agent used `write` tool → replied "Done." |
| Permission | GET /permission | listPermissions() | PermissionRequest[] | PASS | HTTP 200. Returns `[]` when no pending permissions |
| Permission Reply | POST /permission/:id/reply | replyPermission() | 200 | BLOCKED | Server auto-approved file write without triggering permission. No pending permission to test against |
| Session Diff | GET /session/:id/diff?messageID= | getSessionDiff() | FileDiff[] | PASS | HTTP 200 with real `msg_` ID (`msg_ea70a8046001...`). Returns `[]` because workspace is not a git repo — endpoint itself works correctly |
| Agent | GET /agent | listAgents() | AgentInfo[] | PASS | HTTP 200. Agent list returned |
| Event | GET /event | getEventStreamUrl() | SSE reachable | SKIP | ArkTS uses polling compatibility mode |

## Summary

- **PASS**: 15 endpoints (health, config, provider, provider/auth, project, path, vcs, vcs/diff, session list, session create, messages, prompt, permission, session diff, agent)
- **FAIL**: 0
- **SKIP**: 5 (patch config, file list, file content, vcs status, event SSE)
- **BLOCKED**: 3 (auth PUT, auth DELETE, permission reply — server auto-approves)

## Agent Flow Test Evidence

Session: `ses_158f60ccfffe9CcFFHVp9p6J9b` (slug: playful-meadow)

1. **Create session** → POST /session → 200, session ID returned
2. **Send "Say hello"** → POST /session/:id/prompt_async → 204
3. **Poll messages** → GET /session/:id/message → 2 messages in ~3s
   - msg_0: role=user, text="Say hello in one sentence. Do not use any tools."
   - msg_1: role=assistant, text="Hello.", parts=[step-start, reasoning, text, step-finish]
4. **Send "Create hello.txt"** → POST /session/:id/prompt_async → 204
5. **Poll messages** → 5 messages total, new messages:
   - msg_2: role=user, text="Create a file called hello.txt..."
   - msg_3: role=assistant, parts=[step-start, reasoning, **tool**(write), step-finish]
     - Tool part: `{type:"tool", callID:"call_00_...", tool:"write", state:{status:"completed", input:{filePath:"...", content:"Hello World"}, output:"Wrote file successfully."}}`
   - msg_4: role=assistant, text="Done."
6. **Session diff** → GET /session/:id/diff?messageID=msg_ea70a8046001... → 200 `[]` (non-git workspace)
7. **Permission** → GET /permission → `[]` (auto-approved, no permission triggered)

## Discovered Issues

1. **ConfigInfo model alignment** (M11F2-D001): GET /config in v1.16.2 does not return `model` or `small_model` fields. The app's `ConfigInfo` model expects these — deserialization produces empty strings. App handles this via fallback to session.model on selectSession().
2. **Prompt payload format** (M11F2-D002): POST /session/:id/prompt_async expects `{"parts":[{"type":"text","text":"..."}]}` — field name is `text`, not `content`. App's `buildPromptBody()` already correct.
3. **SessionInfo model alignment** (M11F2-D003): Session response includes `model{id,providerID,variant}` — fixed in M11-Fix3 (modelID→id).
4. **RawPart tool structure alignment** (M11F3-D004): Real API uses `type:"tool"` with nested `state:{status, input, output}` object, NOT `type:"tool-invocation"` with flat fields (`toolInvocationId`, `toolName`, `args`, `result`). **FIXED in this run**: RawPart updated to `{type, text, id, callID, tool, state:{...}}`, normalizeMessages() updated to extract from nested state.
