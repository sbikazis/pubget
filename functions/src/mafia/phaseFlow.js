// Mafia is a game domain, not an Events workflow. These are the only legal
// states in the server-owned state machine.
const LOBBY_ORDER = ["waiting", "starting", "role_reveal"];
const PLAY_ORDER = [
  "night",
  "day",
  "discussion",
  "voting",
  "vote_result",
  "resolution",
];
const TERMINAL_PHASES = new Set(["game_over", "cancelled"]);
const ORDER = [...LOBBY_ORDER, ...PLAY_ORDER, "game_over", "cancelled"];

const DURATIONS_SECONDS = {
  waiting: 120,
  starting: 10,
  role_reveal: 8,
  night: 45,
  day: 20,
  discussion: 90,
  voting: 45,
  vote_result: 6,
  resolution: 4,
};

const TRANSITIONS = {
  waiting: "starting",
  starting: "role_reveal",
  role_reveal: "night",
  night: "day",
  day: "discussion",
  discussion: "voting",
  voting: "vote_result",
  vote_result: "resolution",
  resolution: "night",
};

function nextPhase(current) {
  if (TERMINAL_PHASES.has(current)) return current;
  return TRANSITIONS[current] || "night";
}

function durationOf(phase) {
  return DURATIONS_SECONDS[phase] || 0;
}

const PHASE_MESSAGES = {
  waiting: "Waiting for players to join.",
  starting: "Roles are being assigned.",
  night: "Night falls. The village sleeps.",
  day: "Morning. The village learns what happened overnight.",
  discussion: "Discussion is open.",
  voting: "Voting has begun.",
  vote_result: "The vote result is being revealed.",
  resolution: "The village resolves the vote.",
  game_over: "The Mafia game is over.",
};

const ARABIC_MESSAGES = {
  waiting: "بانتظار اللاعبين.",
  starting: "تبدأ المافيا قريبًا.",
  role_reveal: "تم توزيع الأدوار سرًا.",
  night: "حلّ الليل. القرية نائمة.",
  day: "أشرقت الشمس.",
  discussion: "وقت النقاش.",
  voting: "بدأ التصويت السري.",
  vote_result: "يتم إعلان نتيجة التصويت.",
  resolution: "تتم معالجة النتيجة.",
  game_over: "انتهت لعبة المافيا.",
};

module.exports = {
  ORDER,
  PLAY_ORDER,
  DURATIONS_SECONDS,
  nextPhase,
  durationOf,
  PHASE_MESSAGES,
  ARABIC_MESSAGES,
  TRANSITIONS,
  TERMINAL_PHASES,
};
