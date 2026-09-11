// functions/src/mafia/phaseFlow.js
//
// Mafia owns its own state machine. Uppercase values are persisted by the
// current engine; lowercase aliases keep old archived games readable.
const LOBBY_ORDER = ["WAITING", "STARTING", "ROLE_REVEAL"];
const CANONICAL_PLAY_ORDER = [
  "NIGHT", "DAY", "DISCUSSION", "VOTING", "VOTE_RESULT", "RESOLUTION",
];
// Export the legacy helper list for older pure callers; persisted games use
// CANONICAL_PLAY_ORDER through the uppercase state machine above.
const PLAY_ORDER = ["night", "day", "discussion", "voting", "execution"];
const ORDER = [...LOBBY_ORDER, ...CANONICAL_PLAY_ORDER, "GAME_OVER", "CANCELLED"];

const DURATIONS_SECONDS = {
  WAITING: 120,
  STARTING: 10,
  ROLE_REVEAL: 12,
  NIGHT: 45,
  DAY: 20,
  DISCUSSION: 90,
  VOTING: 45,
  VOTE_RESULT: 8,
  RESOLUTION: 8,
  GAME_OVER: 0,
  CANCELLED: 0,
};

const LEGACY_TO_CANONICAL = {
  waiting: "WAITING",
  starting: "STARTING",
  night: "NIGHT",
  day: "DAY",
  discussion: "DISCUSSION",
  voting: "VOTING",
  execution: "RESOLUTION",
  finished: "GAME_OVER",
  cancelled: "CANCELLED",
};

function canonicalPhase(value) {
  if (typeof value !== "string") return value;
  return LEGACY_TO_CANONICAL[value] || value;
}

function nextPhase(current) {
  if (current === "waiting") return "starting";
  if (current === "starting") return "night";
  if (current === "night") return "day";
  if (current === "day") return "discussion";
  if (current === "discussion") return "voting";
  if (current === "voting") return "execution";
  if (current === "execution") return "night";
  if (current === "finished") return "finished";
  if (current === "cancelled") return "cancelled";
  const canonical = canonicalPhase(current);
  if (canonical === "WAITING") return current === "waiting" ? "starting" : "STARTING";
  if (canonical === "STARTING") return current === "starting" ? "ROLE_REVEAL" : "ROLE_REVEAL";
  if (canonical === "ROLE_REVEAL") return "NIGHT";
  if (canonical === "GAME_OVER" || canonical === "CANCELLED") return canonical;
  const idx = CANONICAL_PLAY_ORDER.indexOf(canonical);
  if (idx === -1) return "NIGHT";
  return CANONICAL_PLAY_ORDER[(idx + 1) % CANONICAL_PLAY_ORDER.length];
}

function durationOf(phase) {
  return DURATIONS_SECONDS[canonicalPhase(phase)] || 0;
}

const PHASE_MESSAGES = {
  WAITING: "Waiting for players to join.",
  STARTING: "Roles are being assigned.",
  ROLE_REVEAL: "Your role has been assigned privately.",
  NIGHT: "Night falls. The village sleeps.",
  DAY: "Morning. The village learns what happened overnight.",
  DISCUSSION: "Discussion is open.",
  VOTING: "Voting has begun.",
  VOTE_RESULT: "The vote result is being revealed.",
  RESOLUTION: "The server is resolving the round.",
  GAME_OVER: "The Mafia game is over.",
  CANCELLED: "The Mafia game was cancelled.",
};

const ARABIC_MESSAGES = PHASE_MESSAGES;

module.exports = {
  ORDER,
  PLAY_ORDER,
  DURATIONS_SECONDS,
  canonicalPhase,
  nextPhase,
  durationOf,
  PHASE_MESSAGES,
  ARABIC_MESSAGES,
};
