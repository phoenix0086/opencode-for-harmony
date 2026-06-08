# M11 API Smoke Matrix

Use only these statuses:

```text
PASS / FAIL / SKIP / BLOCKED
```

Do not leave every row as TODO. If the test has not been run, use BLOCKED and explain why.

| Module | Endpoint | Client Method | Expected Result | Status | Evidence / Notes |
|---|---|---|---|---|---|
| Health | GET /global/health | health() | healthy/version | BLOCKED | Not tested on real server yet |
| Config | GET /config | getConfig() | ConfigInfo | BLOCKED | Not tested on real server yet |
| Config | PATCH /config | updateConfig() | ConfigInfo | BLOCKED | Need PATCH override verification |
| Provider | GET /provider | listProviders() | all/default/connected | BLOCKED | Not tested on real server yet |
| Provider Auth | GET /provider/auth | getAuthMethods() | Auth methods | BLOCKED | Not tested on real server yet |
| Auth | PUT /auth/:id | setAuth() | 200 | BLOCKED | Needs real provider key; do not log key |
| Auth | DELETE /auth/:id | removeAuth() | 200 | BLOCKED | Not tested |
| Project | GET /project/current | getCurrentProject() | Current project | BLOCKED | Not tested |
| Path | GET /path | getPaths() | PathInfo | BLOCKED | Not tested |
| File | GET /file?path= | listFiles() | File list | BLOCKED | Not tested |
| File | GET /file/content?path= | readFile() | File content | BLOCKED | Not tested |
| VCS | GET /vcs | getVcsInfo() | branch/default_branch | BLOCKED | Not tested |
| VCS Status | GET /vcs/status | getVcsStatus() | VcsFileStatus[] | BLOCKED | Not tested |
| VCS Diff | GET /vcs/diff?mode=git | getVcsDiff("git") | FileDiff[] | BLOCKED | Not tested |
| Session | GET /session | listSessions() | SessionInfo[] | BLOCKED | Not tested |
| Session | POST /session | createSession() | SessionInfo | BLOCKED | Not tested |
| Message | GET /session/:id/message | getMessages() | NormalizedMessage[] | BLOCKED | Not tested |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | 204/200 | BLOCKED | Not tested |
| Permission | GET /permission | listPermissions() | PermissionRequest[] | BLOCKED | Not tested |
| Permission Reply | POST /permission/:id/reply | replyPermission() | 200 | BLOCKED | Not tested |
| Session Diff | GET /session/:id/diff?messageID= | getSessionDiff() | FileDiff[] | BLOCKED | Need assistant messageID |
| Agent | GET /agent | listAgents() | AgentInfo[] | BLOCKED | Not tested |
| Event | GET /event | getEventStreamUrl() | SSE reachable | SKIP | ArkTS currently uses polling compatibility mode |
