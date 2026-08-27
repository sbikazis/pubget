// functions/src/mafia/phaseFlow.js
//
// نسخة مطابقة تماماً لـ lib/core/mafia/mafia_game_engine.dart (MafiaPhaseFlow)
// من ناحية ترتيب المراحل ومددها بالثواني.

const ORDER = ['waiting', 'starting', 'night', 'day', 'discussion', 'voting', 'execution']; // تم اضافة waiting, starting

const DURATIONS_SECONDS = {
  waiting: 120, // lobbyWaitSeconds من Flutter - دقيقتين
  starting: 10, // startingCountdownSeconds
  night: 45,
  day: 20,
  discussion: 90,
  voting: 45,
  execution: 15,
};

function nextPhase(current) {
  const idx = ORDER.indexOf(current);
  if (idx === -1) return 'waiting'; // نبدأ من waiting
  return ORDER[(idx + 1) % ORDER.length];
}

function durationOf(phase) {
  return DURATIONS_SECONDS[phase] || 0;
}

const ARABIC_MESSAGES = {
  waiting: '⏳ في انتظار اكتمال اللاعبين...',
  starting: '🚀 ستبدأ اللعبة خلال لحظات!',
  night: '🌙 هبط الظلام على القرية، وبدأت الليلة...',
  day: '☀️ أشرقت الشمس، والقرية تترقب ما حدث الليلة الماضية.',
  discussion: '💬 فُتح باب النقاش بين الأهالي.',
  voting: '🗳️ بدأ التصويت لتحديد المشتبه به.',
  execution: '⚖️ حان وقت تنفيذ حكم القرية.',
};

module.exports = {
  ORDER,
  DURATIONS_SECONDS,
  nextPhase,
  durationOf,
  ARABIC_MESSAGES
};