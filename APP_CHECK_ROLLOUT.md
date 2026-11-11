# App Check staged rollout and rollback plan

App Check is defense-in-depth against automated abuse. It must not replace Firebase Authentication, ownership, membership, participant, phase, or server-side state validation.

## Current implementation state

- Flutter initializes App Check immediately after Firebase Core and before `runApp`.
- Android debug builds use the App Check debug provider; release builds use Play Integrity.
- Apple debug builds use the debug provider; release builds use App Attest with DeviceCheck fallback.
- Web debug builds use the debug provider. Web release builds require
  `--dart-define=FIREBASE_APP_CHECK_WEB_RECAPTCHA_SITE_KEY=<registered-site-key>`.
  If the key is absent, App Check activation is skipped with a diagnostic rather than
  making Firebase startup unavailable.
- Provider activation errors are logged without token contents and do not turn Firebase
  initialization into an app-wide outage.
- **No Firebase product or callable enforcement has been enabled by this code change.**
  This is intentional: enforcement before provider registration and metric observation can
  lock out legitimate existing clients.

## Preconditions before enforcement

1. Confirm Android/iOS/Web app registrations and supported attestation providers in
   Firebase Console → App Check.
2. Register the Android app `com.sbikazis.pubget` with Play Integrity and verify the
   correct Play signing certificate fingerprints in Play Console/Firebase.
3. Register the Apple app with App Attest/DeviceCheck if iOS distribution is supported.
4. Register the Web app with reCAPTCHA and supply the site key through the build define.
5. Build and distribute a release containing this client initialization.
6. Keep current Firestore/Storage authorization rules unchanged while measuring App Check.
7. Define success metrics: valid/invalid/unverified request rates, callable error rates,
   sign-in completion, messaging/upload failures, and scheduler health.

## Stages

### Stage 0 — Baseline

- Capture normal callable, Firestore, Storage, and Authentication traffic/error rates.
- Confirm Cloud Functions logs do not contain secrets or full tokens.

### Stage 1 — Client integration without enforcement

- **Code integrated; production registration and live token metrics remain to be verified.**
- Validate debug/development providers only in non-production builds.
- Monitor unverified traffic by platform and app version.

### Stage 2 — Limited enforcement

- Create/version one low-risk callable as a separate deployment target and enable
  `enforceAppCheck` on that function only.
- Route only a deliberately selected app version/feature entry point to the protected
  callable; the existing callable remains the rollback path during observation.
- Do not begin with registration, profile bootstrap, or critical Mafia lifecycle traffic.
- Record the exact protected function name, client version gate, rollback function name,
  and on-call owner before enabling enforcement.

### Stage 3 — Firestore/Storage/callable expansion

- Expand only after legitimate request success remains within the agreed threshold.
- Enforce callable App Check with `enforceAppCheck` while retaining all existing
  authorization.
- Validate old supported app versions or require an explicit minimum version.

### Stage 4 — Full enforcement and monitoring

- Alert on rejection spikes, platform-specific failures, and abnormal callable volume.
- Re-run emulator/security tests and production smoke tests with dedicated accounts.

## Rollback

If legitimate traffic breaks:

1. Disable App Check enforcement for the affected product/function; do not weaken
   authorization rules.
2. Preserve rejection metrics and absolute timestamps.
3. Identify platform, app version, provider, and token acquisition failure.
4. Correct client/provider configuration.
5. Resume from the last successful stage.

## Not completed

- Firebase Console provider registration and live metrics have not been verified from
  this repository connection.
- Firestore, Storage, Authentication, and callable enforcement are not enabled by this
  commit.
- Live release-device attestation and production smoke tests remain unverified.
