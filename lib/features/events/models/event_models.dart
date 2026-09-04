import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  poll,
  multipleChoice,
  ranking,
  versus,
  theory,
  prediction,
  quiz,
  imageComparison,
  characterComparison,
  animeComparison,
  openDiscussion,
  challenge,
}

enum EventStatus { draft, scheduled, active, ended, cancelled, archived }

final class EventOption {
  const EventOption({
    required this.id,
    required this.label,
    this.imageUrl = '',
    this.characterId = '',
    this.animeId = '',
    this.mimeType = '',
    this.license = '',
    this.attribution = '',
  });

  final String id;
  final String label;
  final String imageUrl;
  final String characterId;
  final String animeId;
  final String mimeType;
  final String license;
  final String attribution;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'label': label,
    if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    if (characterId.isNotEmpty) 'characterId': characterId,
    if (animeId.isNotEmpty) 'animeId': animeId,
    if (mimeType.isNotEmpty) 'mimeType': mimeType,
    if (license.isNotEmpty) 'license': license,
    if (attribution.isNotEmpty) 'attribution': attribution,
  };

  factory EventOption.fromMap(Map<String, dynamic> map, {required int index}) {
    return EventOption(
      id: map['id'] as String? ?? 'opt-${index + 1}',
      label: map['label'] as String? ?? map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      characterId: map['characterId'] as String? ?? '',
      animeId: map['animeId'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? '',
      license: map['license'] as String? ?? '',
      attribution: map['attribution'] as String? ?? '',
    );
  }
}

final class EventQuizQuestion {
  const EventQuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionId,
  });

  final String id;
  final String prompt;
  final List<EventOption> options;
  final String correctOptionId;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'prompt': prompt,
    'options': options.map((item) => item.toMap()).toList(growable: false),
    'correctOptionId': correctOptionId,
  };

  factory EventQuizQuestion.fromMap(
    Map<String, dynamic> map, {
    required int index,
  }) {
    final options = _options(map['options']);
    return EventQuizQuestion(
      id: map['id'] as String? ?? 'q-${index + 1}',
      prompt: map['prompt'] as String? ?? '',
      options: options,
      correctOptionId:
          map['correctOptionId'] as String? ??
          (options.isEmpty ? '' : options.first.id),
    );
  }

  EventQuizQuestion copyWith({
    String? id,
    String? prompt,
    List<EventOption>? options,
    String? correctOptionId,
  }) => EventQuizQuestion(
    id: id ?? this.id,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    correctOptionId: correctOptionId ?? this.correctOptionId,
  );
}

final class EventConfiguration {
  const EventConfiguration({
    this.question = '',
    this.prompt = '',
    this.options = const <EventOption>[],
    this.questions = const <EventQuizQuestion>[],
    this.maxSelections = 1,
    this.allowMultiple = false,
    this.allowUpdate = false,
    this.allowVoting = false,
    this.completionRule = '',
    this.criterion = '',
    this.challengeKind = '',
    this.targetEventId = '',
  });

  final String question;
  final String prompt;
  final List<EventOption> options;
  final List<EventQuizQuestion> questions;
  final int maxSelections;
  final bool allowMultiple;
  final bool allowUpdate;
  final bool allowVoting;
  final String completionRule;
  final String criterion;
  final String challengeKind;
  final String targetEventId;

