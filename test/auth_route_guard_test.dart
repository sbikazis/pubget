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
}
