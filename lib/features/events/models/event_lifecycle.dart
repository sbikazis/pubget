import 'event_models.dart';

/// Client-side mirror of the server event lifecycle. Server state is
/// authoritative; this only validates UI input and keeps tests aligned.
abstract final class EventLifecycle {
  static const maxDuration = Duration(days: 7);
  static const minDuration = Duration(hours: 1);

  // Content ceilings mirrored from functions/src/eventsDomain.js.
  static const titleMax = 80;
  static const descriptionMax = 500;
  static const pollOptionMax = 7;
  static const pollOptionMin = 2;
  static const textMax = 1000;

  /// The audience expresses agreement or disagreement with a Theory.
  static const theoryStances = <String>{'agree', 'disagree'};

  /// Shared reaction bar inside an Event.
  static const reactions = <String>{'like', 'dislike'};

  /// Returned by the builder when the quota call could not be answered; the
  /// server remains the authoritative gatekeeper in that case.
  static const unknownQuotaRemaining = 99;

  static const allowed = <EventStatus, Set<EventStatus>>{
    EventStatus.draft: {EventStatus.active, EventStatus.deleted},
    EventStatus.active: {EventStatus.ended},
    EventStatus.ended: {EventStatus.archived},
    EventStatus.archived: <EventStatus>{},
    EventStatus.deleted: <EventStatus>{},
  };

  static bool canTransition(EventStatus from, EventStatus to) =>
      allowed[from]?.contains(to) ?? false;

  /// Returns a validation key (see AppStrings.eventMessage) or null.
  static String? validateWindow(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return 'ev.windowEndAfterStart';
    if (end.difference(start) < minDuration) return 'ev.windowMinDuration';
    if (end.difference(start) > maxDuration) return 'ev.windowMaxDuration';
    return null;
  }
}

/// Client-side validation. Every returned String is a stable key that
/// AppStrings.eventMessage maps to localized copy.
abstract final class EventValidation {
  static String? draft(EventDraft draft) {
    if (draft.title.trim().isEmpty) return 'ev.titleRequired';
    if (draft.title.trim().length > EventLifecycle.titleMax) {
      return 'ev.titleTooLong';
    }
    if (draft.description.trim().length > EventLifecycle.descriptionMax) {
      return 'ev.descriptionTooLong';
    }
    if (draft.scope == EventScope.group &&
        (draft.groupId == null || draft.groupId!.trim().isEmpty)) {
      return 'ev.chooseGroup';
    }
    if (draft.scope == EventScope.multiGroup && draft.groupIds.length < 2) {
      return 'ev.chooseTwoGroups';
    }
    final start = draft.startAt;
    final end = draft.endAt;
    if (start != null && end != null) {
      final window = EventLifecycle.validateWindow(start, end);
      if (window != null) return window;
    }
    return configuration(draft.type, draft.configuration);
  }

  /// Stricter than [draft]: what the server needs right before publishEvent.
  static String? publish(EventDraft draft) {
    final base = EventValidation.draft(draft);
    if (base != null) return base;
    if (draft.type == EventType.theory && draft.description.trim().isEmpty) {
      return 'ev.theoryBodyRequired';
    }
    return null;
  }

  static String? configuration(EventType type, EventConfiguration config) {
    if (type == EventType.theory) {
      // The prompt is optional for a Theory; the body is enforced by
      // [publish] at publish time (the server agrees: saveEventDraft is fine
      // without it, publishEvent is not).
      final anime = config.anime;
      if (anime != null) {
        final id = anime.animeId.trim();
        final title = anime.title.trim();
        if (id.isEmpty ||
            id.length > 64 ||
            title.isEmpty ||
            title.length > 160 ||
            (anime.imageUrl.isNotEmpty && !_isHttpImage(anime.imageUrl))) {
          return 'ev.animeInvalid';
        }
      }
      return null;
    }
    if (type == EventType.quiz) {
      if (config.questions.isEmpty || config.questions.length > 20) {
        return 'ev.quizNeedsQuestions';
      }
      for (var i = 0; i < config.questions.length; i++) {
        final question = config.questions[i];
        if (question.prompt.trim().isEmpty) return 'ev.quizPromptRequired';
        if (question.options.length < 2 || question.options.length > 6) {
          return 'ev.quizAnswerRange';
        }
        if (question.options.any((option) => option.label.trim().isEmpty)) {
          return 'ev.quizEmptyAnswer';
        }
        if (!question.options.any(
          (option) => option.id == question.correctOptionId,
        )) {
          return 'ev.quizCorrectAnswer';
        }
      }
      return null;
    }
    if (type == EventType.openDiscussion || type == EventType.challenge) {
      final prompt = config.prompt.trim().isNotEmpty
          ? config.prompt
          : config.question;
      if (prompt.trim().isEmpty) return 'ev.promptRequired';
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
        if (!kinds.contains(kind)) return 'ev.challengeKind';
        if (kind == 'participate_event' &&
            config.targetEventId.trim().isEmpty) {
          return 'ev.targetEventRequired';
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
      if (criterion.trim().isEmpty) return 'ev.criterionRequired';
      if (config.options.length < 2 || config.options.length > 10) {
        return 'ev.candidatesRange';
      }
      final ids = <String>{};
      for (final option in config.options) {
        if (type == EventType.characterComparison &&
            option.characterId.trim().isEmpty &&
            option.label.trim().isEmpty) {
          return 'ev.characterCatalogId';
        }
        if (type == EventType.animeComparison &&
            option.animeId.trim().isEmpty &&
            option.label.trim().isEmpty) {
          return 'ev.animeCatalogId';
        }
        if (type == EventType.imageComparison) {
          if (!option.imageUrl.startsWith('https://') ||
              option.mimeType.trim().isEmpty ||
              option.license.trim().isEmpty ||
              option.attribution.trim().isEmpty) {
            return 'ev.imageCandidateMeta';
          }
        }
        final key = type == EventType.imageComparison
            ? option.imageUrl
            : (option.characterId.isNotEmpty
                  ? option.characterId
                  : (option.animeId.isNotEmpty
                        ? option.animeId
                        : option.label));
        if (ids.contains(key)) return 'ev.duplicateCandidates';
        ids.add(key);
      }
      return null;
    }
    if (type == EventType.poll) {
      return poll(config);
    }
    final question = config.question.trim().isNotEmpty
        ? config.question
        : config.prompt;
    if (question.trim().isEmpty) return 'ev.questionRequired';
    if (config.options.length < 2 || config.options.length > 10) {
      return 'ev.optionsRange';
    }
    if (config.options.any((option) => option.label.trim().isEmpty)) {
      return 'ev.optionLabelRequired';
    }
    return null;
  }

  /// Poll: 2..7 options, each with a label and an image (owner requirement).
  static String? poll(EventConfiguration config) {
    final question = config.question.trim().isNotEmpty
        ? config.question
        : config.prompt;
    if (question.trim().isEmpty) return 'ev.questionRequired';
    final options = config.options;
    if (options.length < EventLifecycle.pollOptionMin ||
        options.length > EventLifecycle.pollOptionMax) {
      return 'ev.pollOptionsRange';
    }
    if (options.any((option) => option.label.trim().isEmpty)) {
      return 'ev.optionLabelRequired';
    }
    if (options.any((option) => !_isHttpImage(option.imageUrl))) {
      return 'ev.optionImageRequired';
    }
    return null;
  }
}

bool _isHttpImage(String url) {
  if (url.length < 12 || url.length > 1024) return false;
  return url.startsWith('https://');
}