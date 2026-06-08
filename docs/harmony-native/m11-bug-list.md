# M11-Fix Bug List

## M11-Fix (Round 1)

| ID | Severity | Area | Problem | Fix | Status |
|---|---|---|---|---|---|
| M11F-001 | High | Docs | README overclaims M11/M12 completion | Mark as In Progress until real smoke results exist | DONE |
| M11F-002 | High | EventStreamClient | Same message ID updates are missed | Add message fingerprint tracking | DONE |
| M11F-003 | Medium | EventStreamClient | setSessionId does not fully reset polling state | Reset mode/errors/fingerprints/llm flag | DONE |
| M11F-004 | High | Diff | Tool success refresh can use stale assistant message ID | Await loadMessages before loadDiffs via refreshAfterToolSuccess() | DONE |
| M11F-005 | High | Provider | API Key save is local only | Add server auth write via OpenCodeClient.setAuth + connected check | DONE |
| M11F-006 | High | Security | Config preview can expose API keys | Mask by default (generatePreviewConfig); secrets only via explicit generateConfigWithSecrets | DONE |
| M11F-007 | Medium | SessionTabs | Tabs can become stale after async session load | Already addressed in M19.1 (syncSessionTabs) | DONE |
| M11F-008 | High | Verification | Smoke matrix still all TODO | Updated to BLOCKED with reasons | DONE |

## M11-Fix2 (Round 2)

| ID | Severity | Area | Problem | Fix | Status |
|---|---|---|---|---|---|
| M11F2-001 | High | Security | generateConfig() called generateConfigWithSecrets by default | Changed to generatePreviewConfig(); status text says "密钥已脱敏" | DONE |
| M11F2-002 | High | Security | HeaderList shows header values in plaintext | Use providerRegistry.maskApiKey(h.value) for display | DONE |
| M11F2-003 | High | UI | SessionTabs @State out of sync with sessions | Removed internal @State sessionTabs; computeTabs() derives from sessions @Prop directly | DONE |
| M11F2-004 | Medium | Verification | Smoke matrix needs real PASS/FAIL | Ran smoke test against OpenCode v1.16.2: 15 PASS, 0 FAIL, 4 SKIP, 4 BLOCKED | DONE |

## M11-Fix3 (Round 3 — SessionModel alignment)

| ID | Severity | Area | Problem | Fix | Status |
|---|---|---|---|---|---|
| M11F3-001 | High | SessionModel | API returns `model.id` not `model.modelID` | Renamed SessionModel field to `id`; updated Index.ets, SessionSidebar.ets | DONE |

## M11-Fix4 (Round 4 — Build fix + Agent flow alignment)

| ID | Severity | Area | Problem | Fix | Status |
|---|---|---|---|---|---|
| M11F4-001 | High | StorageService | `store.clear()` causes build error at line 148 | Replaced with explicit key-by-key deletion | DONE |
| M11F4-002 | High | RawPart | API tool parts use `type:"tool"` with nested `state:{status,input,output}`, not `type:"tool-invocation"` with flat fields | Updated RawPart to `{type,text,id,callID,tool,state:{}}`; normalizeMessages() extracts from nested state | DONE |
| M11F4-003 | Medium | Smoke matrix | SKIP count was 4 but should be 5; PASS count was 15 but "session diff skipped" misclassified | Corrected to PASS:15, SKIP:5, BLOCKED:3 | DONE |

## Discovered Issues (from smoke test)

| ID | Severity | Area | Problem | Status |
|---|---|---|---|---|
| M11F2-D001 | Medium | ConfigInfo | GET /config response has no `model`/`small_model` fields in v1.16.2 — ConfigInfo deserialization gets empty strings | DONE — app handles via fallback to session.model in selectSession() |
| M11F2-D002 | Medium | Prompt | POST /session/:id/prompt_async expects `{"parts":[{"text":"..."}]}` not `{"parts":[{"content":"..."}]}` | DONE — buildPromptBody() already uses `text` field correctly |
| M11F2-D003 | High | SessionModel | Session response uses `model.id` not `model.modelID` | DONE — fixed in M11-Fix3 |
| M11F3-D004 | High | RawPart | Real API tool parts: `type:"tool"`, `callID`, `tool`, nested `state:{status,input,output}` — NOT `type:"tool-invocation"` with flat fields | DONE — fixed in M11-Fix4 |
