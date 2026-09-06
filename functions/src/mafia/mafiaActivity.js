"use strict";

function toMafiaActivity(event, game) {
  if (!event || !game) return null;
  return {
    domain: "mafia",
    gameId: game.id || event.gameId,
    gameType: "mafia",
    groupId: game.groupId || null,
    eventType: event.type,
    actor: event.actorId || "system",
    metadata: event.payload || {},
  };
}

module.exports = { toMafiaActivity };
