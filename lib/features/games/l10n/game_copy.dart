import 'package:flutter/widgets.dart';

import '../../../core/l10n/app_strings.dart';
import '../models/game_models.dart';
import '../models/game_type_registry.dart';

/// Localized chrome for the Game Center (Spec 12), game details, and the
/// three game play panels (Spec 12.2).
///
/// [GameStrings] stays the English source so engine-level messages, tests,
/// and server parity keep one reference; every UI call site reads this class
/// instead.
final class GameCopy {
  const GameCopy(this._s);

  final AppStrings _s;

  static GameCopy of(BuildContext context) => GameCopy(AppStrings.of(context));

  static GameCopy forLocale(Locale? locale) =>
      GameCopy(AppStrings.forLocale(locale));

  // ── Game Center sections (Spec 12.1) ───────────────────────────────────
  String get gameCenter => _s.pick('Game Center', 'مركز الألعاب');
  String get gameCenterInGroup => _s.pick(
    'Games in this group',
    'ألعاب هذه المجموعة',
  );
  String get tabAvailable => _s.pick('Available', 'متاحة');
  String get tabActive => _s.pick('Active', 'جارية');
  String get tabWaiting => _s.pick('Waiting', 'بالانتظار');
  String get tabRecent => _s.pick('Recent', 'الحديثة');
  String get tabHistory => _s.pick('History', 'السجل');
  String get tabRules => _s.pick('Rules', 'القوانين');
  String get createGame => _s.pick('Create game', 'إنشاء لعبة');
  String get noActiveGames => _s.pick(
    'No games are running right now.',
    'لا توجد ألعاب جارية الآن.',
  );
  String get noWaitingGames => _s.pick(
    'No games are waiting for players.',
    'لا توجد ألعاب في انتظار اللاعبين.',
  );
  String get noRecentGames => _s.pick(
    'No finished games yet.',
    'لا توجد ألعاب منتهية بعد.',
  );
  String get noHistoryGames => _s.pick(
    'Your game history is empty.',
    'سجل ألعابك فارغ.',
  );
  String get createFromGroupChatOnly => _s.pick(
    'Games are created from a group chat. Open one to start a game.',
    'تُنشأ الألعاب من دردشة مجموعة. افتح واحدة لبدء لعبة.',
  );
  String get createFromGroupChatButton => _s.pick(
    'Only members can create a game, from the group chat.',
    'الأعضاء فقط يمكنهم إنشاء لعبة، من دردشة المجموعة.',
  );

  // ── Game card facts (Spec 12.1) ────────────────────────────────────────
  String playerCount(int players) => _s.pick(
    '$players players',
    '$players لاعبين',
  );
  String playerRange(int min, int max) => _s.pick(
    '$min–$max players',
    '$min–$max لاعبين',
  );
  String playerCountOf(int players, int max) => _s.pick(
    '$players/$max players',
    '$players/$max لاعبين',
  );
  String durationMinutes(int minutes) => _s.pick(
    '$minutes min',
    '$minutes دقيقة',
  );
  String get difficultyTitle => _s.pick('Difficulty', 'الصعوبة');
  String difficulty(String raw) => switch (raw) {
    'easy' => _s.pick('Easy', 'سهل'),
    'hard' => _s.pick('Hard', 'صعب'),
    _ => _s.pick('Normal', 'متوسط'),
  };
  String get winCondition => _s.pick('Win condition', 'شرط الفوز');

  /// Per-type rules and win conditions for the Rules section. English stays
  /// sourced from the registry so the two never drift apart.
  String rulesFor(GameType type) {
    final spec = GameTypeRegistry.tryOf(type);
    if (spec == null) return '';
    return _s.pick(spec.rules, _rulesAr(type));
  }

  String winConditionFor(GameType type) {
    final spec = GameTypeRegistry.tryOf(type);
    if (spec == null) return '';
    return _s.pick(spec.winCondition, _winConditionAr(type));
  }

