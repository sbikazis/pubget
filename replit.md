# Pubget on Replit

## Project targets

- Flutter/Dart: the client application in `lib/`
- Firebase Cloud Functions: Node.js 20 code in `functions/`
- Firebase project: `pubget-aaf27` (do not substitute another project)
- Replit Preview: Flutter Web on port 5000

## Preview

The `Start application` workflow runs:

```sh
bash scripts/run_replit_web.sh
```

The script fetches the public Firebase Web client configuration from the
existing `pubget-aaf27` Firebase Hosting site, verifies the project ID, project
number, and Web app ID, and passes it to Flutter through a temporary
`--dart-define-from-file` file. The temporary file is deleted automatically.

This is Firebase client metadata, not a privileged credential. The workflow
fails instead of building if the public configuration is unavailable,
incomplete, or belongs to a different Firebase project.

Firebase Web client configuration is embedded in the compiled web application
by Firebase design. Privileged credentials are never fetched by this workflow.
Do not commit service-account JSON, OAuth client secrets, Firebase CLI tokens,
signing keys, or other privileged credentials.

## Validation

Run checks separately from the long-running Preview workflow:

```sh
flutter analyze
flutter test
npm ci
npm run test:rules
cd functions
npm ci
npm run check
npm test
```

The root rules tests use Firebase Emulator Suite with the demo project
`demo-pubget-security`; they do not write to the production Firebase project.

## Credentials and deployment

Local analysis, unit tests, and demo-project emulator tests do not require
production Firebase credentials.

Production administration or deployment requires one of:

- Application Default Credentials from a least-privilege service account, or
- an explicitly authenticated Firebase CLI session.

Keep service-account JSON in Replit Secrets (for example,
`FIREBASE_SERVICE_ACCOUNT_JSON`) and materialize it only temporarily when a
specific command needs `GOOGLE_APPLICATION_CREDENTIALS`. Firebase CLI
authentication alone does not provide ADC to standalone Admin SDK scripts.

Never run a Firebase deployment as part of Preview startup or automated tests.
Deployment remains a separate, explicit operation.

## One-time console checks

The repository cannot prove account-side configuration. Verify these once:

- Add the Replit development domain to Firebase Authentication authorized
  domains and to the Google OAuth Web client.
- Confirm Email/Password and Google providers are enabled in Firebase Auth.
- Configure Web Push credentials before expecting FCM to work in Preview.
- Register and enforce App Check providers only after development/debug tokens
  and production providers are planned.
- Confirm the AdMob app, ad units, mediation partners, consent flow, and store
  linkage in AdMob. Native AdMob identifiers alone do not activate ads.