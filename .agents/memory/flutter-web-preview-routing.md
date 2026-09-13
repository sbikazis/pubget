---
name: Flutter web preview routing
description: Replit preview behavior for Flutter web apps served by a static HTTP server.
---

Use a history-API fallback to `build/web/index.html` when the preview server receives a non-file route. Direct URLs such as `/games?...` otherwise return a 404 even though the Flutter app itself is healthy.

**Why:** The Replit preview opens routed URLs directly, while Python's default static server only looks for a matching file or directory.

**How to apply:** Keep the workflow serving the built `build/web` directory through a small server that preserves real asset responses and falls back only for missing paths.