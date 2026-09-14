"use strict";

const LOBBY_ORDER = ["WAITING", "STARTING", "ROLE_REVEAL"];
const PLAY_ORDER = [
  "NIGHT",
  "DAY",
  "DISCUSSION",
  "VOTING",
  "VOTE_RESULT",
  "RESOLUTION",
];
const TERMINAL_PHASES = new Set(["GAME_OVER", "CANCELLED"]);
const ORDER = [...LOBBY_ORDER, ...PLAY_ORDER, "GAME_OVER", "CANCELLED"];

const DURATIONS_SECONDS = {
  WAITING: 120,
  STARTING: 10,
  ROLE_REVEAL: 8,
  NIGHT: 45,
  DAY: 20,
  DISCUSSION: 90,
  VOTING: 45,
  VOTE_RESULT: 6,
  RESOLUTION: 4,
};

const TRANSITIONS = {
  WAITING: "STARTING",
  STARTING: "ROLE_REVEAL",
  ROLE_REVEAL: "NIGHT",
  NIGHT: "DAY",
  DAY: "DISCUSSION",
  DISCUSSION: "VOTING",
  VOTING: "VOTE_RESULT",
  VOTE_RESULT: "RESOLUTION",
  RESOLUTION: "NIGHT",
};

function nextPhase(current) {
  if (TERMINAL_PHASES.has(current)) return current;
  return TRANSITIONS[current] || "NIGHT";
}

function durationOf(phase) {
  return DURATIONS_SECONDS[phase] || 0;
}

const PHASE_MESSAGES = {
  WAITING: "Waiting for players to join.",
  STARTING: "Roles are being assigned.",
  ROLE_REVEAL: "Roles have been assigned privately.",
  NIGHT: "Night falls. The village sleeps.",
  DAY: "Morning. The village learns what happened overnight.",
  DISCUSSION: "Discussion is open.",
  VOTING: "Voting has begun.",
  VOTE_RESULT: "The vote result is being revealed.",
  RESOLUTION: "The village resolves the vote.",
  GAME_OVER: "The Mafia game is over.",
};

const ARABIC_MESSAGES = {
  WAITING: "بانتظار اللاعبين.",
  STARTING: "تبدأ المافيا قريبًا.",
  ROLE_REVEAL: "تم توزيع الأدوار سرًا.",
  NIGHT: "حلّ الليل. القرية نائمة.",
  DAY: "أشرقت الشمس.",
  DISCUSSION: "وقت النقاش.",
  VOTING: "بدأ التصويت السري.",
  VOTE_RESULT: "يتم إعلان نتيجة التصويت.",
  RESOLUTION: "تتم معالجة النتيجة.",
  GAME_OVER: "انتهت لعبة المافيا.",
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
