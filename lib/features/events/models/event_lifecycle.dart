import 'event_models.dart';

/// Client-side mirror of the server event lifecycle. Server state is
/// authoritative; this only validates UI input and keeps tests aligned.
abstract final class EventLifecycle {
  static const maxDuration = Duration(days: 7);

  static const allowed = <EventStatus, Set<EventStatus>>{
    EventStatus.draft: {
      EventStatus.scheduled,
      EventStatus.active,
      EventStatus.cancelled,
    },
    EventStatus.scheduled: {EventStatus.active, EventStatus.cancelled},
    EventStatus.active: {EventStatus.ended, EventStatus.cancelled},
    EventStatus.ended: {EventStatus.archived},
    EventStatus.cancelled: {EventStatus.archived},
    EventStatus.archived: <EventStatus>{},
  };

  static bool canTransition(EventStatus from, EventStatus to) =>
      allowed[from]?.contains(to) ?? false;

  static String? validateWindow(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      return 'End time must be after start time.';
    }
    if (end.difference(start) > maxDuration) {
      return 'Events cannot last longer than 7 days.';
    }
    return null;
  }
}

abstract final class EventValidation {
  static String? draft(EventDraft draft) {
    if (draft.title.trim().isEmpty) return 'A title is required.';
    if (draft.groupId == null || draft.groupId!.trim().isEmpty) {
      return 'Events must belong to a group.';
    }
    final start = draft.startAt;
    final end = draft.endAt;
    if (start != null && end != null) {
      final window = EventLifecycle.validateWindow(start, end);
      if (window != null) return window;
    }
    return null;
  }
}
