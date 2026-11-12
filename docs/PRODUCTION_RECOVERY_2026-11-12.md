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
