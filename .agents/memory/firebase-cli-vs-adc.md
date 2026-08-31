---
name: Firebase CLI versus ADC
description: Authentication boundary for production Firebase maintenance scripts in this Replit environment.
---

Firebase CLI login authenticates Firebase CLI deployments and API calls, but standalone Firebase Admin SDK scripts using `applicationDefault()` still lack Application Default Credentials.

**Why:** A production backfill could deploy successfully through Firebase CLI while the Admin SDK rejected both dry-run and apply operations for missing ADC.

**How to apply:** Prefer a service account/ADC for reusable Admin SDK maintenance scripts. For one-off audited operations, use the authenticated Firebase API without exporting or persisting OAuth credentials, and never print tokens.