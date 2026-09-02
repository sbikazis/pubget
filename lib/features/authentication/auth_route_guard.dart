import '../../core/loading/loading_state.dart';

abstract final class AuthRouteGuard {
  static const authFlowPaths = <String>{
    '/login',
    '/register',
    '/splash',
    '/onboarding',
    '/terms',
    '/forgot-password',
  };

  static const guestOnlyPaths = <String>{
    '/login',
    '/register',
    '/forgot-password',
  };

  static const protectedPaths = <String>{
    '/home',
    '/search',
    '/settings',
    '/onboarding',
    '/profile',
    '/profile/edit',
    '/friend-requests',
    '/notifications',
    '/edits',
    '/edits/upload',
    '/groups',
    '/groups/create',
    '/group',
    '/group-invite',
    '/group-chat',
    '/group-media',
    '/group-members',
    '/group-requests',
    '/group-roleplay',
    '/private',
    '/private-chat',
    '/events',
    '/events/create',
    '/event',
    '/anime',
    '/anime/details',
    '/anime/browse',
    '/anime/genre',
    '/anime/season',
    '/games',
    '/games/create',
    '/game',
    '/fan-works',
    '/fan-works/create',
    '/fan-work',
    '/store',
    '/store/item',
    '/inventory',
    '/premium',
    '/economy/history',
  };

  static String? resolve({
    required String path,
    required bool isInitialized,
    required LoadingState authState,
    required bool isAuthenticated,
    required LoadingState onboardingState,
    required bool canEnterHome,
  }) {
    final authBusy =
        !isInitialized ||
        authState == LoadingState.initial ||
        authState == LoadingState.loading;

    if (guestOnlyPaths.contains(path) && isAuthenticated) {
      if (authBusy || onboardingState == LoadingState.initial) {
        return '/splash';
      }
      return canEnterHome ? '/home' : '/onboarding';
    }

    if (!protectedPaths.contains(path)) return null;
    if (authBusy) return '/splash';
    if (!isAuthenticated) return '/login';
    if (path != '/onboarding' && onboardingState == LoadingState.initial) {
      return '/splash';
    }
    if (path != '/onboarding' && !canEnterHome) return '/onboarding';
    return null;
  }
}
