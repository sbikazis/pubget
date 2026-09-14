# PUBGET — PROJECT STATE (LOG / KNOWN ISSUES / FOLLOW-UP)

Living document for the current branch state, unblocked issues, and follow-up items. Append, do not rewrite history blithely.

## Branch: cursor/chat-phase-b (Chat Phase B close, 2026-09-14)

### Phased change summary (`95eec93..67fdcf7`)

Phase B (chat system repair) is implemented and verified. Scope-of-commit summary lives in `docs/CURRENT_STATE_MASTER.md`; deployment and testing notes below.

- `functions/src/groupChat.js` — edit-window permission gate + media-requirements hardening verified locally via `node --check` and `node --test test/groupsDomain.test.js test/groupChat.test.js` (26/26 pass). **NOT deployed** — run `firebase deploy --only functions` manually.
- Client chat code + chat tests: `flutter analyze` clean (0 err / 0 warn). Chat-scope test batch 46/46 pass.

## Known Issues

### K1 — Pre-existing full-suite failures (NOT phase-B regressions; fail identically on base `95eec93`)

Verified empirically: the exact same 5 test files were run in a temp git worktree at base `95eec93` and reproduce the same 8 failures byte-for-byte at HEAD.

| # | Test file | Failure | Root cause shape |
|---|-----------|---------|------------------|
| 1 | `test/app_shell_test.dart` "Drawer items route to existing destinations" | `ensureVisible(drawer-settings)` → `Bad state: No element` | Shell drawer no longer exposes a `drawer-settings` key/destination that the test taps; stale test fixture. |
| 2 | `test/chat_message_bubble_golden_test.dart` "golden whatsapp bubbles" | `Pixel test failed, 3.85%, 12658px diff` against `test/goldens/chat_message_bubble_whatsapp.png` | Golden is stale relative to current bubble rendering (or environment-dependent fonts). Bubble widget itself unchanged by phase B. Regenerate after reviewing the isolated diff, ideally under the CI golden baseline. |
| 3 | `test/edits_pipeline_hardening_test.dart` "mapEditException never surfaces raw Storage unauthorized text" | Expected `contains 'securely'`, actual copy is `…blocked by storage security…` | Copy drift between the test and `mapEditException` in `lib/features/edits/repositories/firebase_edits_repository.dart`. |
| 4 | `test/edits_pipeline_hardening_test.dart` "Arabic EditCopy hides technical auth failures" | Expected `contains 'تعذر'`, actual `تم حظر الرفع بواسطة أمان التخزين…` | Same copy drift (Arabic branch of the edits copy). |
| 5 | `test/group_bans_page_test.dart` "authorized user can unban a banned member" | `Bad state: No element` in `WidgetController.tap` (banned-users row finder) | Bans page fixture/empty-state mismatch (page predates MIKADO rework). |
| 6 | `test/group_bans_page_test.dart` "unauthorized user cannot unban" | `Found 0 widgets with text "You cannot manage bans"` | Copy no longer matches the visible bans-page copy. |
| 7 | `test/group_details_rebuild_test.dart` "founder details show identity, type, and open chat" | `group-hero-badges` key not found | Group details hero rebuilt pre-phase-B; test expects removed key. |
| 8 | `test/group_details_rebuild_test.dart` "control panel follows live rank permissions" | `group-quick-stats` key not found | Same key lifecycle drift. |

Each is in a feature area outside the chat scope (shell, edits, group bans/details) or a stale golden. Recommend a dedicated follow-up sweep.

## Follow-up

- [ ] `firebase deploy --only functions` (groupChat callables) — manual deploy required, cannot run from this session.
- [ ] `flutter build apk --debug` — was interrupted during phase-B close; rebuild and smoke-test on device.
- [ ] K1 sweep: fix or refresh the 8 pre-existing failures above (separate branch/PR recommended).
- [ ] Manual chat testing checklist (see PR/report): recent/favorite sticker strip, voice slide-to-cancel + lock, composer send freeze while offline, failed-media reuse on retry, private-chat retry no double-send, long-press overlay reaction gating, truthful security banner locale.

## Older entries (pre-phase-B)

None retained in this log at the time of creation. Start appending from here.