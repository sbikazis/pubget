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
      if (type == EventType.challenge) {
        const kinds = <String>{
          'finish_game',
          'publish_edit',
          'create_group',
          'participate_event',
          'self_report',
        };
        final kind = config.challengeKind.trim().isEmpty
            ? 'self_report'
            : config.challengeKind.trim();
        if (!kinds.contains(kind)) return 'Choose a valid challenge type.';
        if (kind == 'participate_event' && config.targetEventId.trim().isEmpty) {
          return 'A target event is required.';
        }
      }
      return null;
    }
    if (type == EventType.characterComparison ||
        type == EventType.animeComparison ||
        type == EventType.imageComparison) {
      final criterion = config.criterion.trim().isNotEmpty
          ? config.criterion
          : config.question;
      if (criterion.trim().isEmpty) return 'A comparison criterion is required.';
      if (config.options.length < 2 || config.options.length > 10) {
        return 'Provide between 2 and 10 candidates.';
      }
      final ids = <String>{};
      for (final option in config.options) {
        if (type == EventType.characterComparison &&
            option.characterId.trim().isEmpty &&
            option.label.trim().isEmpty) {
          return 'Every character candidate needs a catalog ID.';
        }
        if (type == EventType.animeComparison &&
            option.animeId.trim().isEmpty &&
            option.label.trim().isEmpty) {
          return 'Every anime candidate needs a catalog ID.';
        }
        if (type == EventType.imageComparison) {
          if (!option.imageUrl.startsWith('https://') ||
              option.mimeType.trim().isEmpty ||
              option.license.trim().isEmpty ||
              option.attribution.trim().isEmpty) {
            return 'Image candidates need a HTTPS URL, MIME type, license, and attribution.';
          }
        }
        final key = type == EventType.imageComparison
            ? option.imageUrl
            : (option.characterId.isNotEmpty
                  ? option.characterId
                  : (option.animeId.isNotEmpty ? option.animeId : option.label));
        if (ids.contains(key)) return 'Duplicate candidates are not allowed.';
        ids.add(key);
      }
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
