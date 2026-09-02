import 'event_models.dart';

final class EventTypeSpec {
  const EventTypeSpec({
    required this.type,
    required this.label,
    required this.usesOptions,
    required this.usesTextResponse,
    required this.usesQuiz,
    required this.usesRanking,
    required this.hint,
  });

  final EventType type;
  final String label;
  final bool usesOptions;
  final bool usesTextResponse;
  final bool usesQuiz;
  final bool usesRanking;
  final String hint;
}

abstract final class EventTypeRegistry {
  static const specs = <EventType, EventTypeSpec>{
    EventType.poll: EventTypeSpec(
      type: EventType.poll,
      label: 'Poll',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Question, options, and voting rules.',
    ),
    EventType.multipleChoice: EventTypeSpec(
      type: EventType.multipleChoice,
      label: 'Multiple choice',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Question with one or more selectable choices.',
    ),
    EventType.ranking: EventTypeSpec(
      type: EventType.ranking,
      label: 'Ranking',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: true,
      hint: 'Participants rank the provided options.',
    ),
    EventType.versus: EventTypeSpec(
      type: EventType.versus,
      label: 'Versus',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Two or more candidates compete.',
    ),
    EventType.theory: EventTypeSpec(
      type: EventType.theory,
      label: 'Theory',
      usesOptions: false,
      usesTextResponse: true,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Community theories and discussion.',
    ),
    EventType.prediction: EventTypeSpec(
      type: EventType.prediction,
      label: 'Prediction',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Predictions that can be resolved later.',
    ),
    EventType.quiz: EventTypeSpec(
      type: EventType.quiz,
      label: 'Quiz',
      usesOptions: false,
      usesTextResponse: false,
      usesQuiz: true,
      usesRanking: false,
      hint: 'Questions with correct answers.',
    ),
    EventType.imageComparison: EventTypeSpec(
      type: EventType.imageComparison,
      label: 'Image comparison',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Compare images or visual items.',
    ),
    EventType.characterComparison: EventTypeSpec(
      type: EventType.characterComparison,
      label: 'Character comparison',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Compare anime characters.',
    ),
    EventType.animeComparison: EventTypeSpec(
      type: EventType.animeComparison,
      label: 'Anime comparison',
      usesOptions: true,
      usesTextResponse: false,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Compare anime titles.',
    ),
    EventType.openDiscussion: EventTypeSpec(
      type: EventType.openDiscussion,
      label: 'Open discussion',
      usesOptions: false,
      usesTextResponse: true,
      usesQuiz: false,
      usesRanking: false,
      hint: 'Structured discussion without mandatory voting.',
    ),
    EventType.challenge: EventTypeSpec(
      type: EventType.challenge,
      label: 'Challenge',
      usesOptions: false,
      usesTextResponse: true,
      usesQuiz: false,
      usesRanking: false,
      hint: 'A community challenge with a completion rule.',
    ),
  };

  static const templates = <String, EventType>{
    'animeBattle': EventType.versus,
    'bestCharacter': EventType.characterComparison,
    'theoryNight': EventType.theory,
    'emojiChallenge': EventType.challenge,
    'guessCharacter': EventType.quiz,
  };

  static const templateLabels = <String, String>{
    'animeBattle': 'Anime Battle',
    'bestCharacter': 'Best Character',
    'theoryNight': 'Theory Night',
    'emojiChallenge': 'Emoji Challenge',
    'guessCharacter': 'Guess the Character',
  };

  static EventTypeSpec of(EventType type) => specs[type]!;
}

abstract final class EventStrings {
  static const noEventsTitle = 'No active events yet';
  static const noEventsMessage = 'Discover groups or create an event.';
  static const noParticipation = 'Join this event to take part.';
  static const ended = 'This event has ended.';
  static const cancelled = 'This event was cancelled.';
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
