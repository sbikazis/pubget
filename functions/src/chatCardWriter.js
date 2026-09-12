"use strict";

// Shared Admin-SDK chat-card writer. Domains emit a contract; this module
// posts the system message through groupChat.writeAdminChatCard — the same
// server-owned path Events uses. Games and Mafia must not import groupChat.

const { writeAdminChatCard } = require("./groupChat");

const CREATED_TYPES = new Set(["game_created", "GameCreated"]);
const COMPLETED_TYPES = new Set(["game_completed", "GameFinished"]);
const CANCELLED_TYPES = new Set(["game_cancelled", "GameCancelled"]);
const STARTED_TYPES = new Set(["game_started", "GameStarted"]);

function cardFromActivity(activity) {
  if (!activity || typeof activity.groupId !== "string" || !activity.groupId.trim()) {
    return null;
  }
  const gameType = activity.gameType || "";
  const isMafia = activity.domain === "mafia" || gameType === "mafia";
  const created = CREATED_TYPES.has(activity.eventType);
  const completed = COMPLETED_TYPES.has(activity.eventType);
  const cancelled = CANCELLED_TYPES.has(activity.eventType);
  const started = STARTED_TYPES.has(activity.eventType);
  if (!created && !completed && !cancelled && !started) return null;
  const title = typeof activity.metadata?.title === "string" ? activity.metadata.title : "";
  const typeName = isMafia ? "Mafia" : (title.trim() || "A game");
  const gameId = activity.gameId;
  if (typeof gameId !== "string" || !gameId.trim()) return null;

  let kind;
  let text;
  let winnerLabel = null;
  const metadata = activity.metadata || {};
  const playerCount = Number.isFinite(Number(metadata.currentPlayers))
    ? Number(metadata.currentPlayers)
    : Number.isFinite(Number(metadata.playerCount))
      ? Number(metadata.playerCount)
      : null;
  const requiredPlayers = Number.isFinite(Number(metadata.requiredPlayers))
    ? Number(metadata.requiredPlayers)
    : null;
  const maxPlayers = Number.isFinite(Number(metadata.maxPlayers))
    ? Number(metadata.maxPlayers)
    : requiredPlayers;
  if (created) {
    kind = "created";
    text = isMafia
      ? "A Mafia lobby is waiting. Tap to join."
      : `${typeName} is waiting. Tap to join.`;
  } else if (started) {
    kind = "started";
    text = `${typeName} started. Tap to open the game.`;
  } else if (cancelled) {
    kind = "cancelled";
    text = `${typeName} waiting room closed before the game started.`;
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
    // Reuse the waiting card id when a lobby expires/cancels so the
    // actionable announcement is replaced instead of leaving a stale Join
    // affordance in the chat history.
    messageId: `card-game-${gameId.trim()}-${cancelled ? "created" : kind}`,
    extra: {
      gameActivity: {
        kind,
        gameType: isMafia ? "mafia" : gameType,
        title: title || null,
        winnerLabel,
        hostName: metadata.creatorName || activity.actor || null,
        playerCount,
        requiredPlayers,
        maxPlayers,
        status: started ? "started" : cancelled ? "cancelled" : null,
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
