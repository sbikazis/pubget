---
name: Flutter web build cache
description: The Flutter web preview can fail before opening port 5000 when its pub cache or package config is stale.
---

When a Flutter web workflow reports only `Compiling lib/main.dart` and times out, run `flutter pub get` before changing the workflow or port configuration. A cold web build can then take over a minute, after which the existing server on port 5000 starts normally. Use `scripts/run_replit_web.sh` for verification because a plain `flutter build web` omits the workflow's Firebase dart-defines and serves the configuration-error screen.

**Why:** A stale `_flutterfire_internals` package entry caused misleading missing-package errors and delayed the workflow; the app itself was healthy after dependencies were restored.

**How to apply:** Treat the first timeout as a dependency-cache/build-readiness issue, inspect the workflow log, run the package restore, and only then retry the managed workflow. If the managed timeout repeats after a successful compile, run the project script directly to distinguish startup timeout from an app failure.