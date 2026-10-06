import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/loading/loading_state.dart';
import 'package:pubget/features/authentication/auth_route_guard.dart';

void main() {
  test('unauthenticated protected routes go to login', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/home',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.initial,
        canEnterHome: false,
      ),
      '/login',
    );
  });

  test('signed-in users leave guest-only auth screens', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/login',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: true,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/home',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/register',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: true,
        onboardingState: LoadingState.loaded,
        canEnterHome: false,
      ),
      '/onboarding',
    );
  });

  test('incomplete profiles cannot enter home', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/home',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: true,
        onboardingState: LoadingState.loaded,
        canEnterHome: false,
      ),
      '/onboarding',
    );
  });

  test('unauthenticated login is a normal guest route, not an error', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/login',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.initial,
        canEnterHome: false,
      ),
      isNull,
    );
  });

  test('unauthenticated event deep links still return to login', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/event',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
  });

  test('mafia and achievement routes are protected', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/mafia',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/achievements',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
  });

  test('store, search, and settings routes are protected', () {
    expect(
      AuthRouteGuard.resolve(
        path: '/store',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/search',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/joined',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/settings',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/premium',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: true,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      isNull,
    );
    expect(
      AuthRouteGuard.resolve(
        path: '/guide',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: false,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      '/login',
    );
  });

  test('every ReelsFeedPage route is protected', () {
    // Each of these renders `ReelsFeedPage`, which loads the signed-in Edit
    // feed. If one is missing from `protectedPaths`, a signed-out visitor lands
    // on a page that can only fail on Firestore/Storage permissions.
    const reelsRoutes = <String>[
      '/reel',
      '/hashtag',
      '/reels/anime',
      '/reels/character',
      '/reels/creator',
    ];

    for (final path in reelsRoutes) {
      expect(
        AuthRouteGuard.resolve(
          path: path,
          isInitialized: true,
          authState: LoadingState.loaded,
          isAuthenticated: false,
          onboardingState: LoadingState.loaded,
          canEnterHome: true,
        ),
        '/login',
        reason: '$path must redirect a signed-out visitor to login',
      );

      // And an authenticated, onboarded user must still get through.
      expect(
        AuthRouteGuard.resolve(
          path: path,
          isInitialized: true,
          authState: LoadingState.loaded,
          isAuthenticated: true,
          onboardingState: LoadingState.loaded,
          canEnterHome: true,
        ),
        isNull,
        reason: '$path must stay reachable when signed in',
      );
    }
  });

  test('a ReelsFeedPage route waits for auth instead of bouncing to login', () {
    // While auth is still resolving the guard must send the user to splash, not
    // to login -- otherwise a cold start on a shared /reel link logs them out.
    for (final path in <String>['/reel', '/reels/creator']) {
      expect(
        AuthRouteGuard.resolve(
          path: path,
          isInitialized: true,
          authState: LoadingState.loading,
          isAuthenticated: false,
          onboardingState: LoadingState.loaded,
          canEnterHome: true,
        ),
        '/splash',
      );
    }
  });
}
