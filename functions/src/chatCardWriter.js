"use strict";

// Shared Admin-SDK chat-card writer. Domains emit a contract; this module
// posts the system message through groupChat.writeAdminChatCard — the same
// server-owned path Events uses. Games and Mafia must not import groupChat.

const { writeAdminChatCard } = require("./groupChat");

const CREATED_TYPES = new Set(["game_created", "GameCreated"]);
const COMPLETED_TYPES = new Set(["game_completed", "GameFinished"]);

function cardFromActivity(activity) {
  if (!activity || typeof activity.groupId !== "string" || !activity.groupId.trim()) {
    return null;
  }
  const gameType = activity.gameType || "";
  const isMafia = activity.domain === "mafia" || gameType === "mafia";
  const created = CREATED_TYPES.has(activity.eventType);
  const completed = COMPLETED_TYPES.has(activity.eventType);
  if (!created && !completed) return null;
  const title = typeof activity.metadata?.title === "string" ? activity.metadata.title : "";
  const typeName = isMafia ? "Mafia" : (title.trim() || "A game");
  const gameId = activity.gameId;
  if (typeof gameId !== "string" || !gameId.trim()) return null;

  let kind;
  let text;
  let winnerLabel = null;
  if (created) {
    kind = "created";
    text = isMafia
      ? "A Mafia lobby is waiting. Tap to join."
      : `${typeName} is waiting. Tap to join.`;
  } else {
    kind = "completed";
    const winner = activity.metadata && activity.metadata.winner;
    const winnerIds = activity.metadata && activity.metadata.winnerIds;
    if (isMafia) {
      winnerLabel = winner === "mafias"
        ? "Mafia wins"
        : winner === "citizens"
          ? "Town wins"
          : "No winner";
      text = `Mafia ended. ${winnerLabel}.`;
    } else if (Array.isArray(winnerIds) && winnerIds.length > 0) {
      winnerLabel = winnerIds.join(", ");
      text = `${typeName} finished. Winner: ${winnerLabel}.`;
    } else {
      text = `${typeName} finished.`;
    }
  }

  return {
    groupId: activity.groupId.trim(),
    type: "game",
    text,
    mediaId: gameId.trim(),
    messageId: `card-game-${gameId.trim()}-${kind}`,
    extra: {
      gameActivity: {
        kind,
        gameType: isMafia ? "mafia" : gameType,
        title: title || null,
        winnerLabel,
      },
    },
  };
}

async function postFromActivity(db, FieldValue, activity) {
  const card = cardFromActivity(activity);
  if (!card || !db || !FieldValue) return null;
  return writeAdminChatCard(db, FieldValue, card);
}

module.exports = {
  cardFromActivity,
  postFromActivity,
};
