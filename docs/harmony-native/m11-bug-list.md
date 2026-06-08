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

## Discovered Issues (from smoke test)

| ID | Severity | Area | Problem | Status |
|---|---|---|---|---|
| M11F2-D001 | Medium | ConfigInfo | GET /config response has no `model`/`small_model` fields in v1.16.2 — ConfigInfo deserialization may get empty values | TODO — needs model alignment |
| M11F2-D002 | Medium | Prompt | POST /session/:id/prompt_async expects `{"parts":[{"text":"..."}]}` not `{"parts":[{"content":"..."}]}` — app sendMessageAsync payload may be wrong | TODO — needs payload fix |
