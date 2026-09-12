---
name: Flutter web build cache
description: The Flutter web preview can fail before opening port 5000 when its pub cache or package config is stale.
---

When a Flutter web workflow reports only `Compiling lib/main.dart` and times out, run `flutter pub get` before changing the workflow or port configuration. If that leaves a cascade of unrelated missing-symbol errors, run `flutter clean && flutter pub get` once; a cold web build can then take over a minute, after which the existing server on port 5000 starts normally.

**Why:** A stale `_flutterfire_internals` package entry caused misleading missing-package errors and delayed the workflow; the app itself was healthy after dependencies were restored.

**How to apply:** Treat the first timeout as a dependency-cache/build-readiness issue, inspect the workflow log, restore packages, clean once only if the errors remain inconsistent with targeted analysis, and then retry the managed workflow.