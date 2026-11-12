# Pubget — Production Recovery Baseline
Date: 2026-11-12
Repository: sbikazis/pubget
Baseline branch: main
Baseline commit: ee99d703c67db3c1a8a17a5cea41a7226d820d83
Recovery branch: recovery/production-readiness-2026-11-12

## Purpose
Record verified repository and CI facts before making application changes. This document is not a production-readiness certification.

## Verified baseline

- PR #182 ("Pubget 1.0: final integrated rebuild and validation") was merged on 2026-11-11 at 17:17:18 UTC.
- The merge commit is the current main HEAD: ee99d703c67db3c1a8a17a5cea41a7226d820d83.
- The PR's validation runs passed: Flutter analyze/tests, Functions checks/unit tests, Firestore and Storage rules tests, Flutter build validation, and client verification.
- On the merge commit, GitHub Actions reports:
  - Pubget APK: success (run 43066687628)
  - CI: success (run 43066687546)
  - Firebase Functions deployment: success (run 43066687625)
  - Firestore rules deployment: success (run 43066687454)
  - Storage rules deployment: success (run 43066687621)
  - Verify Client: success (run 43066687406)
  - Firebase Hosting deployment: failure (run 43066687410)

## Confirmed failure: Firebase Hosting deployment

Workflow: .github/workflows/deploy-hosting.yml
Run: https://github.com/sbikazis/pubget/actions/runs/43066687410

The Flutter Web build completed successfully. The Firebase Hosting deploy then remained at "adding files to version [0/91]" for several minutes and failed after four retries with:
"Unable to parse JSON: SyntaxError: Unexpected token '<', '<!DOCTYPE ...' is not valid JSON"

This proves the deployment client received an HTML response where it expected JSON. The available log does not identify the upstream HTTP status or the exact HTML response body, so the precise server-side cause is not yet established. Do not assume this is a Flutter compilation or application-code failure.

The deployment workflow currently writes FIREBASE_SERVICE_ACCOUNT to /tmp/sa.json and runs:
firebase deploy --only hosting --project pubget-aaf27 --force

No production redeployment or retry was performed during this audit.

## Remaining release blockers / evidence gaps

1. Firebase Hosting deployment must be diagnosed and successfully validated.
2. Run real-device Android smoke tests for login/session restore, navigation, core social flows, chat, media upload/playback, push notifications, and offline/reconnect behavior.
3. Validate production Firebase/Cloudflare integration end-to-end, including actual R2 upload, processing, authorization, playback/seek, retry, and deletion.
4. Confirm Firebase App Check production registration, provider attestation metrics, and enforcement plan. Do not enable enforcement until legitimate clients are verified.
5. Review any remaining open PRs selectively; do not merge broad mixed-scope PRs without reviewing their current diffs and CI.
6. Capture current screenshots and reproducible steps for user-reported UI defects; repository CI cannot establish visual quality or device behavior.

## Safety and release policy

- Keep changes on this recovery branch and use focused PRs; do not commit directly to main.
- Do not expose credentials in chat or source files. Use repository/environment secrets or the provider's secret manager.
- Do not weaken Firestore/Storage rules, App Check, authentication, or authorization to make tests pass.
- Do not deploy production resources or enable enforcement as part of diagnosis without explicit release approval.
- A successful CI run or APK build alone is not proof of production readiness.

## Day-one execution status

- [x] Confirm repository permissions and default branch.
- [x] Confirm current main HEAD and PR #182 merge status.
- [x] Inspect latest merge-commit CI and deployment outcomes.
- [x] Retrieve Hosting deployment job logs and isolate the failure stage.
- [x] Create an isolated recovery branch.
- [ ] Add targeted Hosting diagnostics/fix after inspecting full deploy workflow and Firebase CLI behavior.
- [ ] Establish a reproducible device-smoke-test checklist with the user.


## Additional investigation — 2026-11-12

### Hosting failure: evidence and limits

- Re-read the full failed Hosting job log (run 43066687410 / job 130683403382).
- Flutter Web compilation completed. The failure occurred during Firebase Hosting's file population/upload phase, after repeated progress at 0/91.
- The CLI ultimately reported an HTML document where it expected JSON. The job log does not contain the Firebase API request URL, HTTP status, or response body, so it is not sufficient to distinguish an upstream timeout, gateway response, auth redirect, or service-side error.
- The workflow does not currently print Node.js or Firebase CLI versions, and it does not preserve a sanitized Firebase debug log. This is an observability gap, not proof that a specific CLI version caused the failure.
- Do not pin Node/Firebase CLI or change Hosting configuration based only on this symptom. Next safe step is to add version reporting and a carefully redacted diagnostic artifact, then reproduce through an approved non-production validation path before altering live deployment behavior.

### Open PR triage (current API state checked 2026-11-12)

- PR #183: this recovery baseline document; open draft, documentation-only.
- PR #181: still open; its base is feature/17-community-interactions, not main. It is not a direct candidate for merging into main without reviewing the full branch chain and diff.
- PR #179: still open; compares as 238 commits ahead / 4 behind main, reports mergeable_state=dirty, and touches many production surfaces. Do not merge as-is; first determine which changes are already present in main, then split genuinely missing changes into focused PRs.
- PR #169: still open; compares as 4 commits ahead / 12 behind main, reports mergeable_state=dirty, and has mixed scope across routing, media, edits, chat/groups, notifications, and profile surfaces. Do not merge as-is; selectively extract only independently justified changes with tests.
- PR #173: open at the time of the PR search. A comparison request did not return a usable response during this pass, so no claim is made about its unique changes or mergeability.

### Updated day-one status

- [x] Re-read full Hosting deployment logs and isolate the exact failing phase.
- [x] Review the current base/head relationships and mergeability of the major open PRs listed above.
- [x] Confirm no existing open PR is a safe one-click merge candidate based on the evidence gathered.
- [ ] Add safe Hosting deployment diagnostics (version reporting and redacted logs) in a separate reviewable change.
- [ ] Inspect user-reported visual defects using screenshots and reproduce on a real Android device.

### Application entry-point inspection

- `PubgetApp` wires `SplashPage` as the router fallback and `/splash` destination, then registers `/home` and other feature routes. The production router does not instantiate `FoundationHomePage`.
- `FoundationHomePage` contains explicit placeholder copy stating that feature domains will be added later, but repository search found it referenced only by its own declaration and its dedicated test. Do not treat that placeholder screen as proof that the production app launches into it.
- The initial route is derived from `Uri.base` and then passed through `AuthRouteGuard`; this makes deep-link and authentication-state tests important. It does not by itself explain the user's reported visual defects.
- The provider graph creates many repositories and providers at the app root. No provider-wide rewrite is justified from static inspection alone; capture the exact failing route and runtime exception before changing this graph.

- [x] Trace the production router entry point and verify whether the legacy foundation placeholder is used.
