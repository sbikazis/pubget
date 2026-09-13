# Pubget

Pubget is a Flutter anime community application built on Firebase
(Authentication, Firestore, Storage, Cloud Functions, Cloud Messaging, and
Hosting). It supports Arabic and English, with a mobile-first Android target
and a web release.

## Structure

- `lib/` — Flutter client (features, providers, repositories, design system)
- `functions/` — Cloud Functions backend (domain modules, game engines, Mafia)
- `firestore.rules` / `storage.rules` — security rules
- `firestore.indexes.json` — composite index definitions
- `test/` — Flutter tests
- `functions/test/` — backend unit and emulator rule/E2E tests
- `docs/` — product spec, rebuild matrix, state master, and domain docs

## Documentation

- `docs/PUBGET_1_0_SPEC.md` — locked product specification for 1.0
- `docs/PUBGET_1_0_REBUILD_MATRIX.md` — live fix/rebuild/delete/keep list
- `docs/CURRENT_STATE_MASTER.md` — working-baseline state and traceability

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

```bash
cd functions
npm install
npm run check
npm test
```

Firestore/Storage rules and emulator E2E tests:

```bash
npm install
npm test
```