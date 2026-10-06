import 'package:firebase_core/firebase_core.dart';

import '../../../core/errors/failure.dart';
import '../../../core/errors/result.dart';
import '../../../core/l10n/app_strings.dart';

/// Honest mapping for Home/discovery failures.
///
/// `permission-denied` is a rules/IAM/App Check denial — not an entitlement
/// check. The live banner "Discovery is not available for this account" was
/// a false mapping that hid real content.
///
/// Every message below is rendered through `discoveryFailureMessage`, so the
/// failure itself stays locale-neutral and the Arabic UI never shows an
/// English sentence (spec §1.4).
Failure discoveryFailureFrom(Object error) {
  if (error is FirebaseException) {
    return discoveryFailureFromCode(error.code);
  }
  return const UnknownError();
}

/// Resolve a discovery failure into user-facing copy for the active locale.
String discoveryFailureMessage(AppStrings copy, Failure failure) {
  if (failure is NetworkError) return copy.discoveryOffline;
  if (failure is PermissionError) return copy.discoverySignInRequired;
  return copy.discoveryUnavailable;
}

Failure discoveryFailureFromCode(String code) {
  return switch (code) {
    'unavailable' || 'deadline-exceeded' => const NetworkError(),
    'unauthenticated' => const PermissionError(),
    'permission-denied' => const UnknownError(),
    'failed-precondition' => const UnknownError(),
    _ => const UnknownError(),
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