  EventConfiguration copyWith({
    String? question,
    String? prompt,
    List<EventOption>? options,
    List<EventQuizQuestion>? questions,
    int? maxSelections,
    bool? allowMultiple,
    bool? allowUpdate,
    bool? allowVoting,
    String? completionRule,
    String? criterion,
    String? challengeKind,
    String? targetEventId,
  }) => EventConfiguration(
    question: question ?? this.question,
    prompt: prompt ?? this.prompt,
    options: options ?? this.options,
    questions: questions ?? this.questions,
    maxSelections: maxSelections ?? this.maxSelections,
    allowMultiple: allowMultiple ?? this.allowMultiple,
    allowUpdate: allowUpdate ?? this.allowUpdate,
    allowVoting: allowVoting ?? this.allowVoting,
    completionRule: completionRule ?? this.completionRule,
    criterion: criterion ?? this.criterion,
    challengeKind: challengeKind ?? this.challengeKind,
    targetEventId: targetEventId ?? this.targetEventId,
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'question': question,
    'prompt': prompt,
    'options': options.map((item) => item.toMap()).toList(growable: false),
    'questions': questions.map((item) => item.toMap()).toList(growable: false),
    'maxSelections': maxSelections,
    'allowMultiple': allowMultiple,
    'allowUpdate': allowUpdate,
    'allowVoting': allowVoting,
    'completionRule': completionRule,
    if (criterion.isNotEmpty) 'criterion': criterion,
    if (challengeKind.isNotEmpty) 'challengeKind': challengeKind,
    if (targetEventId.isNotEmpty) 'targetEventId': targetEventId,
  };

  factory EventConfiguration.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EventConfiguration();
    return EventConfiguration(
      question: map['question'] as String? ?? '',
      prompt: map['prompt'] as String? ?? '',
      options: _options(map['options'] ?? map['candidates'] ?? map['items']),
      questions: (map['questions'] is List)
          ? [
              for (var i = 0; i < (map['questions'] as List).length; i++)
                if ((map['questions'] as List)[i] is Map)
                  EventQuizQuestion.fromMap(
                    Map<String, dynamic>.from(
                      (map['questions'] as List)[i] as Map,
                    ),
                    index: i,
                  ),
            ]
          : const <EventQuizQuestion>[],
      maxSelections: (map['maxSelections'] as num?)?.toInt() ?? 1,
      allowMultiple: map['allowMultiple'] == true,
      allowUpdate: map['allowUpdate'] == true,
      allowVoting: map['allowVoting'] == true,
      completionRule: map['completionRule'] as String? ?? '',
      criterion: map['criterion'] as String? ?? map['question'] as String? ?? '',
      challengeKind: map['challengeKind'] as String? ?? '',
      targetEventId: map['targetEventId'] as String? ?? '',
    );
  }
}

final class EventResult {
  const EventResult({
    required this.kind,
    required this.submissions,
    this.votes = const <String, int>{},
    this.scores = const <String, int>{},
    this.correctCounts = const <String, int>{},
    this.winnerIds = const <String>[],
  });

  final String kind;
  final int submissions;
  final Map<String, int> votes;
  final Map<String, int> scores;
  final Map<String, int> correctCounts;
  final List<String> winnerIds;

  factory EventResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const EventResult(kind: '', submissions: 0);
    }
    return EventResult(
      kind: map['kind'] as String? ?? '',
      submissions: (map['submissions'] as num?)?.toInt() ?? 0,
      votes: _intMap(map['votes']),
      scores: _intMap(map['scores']),
      correctCounts: _intMap(map['correctCounts']),
      winnerIds:
          (map['winnerIds'] as List<Object?>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
    );
  }
}

final class EventTally {
  const EventTally({
    this.submissions = 0,
    this.votes = const <String, int>{},
    this.scores = const <String, int>{},
    this.correctCounts = const <String, int>{},
  });

  final int submissions;
  final Map<String, int> votes;
  final Map<String, int> scores;
  final Map<String, int> correctCounts;

  factory EventTally.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EventTally();
    return EventTally(
      submissions: (map['submissions'] as num?)?.toInt() ?? 0,
      votes: _intMap(map['votes']),
      scores: _intMap(map['scores']),
      correctCounts: _intMap(map['correctCounts']),
    );
  }
}

final class PubgetEvent {
  const PubgetEvent({
    required this.id,
    required this.type,
    required this.creatorId,
    required this.groupId,
    required this.title,
    required this.description,
    required this.configuration,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.participantsCount,
    required this.responsesCount,
    required this.tally,
    required this.result,
    required this.createdAt,
    required this.updatedAt,
    this.coverUrl = '',
    this.templateId,
    this.version = 1,
  });

