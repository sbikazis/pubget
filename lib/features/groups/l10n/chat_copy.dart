import '../../../core/l10n/app_strings.dart';
import '../models/chat_models.dart';

/// Localized status-pill label for a group game lobby card.
///
/// The label used to live on [ChatGameActivity] as a hardcoded English getter,
/// which meant an Arabic-first UI leaked "Join"/"View"/"Full"/"Closed". It now
/// derives from [AppStrings] so both locales render from one source of truth.
String chatGameStatusLabel(ChatGameActivity? activity, AppStrings copy) {
  if (activity?.isCancelled == true) return copy.chatGameStatusClosed;
  if (activity?.isStarted == true) return copy.chatGameStatusLive;
  if (activity?.isFull == true) return copy.chatGameStatusFull;
  return copy.chatGameStatusWaiting;
}

/// Localized call-to-action label for a group game lobby card.
String chatGameActionLabel(ChatGameActivity? activity, AppStrings copy) {
  if (activity?.isCancelled == true) return copy.chatGameCtaDetails;
  if (activity?.isStarted == true) return copy.chatGameCtaView;
  if (activity?.isFull == true) return copy.chatGameStatusFull;
  return copy.chatGameCtaJoin;
}
