"use strict";

const ACTIVE_STATUSES = new Set(["ROLE_REVEAL", "NIGHT", "DAY", "DISCUSSION", "VOTING", "VOTE_RESULT", "RESOLUTION"]);
const WAITING_STATUSES = new Set(["WAITING", "STARTING"]);
const MAX_GAME_ID_LENGTH = 128;

function validGameId(value) {
  return typeof value === "string" &&
    value.trim().length > 0 && value.trim().length <= MAX_GAME_ID_LENGTH;
}

function leaveTransition(status, player, playersCount, minPlayers) {
  if (!player || player.hasLeft === true) return { kind: "already-left" };
  // Master Spec 13.2: the waiting room is joinable and leavable, and dropping
  // below the minimum closes the lobby rather than starting a short game.
  if (WAITING_STATUSES.has(status)) {
    const nextCount = Math.max(0, Number.isInteger(playersCount) ? playersCount - 1 : 0);
    const floor = Number.isInteger(minPlayers) ? minPlayers : 0;
    return {
      kind: nextCount < floor ? "cancelled" : "waiting-left",
      nextCount,
    };
  }
  // Master Spec 13.8: an explicit leave during play is an elimination, with the
  // identity revealed under the same rules as any other elimination.
  if (ACTIVE_STATUSES.has(status)) return { kind: "active-left" };
  return { kind: "unsupported" };
}

function activeLeavePlayerUpdate(FieldValue) {
  return {
    hasLeft: true,
    isAlive: false,
    canVote: false,
    canSpeak: false,
    canUseAbility: false,
    isDisconnected: true,
    // Master Spec 13.7: an elimination reveals the role, so an explicit leave
    // reveals it too — it is the same elimination with a different cause. The
    // role itself still lives in the private subcollection, which no client can
    // read for another player.
    revealedRole: true,
    eliminatedBy: "leave",
    canSayLastWords: true,
    lastWordsUntil: FieldValue.serverTimestamp(),
    leftAt: FieldValue.serverTimestamp(),
  };
}

function waitingLeavePlayerUpdate(FieldValue) {
  return {
    hasLeft: true,
    isAlive: false,
    canVote: false,
    canSpeak: false,
    canUseAbility: false,
    isDisconnected: false,
    leftAt: FieldValue.serverTimestamp(),
  };
}

module.exports = {
  leaveTransition,
  validGameId,
  activeLeavePlayerUpdate,
  waitingLeavePlayerUpdate,
  ACTIVE_STATUSES,
  WAITING_STATUSES,
};
