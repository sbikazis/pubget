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
- `TimeoutError`
- `RateLimitedError`
- `UnavailableError`
- `MalformedDataError`

The extra failure types were added for external catalog APIs (Anime Hub).
Providers still map `FailureResult` into user-facing `LoadingState` without
exposing raw exception text.

## Caching

`core/caching/ttl_cache.dart` provides an in-memory TTL cache. Anime Hub is
the first consumer. Fresh entries skip the remote source; expired entries may
still be served when offline.

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

## Design system

The shared visual language lives under `core/theme/` and `core/widgets/`.
It uses a Royal Purple primary palette and a Gold accent palette with equal
support for light and dark themes.

### Required rules

- Do not introduce hard-coded colors outside `AppColors`. Components should
  normally read semantic colors from `Theme.of(context).colorScheme`.
- Use `AppSpacing`, `AppRadius`, `AppTypography`, and `AppShadows` instead of
  inventing values in feature widgets.
- Let the surrounding `Directionality` decide layout. Use directional
  alignment and start/end semantics instead of left/right assumptions.
- All visible copy must be supplied by the caller when it belongs to a feature.
  Shared fallback messages are intentionally generic and may be overridden.
- Shared widgets stay presentational. State transitions and business decisions
  remain in Providers/Controllers, following the required dependency direction.
- Motion must communicate progress or feedback. The skeleton animation is
  implemented with Flutter's animation primitives, so no animation or shimmer
  package is required.

Import the component barrel when a screen needs several controls:

```dart
import 'package:pubget/core/widgets/pubget_design_system.dart';
```

Individual files remain available for narrow imports. Primary, secondary,
text, and icon buttons expose disabled and loading behavior. Inputs cover
single-line, multiline, search, focus, disabled, and error states. Cards,
avatars, and badges are visual primitives and do not contain premium, rank, or
identity rules.

Sheets and dialogs return values to their caller without changing application
state. `PubgetSnackbars` exposes success, error, and information feedback.
`PubgetTooltip` uses the current theme and platform tooltip behavior.

### LoadingState composition

`PubgetLoadingStateView` maps the foundation `LoadingState` to consistent
loading, empty, error, offline, refreshing, pagination, and loaded UI:

```dart
PubgetLoadingStateView(
  state: provider.state,
  onRetry: provider.load,
  skeleton: const PubgetSkeleton.card(width: double.infinity),
  empty: const PubgetEmptyState(title: 'No items yet'),
  child: ItemsList(items: provider.items),
)
```

Feature screens should override user-facing messages with localized copy and
never expose raw Firebase or technical exception text.

### Internal showcase

`DesignSystemShowcasePage` is reachable from the foundation page during
development. It renders the complete component catalog and provides live
Light/Dark and RTL/LTR controls. It is not a production user flow and contains
no domain behavior.