  final String id;
  final EventType type;
  final String creatorId;
  final String? groupId;
  final String title;
  final String description;
  final EventConfiguration configuration;
  final EventStatus status;
  final DateTime? startAt;
  final DateTime? endAt;
  final int participantsCount;
  final int responsesCount;
  final EventTally tally;
  final EventResult? result;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String coverUrl;
  final String? templateId;
  final int version;

  bool get isOpen =>
      status == EventStatus.active || status == EventStatus.scheduled;
  bool get isHistorical =>
      status == EventStatus.ended || status == EventStatus.archived;
  bool get isReadOnly =>
      status == EventStatus.ended ||
      status == EventStatus.archived ||
      status == EventStatus.cancelled;

  /// UI hint. The backend still rejects expired participation.
  bool isExpired([DateTime? now]) {
    final end = endAt;
    if (end == null) return false;
    return !end.isAfter(now ?? DateTime.now());
  }

  bool isInteractable([DateTime? now]) =>
      status == EventStatus.active && !isExpired(now);

  Duration? remaining(DateTime now) {
    if (endAt == null) return null;
    final left = endAt!.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'type': type.name,
    'creatorId': creatorId,
    'groupId': groupId,
    'title': title,
    'description': description,
    'configuration': configuration.toMap(),
    'status': status.name,
    'startAt': startAt?.toUtc().toIso8601String(),
    'endAt': endAt?.toUtc().toIso8601String(),
    'participantsCount': participantsCount,
    'responsesCount': responsesCount,
    'tally': <String, dynamic>{
      'submissions': tally.submissions,
      'votes': tally.votes,
      'scores': tally.scores,
      'correctCounts': tally.correctCounts,
    },
    'result': result == null
        ? null
        : <String, dynamic>{
            'kind': result!.kind,
            'submissions': result!.submissions,
            'votes': result!.votes,
            'scores': result!.scores,
            'correctCounts': result!.correctCounts,
            'winnerIds': result!.winnerIds,
          },
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'coverUrl': coverUrl,
    'templateId': templateId,
    'version': version,
    'searchName': title.trim().toLowerCase(),
  };

  factory PubgetEvent.fromMap(Map<String, dynamic> map, {required String id}) {
    return PubgetEvent(
      id: id,
      type: EventType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => EventType.poll,
      ),
      creatorId: map['creatorId'] as String? ?? '',
      groupId: map['groupId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      configuration: EventConfiguration.fromMap(
        map['configuration'] is Map
            ? Map<String, dynamic>.from(map['configuration'] as Map)
            : null,
      ),
      status: EventStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => EventStatus.draft,
      ),
      startAt: _date(map['startAt']),
      endAt: _date(map['endAt']),
      participantsCount: (map['participantsCount'] as num?)?.toInt() ?? 0,
      responsesCount: (map['responsesCount'] as num?)?.toInt() ?? 0,
      tally: EventTally.fromMap(
        map['tally'] is Map
            ? Map<String, dynamic>.from(map['tally'] as Map)
            : null,
      ),
      result: map['result'] is Map
          ? EventResult.fromMap(Map<String, dynamic>.from(map['result'] as Map))
          : null,
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
      coverUrl: map['coverUrl'] as String? ?? '',
      templateId: map['templateId'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}

final class EventResponse {
  const EventResponse({
    required this.eventId,
    required this.userId,
    required this.submittedAt,
    required this.responseData,
    this.updatedAt,
  });

  final String eventId;
  final String userId;
  final DateTime? submittedAt;
  final DateTime? updatedAt;
  final Map<String, dynamic> responseData;

