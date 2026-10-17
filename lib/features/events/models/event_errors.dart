import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';

/// Resolve an Events [Failure] into user-facing copy for the active locale.
///
/// The builder, the details screen and the crosspost sheet all render failures
/// through this, so a failure stays locale-neutral and the Arabic UI never
/// shows the raw English `Failure.message` (spec §1.4, §14). Validation errors
/// keep their specific message by translating the server's `ev.*` key.
String eventFailureMessage(AppStrings copy, Failure? failure) {
  if (failure == null) return '';
  if (failure is ValidationError) {
    return copy.eventValidationMessage(failure.message);
  }
  if (failure is NetworkError) return copy.eventOffline;
  if (failure is PermissionError) return copy.eventPermissionDenied;
  if (failure is RateLimitedError) return copy.eventRateLimited;
  return copy.eventLoadFailed;
}