  String _rulesAr(GameType type) => switch (type) {
    GameType.guessCharacter => 'يختار كل لاعب شخصية سرية من الكتالوج، ثم '
        'يتناوبون على طرح أسئلة بنعم/لا أو التخمين مباشرة.',
    GameType.animeChain => 'تناوبوا على تسمية أنمي مرتبط بالعنوان السابق. '
        'الرابط المعطوب أو المكرر أو انتهاء المهلة ينهي اللعبة.',
    GameType.emojiAnimeGuess => 'لاعب يملك إشارة الإيموجي ولا يخمّن. البقية '
        'يخمّنون الأنمي مرة لكل جولة؛ التخمين الصحيح يسجل نقطة.',
    GameType.mafia => 'الأدوار سرية ويوزّعها السيرفر. الليل يُحسم بصمت، '
        'والنهار يصوّت لإقصاء لاعب، ودردشة المافيا خاصة.',
  };

  String _winConditionAr(GameType type) => switch (type) {
    GameType.guessCharacter => 'خمّن الشخصية السرية للاعب الآخر.',
    GameType.animeChain => 'امتلاك أعلى نتيجة عند نهاية السلسلة.',
    GameType.emojiAnimeGuess => 'أكثر التخمينات الصحيحة عبر الجولات.',
    GameType.mafia => 'فوز المافيا بتعادل أعدادها مع المدينة، أو إقصاء '
        'المدينة لكل أعضاء المافيا.',
  };

  String get noWinner => _s.pick('No winner', 'لا يوجد فائز');
  String get winner => _s.pick('Winner', 'الفائز');
  String winners(List<String> ids) => _s.pick(
    'Winners: ${ids.join(', ')}',
    'الفائزون: ${ids.join('، ')}',
  );
  String roundCount(int rounds) => _s.pick(
    '$rounds rounds',
    '$rounds جولات',
  );
  String timerSeconds(int seconds) => _s.pick('${seconds}s', '$seconds ث');

  String statusLabel(GameStatus status) => switch (status) {
    GameStatus.created => _s.pick('Created', 'تم الإنشاء'),
    GameStatus.waiting => _s.pick('Waiting', 'بالانتظار'),
    GameStatus.starting => _s.pick('Starting', 'قيد البدء'),
    GameStatus.inProgress => _s.pick('In progress', 'جارية'),
    GameStatus.completed => _s.pick('Completed', 'منتهية'),
    GameStatus.cancelled => _s.pick('Cancelled', 'ملغاة'),
  };

  // ── Create page ────────────────────────────────────────────────────────
  String get gameTypeTitle => _s.pick('Game type', 'نوع اللعبة');
  String get titleLabel => _s.pick('Title', 'العنوان');
  String get descriptionLabel => _s.pick('Description', 'الوصف');
  String get rulesTitle => _s.pick('Rules', 'القوانين');
  String get roundsLabel => _s.pick('Rounds', 'الجولات');
  String roundsOption(int rounds) => _s.pick(
    '$rounds rounds',
    '$rounds جولات',
  );
  String get timerLabel => _s.pick('Timer', 'المؤقت');
  String secondsOption(int seconds) => _s.pick(
    '$seconds seconds',
    '$seconds ثانية',
  );
  String get lobbyTitle => _s.pick('Lobby', 'غرفة الانتظار');
  String get minPlayersLabel =>
      _s.pick('Minimum players', 'الحد الأدنى للاعبين');
  String get maxPlayersLabel =>
      _s.pick('Maximum players', 'الحد الأقصى للاعبين');
  String get mafiaNeedsGroup => _s.pick(
    'Mafia must be created from a group.',
    'يجب إنشاء المافيا من مجموعة.',
  );
  String get mafiaCreateFailed =>
      _s.pick('Could not create Mafia.', 'تعذّر إنشاء المافيا.');

