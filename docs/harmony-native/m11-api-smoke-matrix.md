# M11 API Smoke Matrix

| 模块 | Endpoint | OpenCodeClient 方法 | 请求体/参数 | 预期结果 | 状态 | 备注 |
|---|---|---|---|---|---|---|
| Health | GET /global/health | health() | 无 | healthy/version | TODO |  |
| Config | GET /config | getConfig() | 无 | ConfigInfo | TODO |  |
| Config | PATCH /config | updateConfig() | config patch | ConfigInfo | TODO | 注意 PATCH/Method Override |
| Provider | GET /provider | listProviders() | 无 | all/default/connected | TODO |  |
| Provider Auth | GET /provider/auth | getAuthMethods() | 无 | Auth methods | TODO |  |
| Auth | PUT /auth/:id | setAuth() | {type:"api",key} | 200 | TODO | 禁止记录 key |
| Auth | DELETE /auth/:id | removeAuth() | provider id | 200 | TODO |  |
| Project | GET /project/current | getCurrentProject() | 无 | 当前项目 | TODO |  |
| Path | GET /path | getPaths() | directory | path info | TODO |  |
| File | GET /file?path= | listFiles() | path | FileNode[] | TODO |  |
| File | GET /file/content?path= | readFile() | path | file content | TODO |  |
| VCS | GET /vcs | getVcsInfo() | directory | branch/default_branch | TODO |  |
| VCS Status | GET /vcs/status | getVcsStatus() | directory | VcsFileStatus[] | TODO |  |
| VCS Diff | GET /vcs/diff?mode=git | getVcsDiff("git") | directory | FileDiff[] | TODO |  |
| Session | GET /session | listSessions() | limit optional | SessionInfo[] | TODO |  |
| Session | POST /session | createSession() | title optional | SessionInfo | TODO |  |
| Session | GET /session/:id | getSession() | sessionID | SessionInfo | TODO |  |
| Session | POST /session/:id/abort | abortSession() | sessionID | 200 | TODO |  |
| Message | GET /session/:id/message | getMessages() | sessionID | NormalizedMessage[] | TODO |  |
| Prompt | POST /session/:id/prompt_async | sendMessageAsync() | agent + parts | 204/200 | TODO |  |
| Permission | GET /permission | listPermissions() | 无 | PermissionRequest[] | TODO |  |
| Permission Reply | POST /permission/:id/reply | replyPermission() | once/deny | 200 | TODO |  |
| Session Diff | GET /session/:id/diff?messageID= | getSessionDiff() | sessionID + messageID | FileDiff[] | TODO | messageID 不能为空 |
| Agent | GET /agent | listAgents() | 无 | AgentInfo[] | TODO |  |
| Event | GET /event | getEventStreamUrl() | directory | SSE/可访问 | TODO | ArkTS 当前用轮询替代 |