  factory EventResponse.fromMap(
    Map<String, dynamic> map, {
    required String userId,
  }) {
    return EventResponse(
      eventId: map['eventId'] as String? ?? '',
      userId: userId,
      submittedAt: _date(map['submittedAt']),
      updatedAt: _date(map['updatedAt']),
      responseData: map['responseData'] is Map
          ? Map<String, dynamic>.from(map['responseData'] as Map)
          : const <String, dynamic>{},
    );
  }
}

final class EventParticipant {
  const EventParticipant({
    required this.userId,
    required this.displayName,
    this.joinedAt,
    this.leftAt,
  });

  final String userId;
  final String displayName;
  final DateTime? joinedAt;
  final DateTime? leftAt;

  bool get isActive => leftAt == null;

  factory EventParticipant.fromMap(
    Map<String, dynamic> map, {
    required String userId,
  }) {
    return EventParticipant(
      userId: userId,
      displayName: map['displayName'] as String? ?? userId,
      joinedAt: _date(map['joinedAt']),
      leftAt: _date(map['leftAt']),
    );
  }
}

final class EventDraft {
  const EventDraft({
    this.eventId,
    this.groupId,
    this.type = EventType.poll,
    this.title = '',
    this.description = '',
    this.templateId,
    this.startAt,
    this.endAt,
    this.configuration = const EventConfiguration(),
  });

  final String? eventId;
  final String? groupId;
  final EventType type;
  final String title;
  final String description;
  final String? templateId;
  final DateTime? startAt;
  final DateTime? endAt;
  final EventConfiguration configuration;

  factory EventDraft.fromEvent(PubgetEvent event) => EventDraft(
    eventId: event.id,
    groupId: event.groupId,
    type: event.type,
    title: event.title,
    description: event.description,
    templateId: event.templateId,
    startAt: event.startAt,
    endAt: event.endAt,
    configuration: event.configuration,
  );

  EventDraft copyWith({
    String? eventId,
    String? groupId,
    EventType? type,
    String? title,
    String? description,
    String? templateId,
    DateTime? startAt,
    DateTime? endAt,
    EventConfiguration? configuration,
    bool clearTemplate = false,
  }) => EventDraft(
    eventId: eventId ?? this.eventId,
    groupId: groupId ?? this.groupId,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    templateId: clearTemplate ? null : templateId ?? this.templateId,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    configuration: configuration ?? this.configuration,
  );

  Map<String, dynamic> toCallableMap() {
    return <String, dynamic>{
      if (eventId != null) 'eventId': eventId,
      if (groupId != null) 'groupId': groupId,
      'type': type.name,
      'title': title,
      'description': description,
      if (templateId != null) 'templateId': templateId,
      'configuration': configuration.toMap(),
      'question': configuration.question,
      'prompt': configuration.prompt,
      'options': configuration.options.map((item) => item.toMap()).toList(),
      'candidates': configuration.options.map((item) => item.toMap()).toList(),
      'items': configuration.options.map((item) => item.toMap()).toList(),
      'questions': configuration.questions.map((item) => item.toMap()).toList(),
      if (configuration.criterion.isNotEmpty) 'criterion': configuration.criterion,
      if (configuration.challengeKind.isNotEmpty)
        'challengeKind': configuration.challengeKind,
      if (configuration.targetEventId.isNotEmpty)
        'targetEventId': configuration.targetEventId,
    };
  }
}

List<EventOption> _options(dynamic raw) {
  if (raw is! List) return const <EventOption>[];
  return [
    for (var i = 0; i < raw.length; i++)
      if (raw[i] is String)
        EventOption(id: 'opt-${i + 1}', label: raw[i] as String)
      else if (raw[i] is Map)
        EventOption.fromMap(Map<String, dynamic>.from(raw[i] as Map), index: i),
  ];
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map) return const <String, int>{};
  final result = <String, int>{};
  for (final entry in raw.entries) {
    if (entry.key is String && entry.value is num) {
      result[entry.key as String] = (entry.value as num).toInt();
    }
  }
  return result;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  try {
    return value?.toDate() as DateTime?;
  } catch (_) {
    return null;
  }
}
