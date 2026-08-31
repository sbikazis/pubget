# App Check staged rollout and rollback plan

App Check is defense-in-depth against automated abuse. It must not replace Firebase Authentication, ownership, membership, participant, phase, or server-side state validation.

## Preconditions

1. Resolve the open High findings independently of App Check.
2. Confirm Android/iOS/Web app registrations and supported attestation providers.
3. Build a Flutter release with App Check initialization for every supported platform.
4. Keep current authorization rules unchanged while measuring App Check.
5. Define success metrics: valid/invalid/unverified request rates, callable error rates, sign-in completion, messaging/upload failures, and scheduler health.

## Stages

### Stage 0 — Baseline

- Capture normal callable, Firestore, Storage, and Authentication traffic/error rates.
- Confirm Cloud Functions logs do not contain secrets or full tokens.

### Stage 1 — Client integration without enforcement

- Ship App Check token acquisition.
- Validate debug/development providers only in non-production builds.
- Monitor unverified traffic by platform and app version.

### Stage 2 — Limited enforcement

- Create/version one low-risk callable as a separate deployment target and enable `enforceAppCheck` on that function only.
- Route only a deliberately selected app version/feature entry point to the protected callable; the existing callable remains the rollback path during observation.
- Do not begin with registration, profile bootstrap, or critical Mafia lifecycle traffic.
- Record the exact protected function name, client version gate, rollback function name, and on-call owner before enabling enforcement.

### Stage 3 — Firestore/Storage/callable expansion

- Expand only after legitimate request success remains within the agreed threshold.
- Enforce callable App Check with `enforceAppCheck` while retaining all existing authorization.
- Validate old supported app versions or require an explicit minimum version.

### Stage 4 — Full enforcement and monitoring

- Alert on rejection spikes, platform-specific failures, and abnormal callable volume.
- Re-run emulator/security tests and production smoke tests with dedicated accounts.

## Rollback

If legitimate traffic breaks:

1. Disable App Check enforcement for the affected product/function; do not weaken authorization rules.
2. Preserve rejection metrics and absolute timestamps.
3. Identify platform, app version, provider, and token acquisition failure.
4. Correct client/provider configuration.
5. Resume from the last successful stage.

## Not completed

App Check was not enabled or enforced during this audit. Live behavior therefore remains unverified.
