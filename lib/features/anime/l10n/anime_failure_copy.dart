import '../../../core/errors/failure.dart';
import 'anime_copy.dart';

/// Localized, user-facing sentence for an Anime Hub failure.
///
/// [Failure.message] is a locale-neutral developer sentence (usually English)
/// and must never be painted directly: doing so leaks English into the Arabic
/// UI. This resolves the failure *kind* into copy for the active locale, and
/// keeps three different situations apart instead of collapsing them into one
/// "check your connection" line:
///
/// * a real connectivity problem ([NetworkError]/[TimeoutError]),
/// * a backend throttle ([RateLimitedError]),
/// * an outage or an unmapped error (everything else).
String animeFailureMessage(AnimeCopy copy, Failure? failure) {
  if (failure is NetworkError || failure is TimeoutError) {
    return copy.checkConnection;
  }
  if (failure is RateLimitedError) return copy.tooManyRequests;
  if (failure is PermissionError) return copy.signInToSaveList;
  return copy.serviceUnavailable;
}