  // ── Details / lobby ────────────────────────────────────────────────────
  String get gameTitleFallback => _s.pick('Game', 'لعبة');
  String get playersTitle => _s.pick('Players', 'اللاعبون');
  String get noPlayersYet => _s.pick('No players yet', 'لا يوجد لاعبون بعد');
  String get joinFirst => _s.pick('Join to be the first.', 'انضم لتكون الأول.');
  String get needPlayersToStart => _s.pick(
    'Need enough players to start.',
    'يلزم لاعبون كافيون للبدء.',
  );
  String needPlayersToStartCount(int min, int joined) => _s.pick(
    'Need $min players to start. $joined joined.',
    'يلزم $min لاعبين للبدء. انضم $joined حتى الآن.',
  );
  String get cancelTitle => _s.pick('Cancel this game?', 'إلغاء هذه اللعبة؟');
  String get cancelBody => _s.pick(
    'Players will be returned to the lobby list. This cannot be undone.',
    'سيعود اللاعبون إلى قائمة الانتظار. لا يمكن التراجع عن هذا.',
  );
  String get keepPlaying => _s.pick('Keep playing', 'متابعة اللعب');
  String get waitingRoomClosesIn => _s.pick(
    'Waiting room closes in',
    'يُغلق غرفة الانتظار خلال',
  );
  String get waitingRoomFull => _s.pick(
    'The lobby is full — the game starts as soon as the creator is ready.',
    'الغرفة مكتملة — تبدأ اللعبة فور جاهزية المنظم.',
  );
  String gameStatusLine(String status) => _s.pick(
    'This game is $status.',
    'هذه اللعبة $status.',
  );
  String get gamesCouldNotLoad => _s.pick(
    'Games could not load.',
    'تعذّر تحميل الألعاب.',
  );
  String get creating => _s.pick('Creating…', 'جاري الإنشاء…');
  String get seeAllGames => _s.pick('See all games', 'عرض كل الألعاب');

  // ── Shared actions / states (mirrors GameStrings for EN parity) ────────
  String get noGamesTitle =>
      _s.pick(GameStrings.noGamesTitle, 'لا توجد ألعاب بعد');
  String get noGamesMessage => _s.pick(
    GameStrings.noGamesMessage,
    'ابدأ لعبة من مجموعة.',
  );
  String get missing => _s.pick(GameStrings.missing, 'هذه اللعبة لم تعد موجودة.');
  String get permission =>
      _s.pick(GameStrings.permission, 'لا تملك صلاحية إدارة الألعاب.');
  String get notJoinable =>
      _s.pick(GameStrings.notJoinable, 'هذه اللعبة غير مفتوحة للانضمام.');
  String get alreadyStarted =>
      _s.pick(GameStrings.alreadyStarted, 'هذه اللعبة بدأت بالفعل.');
  String get alreadyCompleted =>
      _s.pick(GameStrings.alreadyCompleted, 'هذه اللعبة انتهت بالفعل.');
  String get notParticipant => _s.pick(
    GameStrings.notParticipant,
    'أنت لست من المشاركين في هذه اللعبة.',
  );
  String get create => createGame;
  String get join => _s.pick(GameStrings.join, 'الانضمام للعبة');
  String get leave => _s.pick(GameStrings.leave, 'مغادرة اللعبة');
  String get start => _s.pick(GameStrings.start, 'بدء اللعبة');
  String get end => _s.pick(GameStrings.end, 'إنهاء اللعبة');
  String get cancel => _s.pick(GameStrings.cancel, 'إلغاء اللعبة');
  String get submit => _s.pick(GameStrings.submit, 'إرسال الحركة');
  String get retry => _s.pick(GameStrings.retry, 'إعادة المحاولة');
  String get seeAll => _s.pick(GameStrings.seeAll, 'عرض كل الألعاب');
  String get groupGames => _s.pick(GameStrings.groupGames, 'ألعاب المجموعة');
  String get resultTitle => _s.pick(GameStrings.resultTitle, 'النتيجة');
  String get draw => _s.pick('Draw', 'تعادل');
  String get youWon => _s.pick('You won', 'لقد فزت');
  String get chainRule => _s.pick(
    'Keep the chain valid.',
    'حافظ على صحة السلسلة.',
  );
  String get comingSoon =>
      _s.pick(GameStrings.comingSoon, 'هذه اللعبة غير متاحة بعد.');
  String get copied => _s.pick(GameStrings.copied, 'تم نسخ رابط اللعبة');
  String get copyLink => _s.pick(GameStrings.copyLink, 'نسخ الرابط');
  String get share => _s.pick(GameStrings.share, 'مشاركة');
  String get playAgain => _s.pick(GameStrings.playAgain, 'العب مرة أخرى');
  String get viewHistory => _s.pick(GameStrings.viewHistory, 'عرض السجل');
  String get eliminated => _s.pick(GameStrings.eliminated, 'مُقصى');
  String get waitingForPlayers =>
      _s.pick(GameStrings.waitingForPlayers, 'في انتظار اللاعبين');
  String get cannotStart =>
      _s.pick(GameStrings.cannotStart, 'لا يوجد لاعبون كافيون للبدء.');
  String get yourTurn => _s.pick(GameStrings.yourTurn, 'دورك');
  String get waitingTurn => _s.pick(
    GameStrings.waitingTurn,
    'في انتظار اللاعبين الآخرين',
  );
  String get submitting => _s.pick(GameStrings.submitting, 'جاري الإرسال…');
  String get timedOut => _s.pick(GameStrings.timedOut, 'انتهى الوقت');
  String get reconnecting => _s.pick(
    GameStrings.reconnecting,
    'جاري إعادة الاتصال باللعبة…',
  );
  String get offlineAction => _s.pick(
    GameStrings.offlineAction,
    'اتصل بالإنترنت لتنفيذ هذه الحركة.',
  );

