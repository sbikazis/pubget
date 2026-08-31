const ACTIVE_STATUSES = new Set(["night", "day", "discussion", "voting"]);
const MAX_GAME_ID_LENGTH = 128;

function validGameId(value) {
  return typeof value === "string" &&
    value.trim().length > 0 && value.trim().length <= MAX_GAME_ID_LENGTH;
}

function leaveTransition(status, player, playersCount, minPlayers) {
  if (!player || player.hasLeft === true) return { kind: "already-left" };
  if (status === "starting") {
    const nextCount = Math.max(0, Number.isInteger(playersCount) ? playersCount - 1 : 0);
    return {
      kind: nextCount < minPlayers ? "cancelled" : "starting-left",
      nextCount,
    };
  }
  if (ACTIVE_STATUSES.has(status)) return { kind: "active-left" };
  return { kind: "unsupported" };
}

module.exports = { leaveTransition, validGameId };