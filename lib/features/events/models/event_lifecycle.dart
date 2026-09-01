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
    return configuration(draft.type, draft.configuration);
  }

  static String? configuration(EventType type, EventConfiguration config) {
    if (type == EventType.quiz) {
      if (config.questions.isEmpty || config.questions.length > 20) {
        return 'A quiz needs between 1 and 20 questions.';
      }
      for (var i = 0; i < config.questions.length; i++) {
        final question = config.questions[i];
        if (question.prompt.trim().isEmpty) {
          return 'Question ${i + 1} needs text.';
        }
        if (question.options.length < 2 || question.options.length > 6) {
          return 'Question ${i + 1} needs 2 to 6 answers.';
        }
        if (question.options.any((option) => option.label.trim().isEmpty)) {
          return 'Question ${i + 1} has an empty answer.';
        }
        if (!question.options.any(
          (option) => option.id == question.correctOptionId,
        )) {
          return 'Question ${i + 1} needs a correct answer.';
        }
      }
      return null;
    }
    if (type == EventType.theory ||
        type == EventType.openDiscussion ||
        type == EventType.challenge) {
      final prompt = config.prompt.trim().isNotEmpty
          ? config.prompt
          : config.question;
      if (prompt.trim().isEmpty) return 'A prompt is required.';
      return null;
    }
    final question = config.question.trim().isNotEmpty
        ? config.question
        : config.prompt;
    if (question.trim().isEmpty) return 'A question is required.';
    if (config.options.length < 2 || config.options.length > 10) {
      return 'Provide between 2 and 10 options.';
    }
    if (config.options.any((option) => option.label.trim().isEmpty)) {
      return 'Every option needs a label.';
    }
    return null;
  }
}
