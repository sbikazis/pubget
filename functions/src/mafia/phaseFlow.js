// functions/src/mafia/phaseFlow.js
//
// Play loop: night → day → discussion → voting → execution → night.
// Waiting/starting are lobby phases and never re-entered after play begins.

const LOBBY_ORDER = ["waiting", "starting"];
const PLAY_ORDER = ["night", "day", "discussion", "voting", "execution"];
const ORDER = [...LOBBY_ORDER, ...PLAY_ORDER];

const DURATIONS_SECONDS = {
  waiting: 120,
  starting: 10,
  night: 45,
  day: 20,
  discussion: 90,
  voting: 45,
  execution: 15,
};

function nextPhase(current) {
  if (current === "waiting") return "starting";
  if (current === "starting") return "night";
  if (current === "finished" || current === "cancelled") return current;
  const idx = PLAY_ORDER.indexOf(current);
  if (idx === -1) return "night";
  return PLAY_ORDER[(idx + 1) % PLAY_ORDER.length];
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
  execution: "The village carries out its decision.",
};

const ARABIC_MESSAGES = PHASE_MESSAGES;

module.exports = {
  ORDER,
  PLAY_ORDER,
  DURATIONS_SECONDS,
  nextPhase,
  durationOf,
  PHASE_MESSAGES,
  ARABIC_MESSAGES,
};
