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

  test('store and premium routes are protected', () {
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
        path: '/premium',
        isInitialized: true,
        authState: LoadingState.loaded,
        isAuthenticated: true,
        onboardingState: LoadingState.loaded,
        canEnterHome: true,
      ),
      isNull,
    );
  });
}
