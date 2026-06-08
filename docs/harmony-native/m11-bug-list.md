# M11-Fix Bug List

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
