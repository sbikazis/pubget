"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { cardFromActivity, postFromActivity } = require("../src/chatCardWriter");
const { writeAdminChatCard, validateMessage } = require("../src/groupChat");
const { GAME_TYPE_REGISTRY } = require("../src/gamesDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(seed));
  const makeCollection = (base) => ({
    doc(id) {
      const resolvedId = id || `auto-${store.size + 1}`;
      const resolvedPath = `${base}/${resolvedId}`;
      return {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return makeCollection(`${resolvedPath}/${name}`);
        },
        async set(data) {
          store.set(resolvedPath, { ...data });
        },
        async update(data) {
          store.set(resolvedPath, { ...(store.get(resolvedPath) || {}), ...data });
        },
      };
    },
  });
  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
  };
}

test("activity contract maps created and completed cards only", () => {
  const created = cardFromActivity({
    domain: "game",
    gameId: "g1",
    gameType: "guessCharacter",
    groupId: "group-1",
    eventType: "game_created",
    metadata: { title: "Guess" },
  });
  assert.equal(created.type, "game");
  assert.match(created.text, /Tap to join/);
  assert.equal(created.extra.gameActivity.kind, "created");

  const finished = cardFromActivity({
    domain: "mafia",
    gameId: "m1",
    gameType: "mafia",
    groupId: "group-1",
    eventType: "GameFinished",
    metadata: { winner: "citizens" },
  });
  assert.equal(finished.extra.gameActivity.kind, "completed");
  assert.match(finished.text, /Town wins/);

  assert.equal(cardFromActivity({
    domain: "game",
    gameId: "g1",
    groupId: "group-1",
    eventType: "game_started",
  }), null);
});

test("admin writer posts a system-owned game card clients cannot forge", async () => {
  const db = createFakeDb({ "groups/group-1": { name: "G" } });
  const FieldValue = { serverTimestamp: () => ({ now: true }) };
  const id = await postFromActivity(db, FieldValue, {
    domain: "game",
    gameId: "game-1",
    gameType: "animeChain",
    groupId: "group-1",
    eventType: "game_created",
    metadata: { title: "Chain" },
  });
  assert.equal(id, "card-game-game-1-created");
  const card = db.store.get("groups/group-1/messages/card-game-game-1-created");
  assert.equal(card.senderId, "system");
  assert.equal(card.senderRole, "system");
  assert.equal(card.type, "game");
  assert.equal(card.mediaId, "game-1");

  assert.throws(
    () => validateMessage({ type: "game", text: "forged" }, TestHttpsError),
    (error) => error.code === "invalid-argument",
  );
  assert.equal(typeof writeAdminChatCard, "function");
});

test("registries agree: mafia is implemented but not genericCreate", () => {
  assert.equal(GAME_TYPE_REGISTRY.mafia.implemented, true);
  assert.equal(GAME_TYPE_REGISTRY.mafia.genericCreate, false);
  assert.equal(GAME_TYPE_REGISTRY.guessCharacter.implemented, true);
  assert.equal(GAME_TYPE_REGISTRY.guessCharacter.genericCreate, true);
});
