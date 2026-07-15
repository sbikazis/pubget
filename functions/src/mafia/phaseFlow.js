// functions/src/mafia/phaseFlow.js
//
// نسخة مطابقة تماماً لـ lib/core/mafia/mafia_game_engine.dart (MafiaPhaseFlow)
// من ناحية ترتيب المراحل ومددها بالثواني. هذا الملف هو المصدر الحقيقي
// الوحيد الذي تُبنى عليه الانتقالات الفعلية (عبر phaseScheduler.js).
// أي تعديل هنا يستوجب تعديل مطابق يدوياً في mafia_constants.dart/mafia_game_engine.dart.

const ORDER = ['night', 'day', 'discussion', 'voting', 'execution'];

const DURATIONS_SECONDS = {
  night: 45,
  day: 20,
  discussion: 90,
  voting: 45,
  execution: 15,
};

function nextPhase(current) {
  const idx = ORDER.indexOf(current);
  if (idx === -1) return 'night';
  return ORDER[(idx + 1) % ORDER.length];
}

function durationOf(phase) {
  return DURATIONS_SECONDS[phase] || 0;
}

const ARABIC_MESSAGES = {
  night: '🌙 هبط الظلام على القرية، وبدأت الليلة...',
  day: '☀️ أشرقت الشمس، والقرية تترقب ما حدث الليلة الماضية.',
  discussion: '💬 فُتح باب النقاش بين الأهالي.',
  voting: '🗳️ بدأ التصويت لتحديد المشتبه به.',
  execution: '⚖️ حان وقت تنفيذ حكم القرية.',
};

module.exports = { ORDER, DURATIONS_SECONDS, nextPhase, durationOf, ARABIC_MESSAGES };