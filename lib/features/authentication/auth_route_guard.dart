import '../../core/loading/loading_state.dart';

abstract final class AuthRouteGuard {
  static const authFlowPaths = <String>{
    '/login',
    '/register',
    '/splash',
    '/onboarding',
    '/terms',
    '/forgot-password',
    '/verify-email',
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
    '/guide',
    '/onboarding',
    '/profile',
    '/profile/edit',
    '/friend-requests',
    '/notifications',
    '/edits',
    '/edits/upload',
    // Signed-in feeds and their scoped entry points use authenticated data.
    '/reel',
    '/audio',
    '/hashtag',
    '/reels/anime',
    '/reels/character',
    '/reels/creator',
    '/groups',
    '/joined',
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
    '/anime/library',
    '/anime/ratings',
    '/anime/characters',
    '/anime/me',
    '/games',
    '/games/create',
    '/game',
    '/mafia',
    '/achievements',
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
    required bool isEmailVerified,
    required bool isVersionGatePassed,
    required LoadingState onboardingState,
    required bool canEnterHome,
  }) {
    final authBusy =
        !isInitialized ||
        authState == LoadingState.initial ||
        authState == LoadingState.loading;

    if (!isVersionGatePassed && path != '/splash') {
      return '/splash';
    }

    if (path == '/verify-email') {
      if (authBusy || (isAuthenticated && !isVersionGatePassed)) {
        return '/splash';
      }
      return isAuthenticated ? null : '/login';
    }
    if (isAuthenticated && !isEmailVerified && path != '/splash') {
      return '/splash';
    }

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