  // ── Guess Character / anime chain / emoji panels ───────────────────────
  String get guessCharacter =>
      _s.pick(GameStrings.guessCharacter, 'خمّن الشخصية');
  String get chooseSecret =>
      _s.pick(GameStrings.chooseSecret, 'اختر شخصيتك السرية');
  String get secretLocked => _s.pick(
    GameStrings.secretLocked,
    'تم تثبيت السر. في انتظار اللاعب الآخر.',
  );
  String get searchSecretCharacter => _s.pick(
    GameStrings.searchSecretCharacter,
    'ابحث في كتالوج الشخصيات',
  );
  String get noCatalogMatch =>
      _s.pick(GameStrings.noCatalogMatch, 'لا توجد نتائج في الكتالوج.');
  String get askAQuestion =>
      _s.pick(GameStrings.askAQuestion, 'اسأل سؤال بنعم أو لا');
  String get guessInstead =>
      _s.pick(GameStrings.guessInstead, 'أو خمّن الشخصية مباشرة');
  String get ask => _s.pick(GameStrings.ask, 'اسأل');
  String get yes => _s.pick(GameStrings.yes, 'نعم');
  String get no => _s.pick(GameStrings.no, 'لا');
  String get answered => _s.pick(GameStrings.answered, 'أجب');
  String get wrongGuess =>
      _s.pick(GameStrings.wrongGuess, 'تخمين خاطئ. انتقل الدور.');
  String get turnTimedOut =>
      _s.pick(GameStrings.turnTimedOut, 'انتهى وقت الدور.');
  String get clueOwnerTurn => _s.pick(
    GameStrings.clueOwnerTurn,
    'أنت صاحب هذه الإشارة. انتظر التخمين.',
  );
  String get alreadyGuessed => _s.pick(
    GameStrings.alreadyGuessed,
    'لقد خمّنت في هذه الجولة.',
  );
  String get nextTitle => _s.pick(GameStrings.nextTitle, 'العنوان التالي');
  String get animeTitle => _s.pick(GameStrings.animeTitle, 'عنوان الأنمي');
  String get submitGuess => _s.pick(GameStrings.submitGuess, 'إرسال التخمين');
  String get lastTitle => _s.pick(GameStrings.lastTitle, 'العنوان الأخير');
  String get turn => _s.pick(GameStrings.turn, 'الدور');
  String get you => _s.pick(GameStrings.you, 'أنت');
  String get guessTheAnime => _s.pick(
    GameStrings.guessTheAnime,
    'خمّن الأنمي من إشارة الإيموجي',
  );
}
