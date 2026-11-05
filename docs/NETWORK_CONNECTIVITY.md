# Network connectivity and failure handling

## Responsibility

The shared `NetworkService` is a lightweight reachability hint. It does not
replace Firebase's own connection handling or a feature repository's handling
of request failures.

The dependency direction remains:

```text
Widget → Provider/Controller → Repository/Service → Firebase or HTTP API
                   ↑
             NetworkService
```

## Platform probes

- Android, iOS, desktop: try two independent HTTPS 204 connectivity-check
  endpoints. A single DNS lookup for `example.com` is not sufficient evidence
  of internet access; DNS failure for one unrelated hostname must not mark the
  entire device offline.
- Web: use `navigator.onLine` as a link-state hint. Browsers do not provide a
  portable, unrestricted cross-origin internet probe. A feature's actual
  Firebase/API request remains authoritative.
- Unsupported platforms: remain optimistic rather than disabling all
  network-backed actions because no probe implementation exists.

The native probe accepts only HTTP 204. Redirects and captive-portal HTML
responses are not treated as a successful internet check. Each endpoint has a
bounded timeout, and failure of one endpoint falls through to the other.

## State and lifecycle

- Before the first probe completes, `isChecking` is true and `isOffline` is
  false. An unresolved state must not be presented as a confirmed outage.
- `isOnline` means a probe has positively succeeded.
- `canAttemptNetworkRequest` is true while the first probe is pending or when
  the last probe succeeded. This avoids blocking a real request during startup;
  repositories must still handle the request's actual result.
- `refresh()` coalesces concurrent calls into one probe. A timeout bounds
  injected/platform probes, and periodic polling cannot pile up overlapping
  checks.
- `dispose()` cancels polling and prevents late probe completions from
  publishing state.

## Error classification

A network probe only describes general reachability. It cannot prove that
Firebase, Cloud Functions, Firestore, Storage, or a third-party API is healthy.
Repositories must map destination-specific failures into the shared failure
taxonomy, and screens must distinguish offline, timeout, permission, validation,
rate-limit, and server-unavailable cases. Do not show “check your connection”
for a permission error or a backend outage.

## Verification

Run:

```sh
flutter analyze --no-pub --no-fatal-infos
flutter test test/network_service_test.dart
flutter test --exclude-tags golden
```

Real-device checks are still required for Wi-Fi/mobile-data switching,
captive portals, airplane mode, DNS restrictions, and browser offline mode.
