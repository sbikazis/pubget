# Phase-01 Unified schemaVersion Contract

Date: 2026-09-21
Convention: every **main** document written by the server carries `schemaVersion`.
READING path: clients tolerate a missing field (legacy docs) by defaulting to the lowest known version.
No destructive migration was performed; this contract is forward-only.

## Registry (canonical per document type)

| Document (collection/path) | Version | Constant (server) | Client mirror |
|---|---|---|---|
| `edits` field `schemaVersion` (incl. `editUploadKeys`) | **2** | `editsConfig.js:21` `schemaVersion: 2` (written `editsDomain.js:160/225`) | `edit_models.dart:100` default **1** (read `:269`) — see §Divergence |
| `games` root doc (system game record) | **2** | `gamesDomain.js:679` inline | `games_schema_v2.dart:5` `gamesSchemaVersion = 2` ✓ |
| `games/{id}/events` event records | **1** | `gamesDomain.js:84` `EVENT_SCHEMA_VERSION=1` (written `:255/:1220`) | `game_engine.dart:345` `schemaVersion = 1` ✓ |
| `fanWorks` root doc | **1** | `fanWorksDomain.js:53` `SCHEMA_VERSION=1` (written `:496/:529/:628`) | `fan_work_models.dart:421` default 1 ✓ |
| Mafia game docs (in `games`) | **1** | `mafiaDomain.js:312` inline 1 | game/model consumers tolerate ✓ |
| Economy transaction ledger records | **1** | `economyConfig.js:7` `SCHEMA_VERSION=1` (written `economyDomain.js:247/446/475/563/575`) | `economy_models.dart:160` default 1 ✓ |
| Reels / audio (dead module, **not wired** into `index.js`) | **1** | `reelsConfig.js`, `audioDomain.js:111` | `audio_models.dart:27` default 1 ✓ |

## Statement of unification

- All **live** writers already emit `schemaVersion` (verified above). None emit inconsistent values.
- `games` is intentionally TWO schemas (root=2 for system games, events=1 for append-only event records); both are versioned individually.
- Rules: callable-written docs are not field-whitelisted by Firestore rules, so additive `schemaVersion` never conflicts with the emulator suites (49/12 green with unmodified rules).

## §Divergence (the only one found)

`lib/features/edits/models/edit_models.dart:100` defaults `schemaVersion` to **1** while the
server writes **2** for every modern edit. Impact is benign:
- Server-produced edits arrive with `schemaVersion: 2` and it is preserved on read.
- Default 1 only applies to (a) locally constructed drafts before upload and (b) legacy docs lacking the field.
- Client never writes `schemaVersion` to Firestore for edits (upload path is server-owned).

Recommendation (deferred — out of Phase-01 scope to avoid churn against feature branch in flight):
align the constructor default to the server contract constant `2` and keep `?? 1` only in the
legacy-read path with an explicit comment. Tracked as an open item (OPEN-1).

## Enforcement

`npm run check` (node syntax) + rules/unit suites (RULES_GATE.md) are the gate; this registry is the
single source of truth and must be updated whenever a schema version is bumped.