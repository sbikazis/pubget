import 'package:firebase_core/firebase_core.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';

/// Honest mapping for Home/discovery failures.
///
/// `permission-denied` is a rules/IAM/App Check denial — not an entitlement
/// check. The live banner "Discovery is not available for this account" was
/// a false mapping that hid real content.
Failure discoveryFailureFrom(Object error) {
  if (error is FirebaseException) {
    return discoveryFailureFromCode(error.code);
  }
  return const UnknownError('Discovery could not load.');
}

Failure discoveryFailureFromCode(String code) {
  return switch (code) {
    'unavailable' || 'deadline-exceeded' => const NetworkError(
      'Check your connection and try again.',
    ),
    'unauthenticated' => const PermissionError('Sign in to load discovery.'),
    'permission-denied' => const UnknownError('Discovery could not load.'),
    'failed-precondition' => const UnknownError('Discovery could not load.'),
    _ => const UnknownError('Discovery could not load.'),
  };
}

/// Prefer ranked callable results when they actually contain items. If ranking
/// fails or returns empty, use the Firestore fallback so Home can still show
/// real people/groups instead of a false error banner.
Future<Result<List<T>>> rankedOrFallback<T>({
  required Future<Result<List<T>>> ranked,
  required Future<Result<List<T>>> Function() fallback,
}) async {
  final primary = await ranked;
  final items = primary.valueOrNull;
  if (primary.isSuccess && items != null && items.isNotEmpty) {
    return primary;
  }
  final second = await fallback();
  if (second.isSuccess) return second;
  if (primary.isSuccess) return primary;
  return second;
}
