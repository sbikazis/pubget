# Achievements hard verification (live emulator)

Date: 2026-09-09  
Branch: `cursor/achievements-system-bf82`  
Harness: `functions/test/achievements.live.emulator.test.js`  
Command: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run test:achievements:live`

## 1) Client write deny (checklist item 10) — PASS (live emulator)

FirestoreFirestore Emulator on `127.0.0.1:8080`. Authenticated client `alice` attempted:

- `user_achievements/alice/unlocked/the_threshold` set → **PERMISSION_DENIED** (rules L828)
- `user_achievements/alice/unlocked/arena_sovereign` set → **assertFails**
- `user_achievement_progress/alice/progress/the_threshold` set → **assertFails**
- `user_achievement_stats/alice` set → **assertFails**

Emulator log excerpt:

```
@firebase/firestore: ... RPC 'Write' ... Code: 7 Message: 7 PERMISSION_DENIED:
false for 'create' @ L828, false for 'update' @ L828
```

This is a real emulator permission error, not a code-read assumption.

## 2) Threshold path — PASS on emulator / wiring; device UI blocked in this VM

**Server chain proven live:**

`evaluate({ type: 'group_joined' })` → unlocks `the_threshold` → writes `unlockedAt` + progress `1/1` in Firestore emulator (<5s).

**Wiring fixes (were broken before this pass):**

- `joinGroup` / `acceptJoinRequest` now call `achievements.evaluate({ type: 'group_joined' })`
- `groupChat.sendMessage` now calls `achievements.evaluate({ type: 'message_sent' })`
- `parseCharacter` no longer rejects open-group joins that omit a character

**Not available in this Cloud VM:** physical Android/iOS device, so Unlock Celebration on-screen, 56px profile strip, and Functions production logs on a real handset were **not** observed here. Flutter devices present: Linux desktop + Chrome only.

## 3) Arena Sovereign numeric progress — PASS on emulator + live watch fix

Live emulator: 18× `game_won` → progress `currentValue=18` readable by client; continue to 30 → unlock with `unlockedAt`.

**Production bug fixed:** `game_won` from `gamesDomain` did not pass `realWins`, so progress never auto-incremented. `evaluate` now increments wins/games on each `game_won`, and `game_completed` counts non-winners without double-counting winners.

**Client bug fixed:** `FirebaseAchievementRepository.watch` previously listened only to `unlocked` snapshots and one-shot-fetched progress (UI would not refresh progress without unlock/reopen). It now listens to **both** `unlocked` and `progress` snapshots.

Widget test: progress mode updates `18/30` → `19/30` when watch emits (no manual page reopen).

## 4) Reduce Motion — PARTIAL

Widget test with `MediaQueryData(disableAnimations: true)` confirms badges remain static (code path used by OS Reduce Motion). **No Android Accessibility Settings device** in this environment — OS-level visual confirmation still needs a handset/emulator with system Reduce Motion enabled.

## 5) Composites (Legend + Dragon) — PASS on live emulator (same call chain)

After seeding 4 base unlocks, `unlock(worldsmith)` triggered `evaluateComposites` in-process and wrote `legend_of_the_gate` with `source: composite` and `unlockedAt` in **the same chain** (no app reopen; <5s). Granting `crownbearer` with age ≥730 then unlocked `dragon_of_legacy` automatically.

## How to re-run

```bash
# Terminal A
firebase emulators:start --only firestore --project demo-pubget-achievements-live

# Terminal B
cd functions && npm run test:achievements:live
cd functions && npm run test:achievements:live  # or node --test test/achievementsWiring.test.js test/achievementsDomain.test.js
```
