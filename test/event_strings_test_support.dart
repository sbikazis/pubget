// Test-only compatibility helper. `EventStrings` used to be an
// `abstract final class` of static const English labels in
// lib/features/events/models/event_type_registry.dart and was removed from
// production. These are the original values (from revision 6705a39), kept here
// so the widget/unit tests can still reference the copy they assert against
// without reintroducing the class into production `lib/`.
abstract final class EventStrings {
  static const noEventsTitle = 'No active events yet';
  static const noEventsMessage = 'Discover groups or create an event.';
  static const noParticipation = 'Join this event to take part.';
  static const ended = 'This event has ended.';
  static const deleted = 'This event is no longer available.';
  static const archived = 'This event is archived.';
  static const permission = "You don't have permission to manage events.";
  static const missing = 'This event no longer exists.';
  static const submitFailed = 'Submission failed. Try again.';
  static const offline = 'You are offline. The action was not saved.';
  static const create = 'Create event';
  static const publish = 'Publish';
  static const schedule = 'Schedule';
  static const join = 'Join event';
  static const leave = 'Leave event';
  static const submit = 'Submit';
  static const retry = 'Try again';
  static const share = 'Share event';
  static const copyLink = 'Copy link';
  static const copied = 'Event link copied';
  static const saveDraft = 'Save draft';
  static const addQuestion = 'Add question';
  static const removeQuestion = 'Remove question';
  static const addAnswer = 'Add answer';
  static const correctAnswer = 'Correct answer';
  static const seeAll = 'See all events';
  static const groupEvents = 'Group events';
  static const endEvent = 'End event';
  static const cancelEvent = 'Cancel';
  static const archiveEvent = 'Archive';
  static const alreadyParticipated = 'You already participated';
  static const resultTitle = 'Final result';
}
