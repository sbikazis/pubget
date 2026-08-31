# Pubget foundation architecture

This directory contains cross-cutting contracts only. It must not contain
feature-specific business rules.

## Required dependency direction

```text
UI → Provider/Controller → Repository/Service → Firebase
```

- **UI** renders state and forwards user intent.
- **Provider/Controller** owns presentation state and coordinates a use case.
- **Repository/Service** owns data access and maps platform failures to the
  shared `Result<T>` contract.
- **Firebase** is the remote infrastructure boundary.

Widgets must not contain business logic or write sensitive fields directly.
Coins, rewards, subscriptions, roles, and game outcomes remain
server-authoritative through Firebase Functions and Security Rules.

## Result and failure handling

Repositories return `Result<T>` from `core/errors/result.dart` rather than
letting Firebase exceptions reach the UI. Failures are categorized as:

- `NetworkError`
- `PermissionError`
- `NotFoundError`
- `ValidationError`
- `UnknownError`

Providers translate a `FailureResult` into user-facing state without
reimplementing Firebase error parsing.

## Loading states

Future Providers use `LoadingState` from
`core/loading/loading_state.dart`:

`initial`, `loading`, `refreshing`, `loadingMore`, `loaded`, `empty`, `error`,
and `offline`.

This makes loading, empty, refresh, pagination, error, and offline behavior
explicit instead of representing every state with a nullable list.

## Routing

`app/app_router.dart` owns the typed route configuration. `AppRoute` has a
foundation route and a parameterized route that preserves a path and typed
string map for future deep-link adapters. No deep-link business behavior is
implemented in this foundation stage.

## Dependency injection decision

The project already depends on `provider`, and the current app uses a Provider
tree. The foundation keeps that choice and uses `MultiProvider` to construct
services before Providers consume them. `get_it` is intentionally not added:
the current foundation has no need for a second service-locator mechanism.

`core/examples/dummy_repository.dart` and
`core/examples/dummy_provider.dart` are the reference implementation:

```text
FoundationHomePage (UI)
  → DummyProvider
    → DummyRepository
      → Result<String>
```

The example is domain-free and exists only to demonstrate the boundary.
The foundation page invokes it through the Provider tree, and a widget test
verifies the complete UI → Provider → Repository → Result path.

## SDK and dependency baseline

The legacy manifest required Dart 3.11 and retained packages for every legacy
feature. The Replit Flutter toolchain currently supplies Dart 3.8, while this
foundation uses no language feature newer than 3.8. The SDK range is therefore
`>=3.8.0 <4.0.0` so the new baseline can be analyzed and built in this
environment.

Dependencies were reduced to the packages imported by the new foundation:
Flutter, Firebase Core, Provider, and the small Web interop package used by the
browser connectivity probe. Feature packages remain discoverable through the
unchanged legacy manifest history and can be reintroduced only when a migrated
domain needs them.

Firebase initializes from the checked-in native Android/iOS configuration.
Because no generated or environment-provided Firebase Web options exist,
the Web foundation reports Firebase as unavailable instead of inventing or
copying a hard-coded project configuration.

## Connectivity

`core/network/network_service.dart` is a `ChangeNotifier` that exposes only
`Online`/`Offline` state, can be subscribed to from any future Provider, and
cleans up its polling timer. Its platform probes use native IO on desktop and
mobile and the browser online flag on web.