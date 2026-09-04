/*
 * Run with the Firestore emulator after installing firebase/rules-unit-testing
 * as a development dependency in the functions workspace. package.json is
 * intentionally not changed by this security-rules change.
 */
const fs = require("fs");
const path = require("path");
const assert = require("node:assert/strict");
const test = require("node:test");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { serverTimestamp } = require("firebase/firestore");

let env;
const rules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
const db = (uid, claims) => env.authenticatedContext(uid, claims).firestore();

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-pubget-security",
    firestore: { host: "127.0.0.1", port: 8080, rules },
  });
});
test.beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("users/alice").set({
      username: "Alice", coinsBalance: 10, subscriptionType: "free",
      customMaxMembersLimit: 0,
    });
    await admin.doc("users/bob").set({
      username: "Bob", coinsBalance: 10, subscriptionType: "free",
      customMaxMembersLimit: 0,
    });
    await admin.doc("users/charlie").set({ username: "Charlie", coinsBalance: 10 });
    await admin.doc("public_profiles/alice").set({
      uid: "alice", id: "alice", username: "Alice", avatarUrl: "",
      isPremium: false, totalRespect: 2,
    });
    await admin.doc("groups/g1").set({
      founderId: "alice", name: "G", membersCount: 2, maxMembers: 100,
    });
    await admin.doc("groups/g1/members/alice").set({
      userId: "alice", groupId: "g1", role: "founder", displayName: "Alice",
      realUserName: "Alice", realUserImageUrl: "", isPremium: false,
    });
    await admin.doc("groups/g1/members/bob").set({
      userId: "bob", groupId: "g1", role: "member", displayName: "Bob",
      realUserName: "Bob", realUserImageUrl: "", isPremium: false,
    });
    await admin.doc("mafia_games/m1").set({
      groupId: "g1", status: "night", currentPhase: "night", currentNight: 1,
      currentDay: 1, playersCount: 2, maxPlayers: 8,
    });
    await admin.doc("mafia_games/m1/players/alice").set({
      userId: "alice", username: "Alice", avatar: "", isAlive: true, hasLeft: false,
      canVote: true, canSpeak: true,
    });
    await admin.doc("mafia_games/m1/players/bob").set({
      userId: "bob", username: "Bob", avatar: "", isAlive: true, hasLeft: false,
      canVote: true, canSpeak: true,
    });
    await admin.doc("mafia_games/m1/players/alice/private/data").set({ role: "mafia" });
    await admin.doc("mafia_games/m1/players/bob/private/data").set({ role: "citizen" });
    await admin.doc("privateChats/c1").set({
      userA: "alice", userB: "bob", participantIds: ["alice", "bob"],
      lastMessageAt: new Date(), lastMessageText: "", lastMessageSenderId: "",
    });
    await admin.doc("events/e1").set({
      creatorId: "alice", groupId: "g1", type: "poll", title: "Vote",
      status: "active", participantsCount: 1, responsesCount: 0,
    });
    await admin.doc("events/e-draft").set({
      creatorId: "alice", groupId: "g1", type: "poll", title: "Draft",
      status: "draft",
    });
    await admin.doc("events/e1/responses/bob").set({
      userId: "bob", eventId: "e1", responseData: { optionId: "opt-1" },
    });
    await admin.doc("games/game1").set({
      creatorId: "alice", groupId: "g1", type: "guessCharacter", title: "Guess",
      status: "waiting", participantsCount: 1,
    });
    await admin.doc("games/game-draft").set({
      creatorId: "alice", groupId: "g1", type: "guessCharacter", title: "Draft",
      status: "draft",
    });
    await admin.doc("games/game1/participants/alice").set({
      userId: "alice", gameId: "game1", status: "active",
    });
    await admin.doc("games/game1/participants/bob").set({
      userId: "bob", gameId: "game1", status: "active", score: 1,
    });
    await admin.doc("games/game1/actions/a1").set({
      playerId: "bob", actionType: "guess", payload: { value: "Luffy" },
    });
    await admin.doc("games/game1/secret/round").set({
      roundNumber: 1, correctId: "luffy", correctName: "Monkey D. Luffy",
    });
    await admin.doc("games/game1/private/alice").set({
      note: "alice-only",
    });
    await admin.doc("user_achievements/alice/items/first_game_win").set({
      achievementId: "first_game_win", title: "First Victory",
    });
    await admin.doc("game_history/game1").set({
      gameId: "game1", type: "guessCharacter", result: { winnerIds: ["alice"] },
    });
    await admin.doc("fanWorks/fw-public").set({
      creatorId: "alice", type: "drawing", title: "Public drawing",
      status: "published", moderationStatus: "approved", visibility: "public",
      likesCount: 2, bookmarksCount: 1, reportsCount: 0, commentsCount: 1,
    });
    await admin.doc("fanWorks/fw-draft").set({
      creatorId: "alice", type: "story", title: "Secret draft",
      status: "draft", moderationStatus: "pending", visibility: "unpublished",
    });
    await admin.doc("fanWorks/fw-rejected").set({
      creatorId: "alice", type: "other", title: "Rejected",
      status: "published", moderationStatus: "rejected", visibility: "public",
    });
    await admin.doc("fanWorks/fw-public/likes/bob").set({
      userId: "bob", createdAt: new Date(),
    });
    await admin.doc("fanWorks/fw-public/reports/fw-public_bob").set({
      reporterId: "bob", reason: "spam", details: "", createdAt: new Date(),
    });
    await admin.doc("fanWorks/fw-public/comments/c1").set({
      authorId: "bob", text: "nice", likesCount: 0,
    });
  });
});
test.after(() => env.cleanup());
test.afterEach(() => env.clearFirestore());

test("profile owner can change display data but not coins", async () => {
  await assertSucceeds(db("alice").doc("users/alice").update({ bio: "hello" }));
  await assertFails(db("alice").doc("users/alice").update({ coinsBalance: 999999 }));
  await assertFails(db("mallory").doc("users/alice").update({ bio: "pwned" }));
});
test("private users and server-owned public profiles are separated", async () => {
  await assertSucceeds(db("alice").doc("users/alice").get());
  await assertFails(db("bob").doc("users/alice").get());
  await assertFails(db("alice").collection("users").get());

  const publicDoc = await assertSucceeds(
    db("bob").doc("public_profiles/alice").get(),
  );
  const publicData = publicDoc.data();
  assert.equal(publicData.username, "Alice");
  for (const sensitive of [
    "email", "fcmToken", "coinsBalance", "invitedBy", "hasClaimedReferral",
    "isBanned", "premiumSince", "premiumExpiresAt", "autoRenewPremium",
    "customMaxMembersLimit", "customMaxJoinedGroupsLimit",
    "customMaxCreatedGroupsLimit",
  ]) {
    assert.equal(publicData[sensitive], undefined);
  }
  await assertFails(db("alice").doc("public_profiles/alice").update({
    username: "Forged",
  }));
  await assertFails(db("alice").doc("public_profiles/new").set({
    uid: "new", username: "Forged",
  }));
  await assertFails(db("alice").doc("public_profiles/alice").delete());
});
test("group messages are readable by members but writable only by callables", async () => {
  const canonical = {
    senderId: "bob", senderName: "Bob", senderAvatar: "", senderIsPremium: false,
    senderRole: "member", type: "text", text: "hi", createdAt: serverTimestamp(),
    isRead: false, isDelivered: false, isEdited: false,
  };
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("groups/g1/messages/a").set(canonical);
  });
  await assertSucceeds(db("bob").doc("groups/g1/messages/a").get());
  await assertFails(db("mallory").doc("groups/g1/messages/a").get());
  await assertFails(db("bob").doc("groups/g1/messages/new").set(canonical));
  await assertFails(db("mallory").doc("groups/g1/messages/b").set(canonical));
  await assertFails(db("bob").doc("groups/g1/messages/c").set({ ...canonical, senderId: "alice" }));
  await assertFails(db("bob").doc("groups/g1/messages/name").set({ ...canonical, senderName: "Alice" }));
  await assertFails(db("bob").doc("groups/g1/messages/avatar").set({ ...canonical, senderAvatar: "forged" }));
  await assertFails(db("bob").doc("groups/g1/messages/role").set({ ...canonical, senderRole: "founder" }));
  await assertFails(db("bob").doc("groups/g1/messages/premium").set({ ...canonical, senderIsPremium: true }));
  await assertFails(db("bob").doc("groups/g1/messages/game").set({ ...canonical, type: "gameEvent" }));
  await assertFails(db("bob").doc("groups/g1/messages/invite").set({ ...canonical, type: "gameInvite" }));
  await assertFails(db("bob").doc("groups/g1/messages/reply").set({
    ...canonical, replyToId: "missing", replyText: "forged attribution",
  }));
  await assertFails(db("bob").doc("groups/g1/messages/media").set({
    ...canonical, type: "media", text: null, mediaUrl: "https://example.test/a.png",
    mediaType: "image",
  }));
});
test("a stale public projection is denied immediately after privacy changes", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/alice").update({
      profileVisibility: "private",
    });
  });
  await assertFails(db("bob").doc("public_profiles/alice").get());
  await assertFails(
    db("alice").doc("users/alice").update({ profileVisibility: "public" }),
  );
});
test("mafia lifecycle and private roles are not client writable", async () => {
  await assertFails(db("alice").doc("mafia_games/m1").update({ status: "finished", winner: "mafia" }));
  await assertFails(db("alice").doc("mafia_games/m1/players/alice/private/data").set({ role: "mafia" }));
});
test("private interaction data is scoped to its owner", async () => {
  await assertSucceeds(db("alice").doc("user_seen/alice/seen_edits/e1").set({ seenAt: new Date() }));
  await assertFails(db("bob").doc("user_seen/alice/seen_edits/e1").get());
  await assertFails(db("bob").doc("user_interactions/alice/interactions/i1").set({ userId: "alice" }));
});
test("private-chat documents are readable by participants and not client-writable", async () => {
  await assertSucceeds(db("bob").doc("privateChats/c1").get());
  await assertFails(db("mallory").doc("privateChats/c1").get());
  await assertFails(db("alice").doc("privateChats/c1").update({ userB: "mallory" }));
  await assertFails(db("bob").doc("privateChats/c1").update({
    lastReadUserB: new Date(),
  }));
  await assertFails(db("alice").doc("privateChats/forged").set({
    userA: "alice", userB: "mallory", participantIds: ["alice", "mallory"],
    createdAt: new Date(),
  }));
});
test("private messages are readable by participants but writable only by callables", async () => {
  const message = {
    senderId: "alice", senderName: "Alice", senderAvatar: "", senderRole: "",
    type: "text", text: "hello", createdAt: new Date(),
    recipientCount: 1, deliveredCount: 0, readCount: 0,
  };
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("privateChats/c1/messages/m1").set(message);
  });
  await assertSucceeds(db("alice").doc("privateChats/c1/messages/m1").get());
  await assertSucceeds(db("bob").doc("privateChats/c1/messages/m1").get());
  await assertFails(db("mallory").doc("privateChats/c1/messages/m1").get());
  await assertFails(db("alice").doc("privateChats/c1/messages/m2").set(message));
  await assertFails(db("bob").doc("privateChats/c1/messages/m1").update({
    deliveredCount: 1,
  }));
  await assertFails(db("alice").doc("privateChats/c1/messages/m1").delete());
});
test("events are readable by group members and never client-writable", async () => {
  await assertSucceeds(db("bob").doc("events/e1").get());
  await assertFails(db("charlie").doc("events/e1").get());
  await assertSucceeds(db("alice").doc("events/e-draft").get());
  await assertFails(db("bob").doc("events/e-draft").get());
  await assertFails(db("alice").doc("events/e1").update({ status: "ended" }));
  await assertFails(db("alice").doc("events/forged").set({
    creatorId: "alice", groupId: "g1", type: "poll", status: "active",
  }));
  await assertSucceeds(db("bob").doc("events/e1/responses/bob").get());
  await assertFails(db("alice").doc("events/e1/responses/bob").get());
  await assertFails(db("bob").doc("events/e1/responses/bob").update({
    responseData: { optionId: "opt-2" },
  }));
});
test("games are readable by group members and never client-writable", async () => {
  await assertSucceeds(db("bob").doc("games/game1").get());
  await assertFails(db("charlie").doc("games/game1").get());
  await assertSucceeds(db("alice").doc("games/game-draft").get());
  await assertFails(db("bob").doc("games/game-draft").get());
  await assertFails(db("alice").doc("games/game1").update({ status: "completed" }));
  await assertFails(db("bob").doc("games/game1/participants/bob").update({ score: 999999 }));
  await assertFails(db("alice").doc("games/game1/participants/bob").update({ status: "left" }));
  await assertFails(db("bob").doc("games/game1/actions/a1").set({
    playerId: "alice", actionType: "guess", payload: { value: "spoof" },
  }));
  await assertFails(db("alice").doc("games/forged").set({
    creatorId: "alice", groupId: "g1", type: "guessCharacter", status: "active",
  }));
  await assertSucceeds(db("bob").doc("games/game1/participants/alice").get());
  await assertFails(db("alice").doc("games/game1/secret/round").get());
  await assertFails(db("bob").doc("games/game1/secret/round").get());
  await assertFails(db("alice").doc("games/game1/secret/round").set({ correctId: "spoof" }));
  await assertSucceeds(db("alice").doc("games/game1/private/alice").get());
  await assertFails(db("bob").doc("games/game1/private/alice").get());
  await assertFails(db("alice").doc("games/game1/private/alice").set({ score: 99 }));
  await assertFails(db("alice").doc("games/game1").update({
    result: { winnerIds: ["alice"], scores: { alice: 99 } },
  }));
  await assertSucceeds(db("alice").doc("user_achievements/alice/items/first_game_win").get());
  await assertFails(db("bob").doc("user_achievements/alice/items/first_game_win").get());
  await assertFails(db("alice").doc("user_achievements/alice/items/forged").set({
    achievementId: "forged",
  }));
  await assertFails(db("alice").doc("game_history/game1").set({ winner: "alice" }));
});
test("group capacity is fixed at trusted entitlement on create and never client-updatable", async () => {
  const group = {
    founderId: "alice", name: "Capacity", description: "", slogan: "", imageUrl: "",
    type: "public", animeName: null, animeId: null, franchiseIds: [], maxMembers: 100,
    createdAt: serverTimestamp(), chatBackgroundUrl: null, membersCount: 1,
    isPromoted: false, promotionExpiresAt: null, lastMessageAt: null,
    lastMessageText: null, activeGameId: null, gameStatus: null, hasRunningGame: false,
  };
  await assertSucceeds(db("alice").doc("groups/capacity-free").set(group));
  await assertFails(db("alice").doc("groups/capacity-invalid").set({ ...group, maxMembers: 101 }));
  await assertFails(db("alice").doc("groups/g1").update({ maxMembers: 999 }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/alice").update({ customMaxMembersLimit: 350 });
  });
  await assertSucceeds(db("alice").doc("groups/capacity-custom").set({ ...group, maxMembers: 350 }));
  await assertFails(db("alice").doc("groups/capacity-wrong-custom").set({ ...group, maxMembers: 100 }));
});
test("stickers and social authority cannot be forged", async () => {
  await assertSucceeds(db("alice").doc("users/alice/stickers/s1").set({
    creatorId: "alice", imageUrl: "https://example.test/s.png", createdAt: new Date(),
  }));
  await assertFails(db("alice").doc("users/alice/stickers/s2").set({
    creatorId: "bob", imageUrl: "https://example.test/s.png", createdAt: new Date(),
  }));
  await assertFails(db("alice").doc("respects/alice_bob").set({
    fromUserId: "alice", toUserId: "bob", value: 5, createdAt: new Date(),
  }));
  await assertFails(db("alice").doc("fans/not-canonical").set({
    fanUserId: "alice", targetUserId: "bob", createdAt: new Date(),
  }));
  await assertFails(db("alice").doc("friendships/alice_bob").set({
    userA: "alice", userB: "bob", userIds: ["alice", "bob"],
    status: "pending", requestedBy: "alice", createdAt: new Date(),
  }));
});
test("friendship reads are limited to relationship participants", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("friendships/alice_bob").set({
      userA: "alice", userB: "bob", userIds: ["alice", "bob"],
      status: "pending", requestedBy: "alice", createdAt: new Date(),
    });
  });
  await assertSucceeds(db("alice").doc("friendships/alice_bob").get());
  await assertSucceeds(db("bob").doc("friendships/alice_bob").get());
  await assertFails(db("charlie").doc("friendships/alice_bob").get());
});
test("respect details are visible only to either participant", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("respects/server-owned-id").set({
      fromUserId: "alice", toUserId: "bob", value: 6,
      createdAt: new Date(), updatedAt: new Date(),
    });
  });
  await assertSucceeds(db("alice").doc("respects/server-owned-id").get());
  await assertSucceeds(db("bob").doc("respects/server-owned-id").get());
  await assertFails(db("charlie").doc("respects/server-owned-id").get());
});
test("legacy fan identity documents are not client-readable", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("fans/alice_bob").set({
      fanUserId: "alice", targetUserId: "bob", createdAt: new Date(),
    });
  });
  await assertFails(db("alice").doc("fans/alice_bob").get());
  await assertFails(db("bob").doc("fans/alice_bob").get());
  await assertFails(db("charlie").doc("fans/alice_bob").get());
});
test("night actions are player intent only, never role or resolver state", async () => {
  await assertSucceeds(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("bob").doc("mafia_games/m1/night_actions/bob_n1").set({
    playerId: "bob", targetId: "alice", nightNumber: 1, submittedAt: new Date(), role: "mafia",
  }));
});
test("members atomically create a waiting lobby and their own default player", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("groups/g2").set({ founderId: "alice", activeGameId: null, gameStatus: null, hasRunningGame: false });
    await admin.doc("groups/g2/members/alice").set({ userId: "alice", groupId: "g2", role: "founder" });
  });
  const game = {
    groupId: "g2", createdBy: "alice", createdAt: new Date(), version: "classic",
    status: "waiting", currentPhase: "waiting", currentDay: 0, currentNight: 0,
    playersCount: 1, minPlayers: 2, maxPlayers: 8, winner: null,
    countdownEndsAt: new Date(Date.now() + 120000), phaseEndsAt: null, isLocked: false, startedAt: null,
    endedAt: null, rewardsDistributed: false, historyWritten: false,
  };
  const player = {
    userId: "alice", username: "Alice", avatar: "", isAlive: true,
    isDisconnected: false, isMuted: false, hasLeft: false, joinedAt: new Date(),
    lastSeenAt: null, coinsEarned: 0, votesReceived: 0, canSpeak: true,
    canVote: true, canUseAbility: true, revealedRole: false,
  };
  const firestore = db("alice");
  const batch = firestore.batch();
  batch.set(firestore.doc("mafia_games/g2game"), game);
  batch.set(firestore.doc("mafia_games/g2game/players/alice"), player);
  batch.update(firestore.doc("groups/g2"), {
    activeGameId: "g2game", gameStatus: "waiting", hasRunningGame: true,
  });
  await assertSucceeds(batch.commit());
  await assertFails(db("bob").doc("mafia_games/g2game/players/alice").set(player));
  // The existing marker is authoritative: even the original creator cannot
  // replace it with a second lobby in the same group.
  const second = firestore.batch();
  second.set(firestore.doc("mafia_games/g2game2"), game);
  second.set(firestore.doc("mafia_games/g2game2/players/alice"), player);
  second.update(firestore.doc("groups/g2"), {
    activeGameId: "g2game2", gameStatus: "waiting", hasRunningGame: true,
  });
  await assertFails(second.commit());
});
test("lobby bounds reject invalid player limits and expiry windows", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("groups/g3").set({ founderId: "alice", activeGameId: null, gameStatus: null, hasRunningGame: false });
    await admin.doc("groups/g3/members/alice").set({ userId: "alice", groupId: "g3", role: "founder" });
  });
  const player = {
    userId: "alice", username: "Alice", avatar: "", isAlive: true,
    isDisconnected: false, isMuted: false, hasLeft: false, joinedAt: new Date(),
    lastSeenAt: null, coinsEarned: 0, votesReceived: 0, canSpeak: true,
    canVote: true, canUseAbility: true, revealedRole: false,
  };
  const baseGame = {
    groupId: "g3", createdBy: "alice", createdAt: new Date(), version: "classic",
    status: "waiting", currentPhase: "waiting", currentDay: 0, currentNight: 0,
    playersCount: 1, minPlayers: 2, maxPlayers: 8, winner: null,
    countdownEndsAt: new Date(Date.now() + 120000), phaseEndsAt: null, isLocked: false,
    startedAt: null, endedAt: null, rewardsDistributed: false, historyWritten: false,
  };
  async function attempt(id, game) {
    const firestore = db("alice");
    const batch = firestore.batch();
    batch.set(firestore.doc(`mafia_games/${id}`), game);
    batch.set(firestore.doc(`mafia_games/${id}/players/alice`), player);
    batch.update(firestore.doc("groups/g3"), {
      activeGameId: id, gameStatus: "waiting", hasRunningGame: true,
    });
    await assertFails(batch.commit());
  }
  await attempt("bad-min", { ...baseGame, minPlayers: 1 });
  await attempt("bad-max", { ...baseGame, maxPlayers: 51 });
  await attempt("far-future", {
    ...baseGame, countdownEndsAt: new Date(Date.now() + 60 * 60 * 1000),
  });
  await attempt("stale", { ...baseGame, countdownEndsAt: new Date() });
});
test("join, leave, and heartbeat require the caller's paired player mutation", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("mafia_games/lobby").set({
      groupId: "g1", status: "waiting", currentPhase: "waiting",
      playersCount: 1, maxPlayers: 8,
    });
    await admin.doc("mafia_games/lobby/players/alice").set({ userId: "alice" });
  });
  const player = {
    userId: "bob", username: "Bob", avatar: "", isAlive: true,
    isDisconnected: false, isMuted: false, hasLeft: false, joinedAt: new Date(),
    lastSeenAt: null, coinsEarned: 0, votesReceived: 0, canSpeak: true,
    canVote: true, canUseAbility: true, revealedRole: false,
  };
  const bob = db("bob");
  let batch = bob.batch();
  batch.set(bob.doc("mafia_games/lobby/players/bob"), player);
  batch.update(bob.doc("mafia_games/lobby"), { playersCount: 2 });
  await assertSucceeds(batch.commit());
  await assertSucceeds(bob.doc("mafia_games/lobby/players/bob").update({
    lastSeenAt: new Date(), isDisconnected: false,
  }));
  await assertFails(bob.doc("mafia_games/lobby").update({ playersCount: 3 }));
  batch = bob.batch();
  batch.delete(bob.doc("mafia_games/lobby/players/bob"));
  batch.update(bob.doc("mafia_games/lobby"), { playersCount: 1 });
  await assertSucceeds(batch.commit());
});
test("votes, chat, and actions reject wrong phase, number, and targets", async () => {
  await assertFails(db("alice").doc("mafia_games/m1/votes/alice_d1").set({
    voterId: "alice", targetId: "bob", dayNumber: 1, time: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n2").set({
    playerId: "alice", targetId: "bob", nightNumber: 2, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "nobody", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/chat/c1").set({
    senderId: "alice", sender: "Alice", senderAvatar: "", text: "no night chat",
    time: new Date(), type: "player",
  }));
});
test("a living player can submit canonical vote and chat intent in its phase", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1").update({
      status: "voting", currentPhase: "voting", currentDay: 1,
    });
  });
  await assertSucceeds(db("alice").doc("mafia_games/m1/votes/alice_d1").set({
    voterId: "alice", targetId: "bob", dayNumber: 1, time: new Date(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1").update({
      status: "discussion", currentPhase: "discussion",
    });
  });
  await assertSucceeds(db("alice").doc("mafia_games/m1/chat/c1").set({
    senderId: "alice", sender: "Alice", senderAvatar: "", text: "hello",
    time: new Date(), type: "player",
  }));
});

test("mafia night and vote attacks are rejected", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1/players/bob/private/data").set({ role: "mafia" });
  });
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1/players/bob/private/data").set({ role: "citizen" });
  });
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/bob_n1").set({
    playerId: "bob", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "alice", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n0").set({
    playerId: "alice", targetId: "bob", nightNumber: 0, submittedAt: new Date(),
  }));
  await assertFails(db("mallory").doc("mafia_games/m1/night_actions/mallory_n1").set({
    playerId: "mallory", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("groups/g1/members/eve").set({
      userId: "eve", groupId: "g1", role: "member", displayName: "Eve",
      realUserName: "Eve", realUserImageUrl: "", isPremium: false,
    });
  });
  await assertFails(db("eve").doc("mafia_games/m1/night_actions/eve_n1").set({
    playerId: "eve", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertSucceeds(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n1").set({
    playerId: "alice", targetId: "bob", nightNumber: 1, submittedAt: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/night_actions/alice_n1").update({
    targetId: "alice",
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1/players/bob").update({ isAlive: false });
  });
  await assertFails(db("bob").doc("mafia_games/m1/night_actions/bob_n1").set({
    playerId: "bob", targetId: "alice", nightNumber: 1, submittedAt: new Date(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1").update({
      status: "voting", currentPhase: "voting", currentDay: 1,
      phaseEndsAt: new Date(Date.now() - 60 * 1000),
    });
    await context.firestore().doc("mafia_games/m1/players/bob").update({ isAlive: true });
  });
  await assertFails(db("alice").doc("mafia_games/m1/votes/alice_d1").set({
    voterId: "alice", targetId: "bob", dayNumber: 1, time: new Date(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("mafia_games/m1").update({ phaseEndsAt: null });
  });
  await assertFails(db("alice").doc("mafia_games/m1/votes/bob_d1").set({
    voterId: "bob", targetId: "alice", dayNumber: 1, time: new Date(),
  }));
  await assertSucceeds(db("alice").doc("mafia_games/m1/votes/alice_d1").set({
    voterId: "alice", targetId: "bob", dayNumber: 1, time: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/votes/alice_d1").set({
    voterId: "alice", targetId: "alice", dayNumber: 1, time: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1/votes/alice_d1").update({
    targetId: "alice",
  }));
  await assertFails(db("alice").doc("mafia_games/m1/votes/alice_d2").set({
    voterId: "alice", targetId: "bob", dayNumber: 2, time: new Date(),
  }));
  await assertFails(db("alice").doc("mafia_games/m1").update({
    winner: "mafia", status: "finished", currentPhase: "finished",
    phaseEndsAt: new Date(), rewardsDistributed: true,
  }));
  await assertFails(db("alice").doc("mafia_games/m1/players/alice/private/data").update({
    role: "citizen",
  }));
});

const joinRequest = (uid, characterName = null, characterKey = null) => ({
  userId: uid,
  groupId: "g1",
  role: "member",
  displayName: uid,
  characterName,
  characterKey,
  characterImageUrl: null,
  characterReason: null,
  realUserName: uid,
  realUserImageUrl: null,
  invitedByUserId: null,
  inviterDisplayName: null,
  joinedAt: new Date(),
  lastReadAt: null,
  isManualRole: false,
  isPremium: false,
  inviteCount: 0,
  requestId: `request-${uid}`,
});

const notification = (type, senderId) => ({
  title: "Canonical group event",
  body: "A matching group membership event occurred.",
  type,
  refId: "g1",
  senderId,
  commentId: null,
  createdAt: new Date(),
  isRead: false,
});

async function seedRequest(uid, characterName = null, characterKey = null) {
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc(`groups/g1/requests/${uid}`).set(
      joinRequest(uid, characterName, characterKey),
    );
  });
}

test("join requests and their notifications are server-authoritative", async () => {
  const charlie = db("charlie");
  const batch = charlie.batch();
  batch.set(charlie.doc("groups/g1/requests/charlie"), joinRequest("charlie"));
  batch.set(
    charlie.doc("users/alice/notifications/join_request_g1_request-charlie"),
    notification("join_request", "charlie"),
  );
  await assertFails(batch.commit());
  await assertFails(
    db("charlie").doc("users/bob/notifications/join_request_g1_request-charlie")
      .set(notification("join_request", "charlie")),
  );
});

test("join acceptance is server-authoritative", async () => {
  await seedRequest("charlie", "Hero One", "heroone");
  const alice = db("alice");
  const batch = alice.batch();
  batch.set(alice.doc("groups/g1/members/charlie"), joinRequest(
    "charlie", "Hero One", "heroone",
  ));
  batch.delete(alice.doc("groups/g1/requests/charlie"));
  batch.set(alice.doc("groups/g1/characters/heroone"), {
    userId: "charlie",
    characterName: "Hero One",
    imageUrl: null,
    reservedAt: new Date(),
  });
  batch.update(alice.doc("groups/g1"), {
    membersCount: 3,
    membershipMutation: {
      operation: "accept", userId: "charlie", actorId: "alice",
    },
  });
  batch.set(
    alice.doc("users/charlie/notifications/request_accepted_g1_request-charlie"),
    notification("request_accepted", "alice"),
  );
  await assertFails(batch.commit());
});

test("join rejection is server-authoritative", async () => {
  await seedRequest("charlie");
  const alice = db("alice");
  const batch = alice.batch();
  batch.delete(alice.doc("groups/g1/requests/charlie"));
  batch.set(
    alice.doc("users/charlie/notifications/request_rejected_g1_request-charlie"),
    notification("request_rejected", "alice"),
  );
  await assertFails(batch.commit());
});

test("member can leave as self and release only own reservation", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("groups/g1/members/bob").update({
      characterName: "Bob Hero", characterKey: "bobhero",
    });
    await admin.doc("groups/g1/characters/bobhero").set({
      userId: "bob", characterName: "Bob Hero", imageUrl: null, reservedAt: new Date(),
    });
  });
  const bob = db("bob");
  const batch = bob.batch();
  batch.delete(bob.doc("groups/g1/members/bob"));
  batch.delete(bob.doc("groups/g1/characters/bobhero"));
  batch.update(bob.doc("groups/g1"), {
    membersCount: 1,
    membershipMutation: { operation: "remove", userId: "bob", actorId: "bob" },
  });
  await assertSucceeds(batch.commit());
});

test("moderator can kick a non-founder with the exact counter mutation", async () => {
  const alice = db("alice");
  const batch = alice.batch();
  batch.delete(alice.doc("groups/g1/members/bob"));
  batch.update(alice.doc("groups/g1"), {
    membersCount: 1,
    membershipMutation: { operation: "remove", userId: "bob", actorId: "alice" },
  });
  await assertSucceeds(batch.commit());
});

test("membership attacks cannot forge counters, roles, removals, or reservations", async () => {
  await seedRequest("charlie");
  await assertFails(db("alice").doc("groups/g1").update({ membersCount: 3 }));
  await assertFails(db("charlie").doc("groups/g1/members/charlie").set(
    { ...joinRequest("charlie"), role: "founder" },
  ));

  const bob = db("bob");
  let batch = bob.batch();
  batch.delete(bob.doc("groups/g1/members/alice"));
  batch.update(bob.doc("groups/g1"), {
    membersCount: 1,
    membershipMutation: { operation: "remove", userId: "alice", actorId: "bob" },
  });
  await assertFails(batch.commit());

  batch = bob.batch();
  batch.delete(bob.doc("groups/g1/members/alice"));
  batch.update(bob.doc("groups/g1"), {
    membersCount: 1,
    membershipMutation: { operation: "remove", userId: "bob", actorId: "bob" },
  });
  await assertFails(batch.commit());

  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("groups/g1/characters/alicehero").set({
      userId: "alice", characterName: "Alice Hero", reservedAt: new Date(),
    });
  });
  await assertFails(db("bob").doc("groups/g1/characters/alicehero").delete());
});

test("clients can read only their own server-owned notifications", async () => {
  await assertFails(
    db("charlie").doc("users/bob/notifications/join_request_g1_request-charlie")
      .set(notification("join_request", "charlie")),
  );
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/bob/notifications/n1").set(
      notification("request_accepted", "alice"),
    );
  });
  await assertSucceeds(db("bob").doc("users/bob/notifications/n1").get());
  await assertFails(db("alice").doc("users/bob/notifications/n1").get());
  await assertFails(db("bob").doc("users/bob/notifications/n1").update({ isRead: true }));
  await assertFails(db("bob").doc("users/bob/notifications/n1").update({ body: "forged" }));
  await assertFails(db("alice").doc("users/bob/notifications/n1").delete());
  await assertFails(db("bob").doc("users/bob/notifications/n1").delete());
});

test("clients cannot delete a group root and orphan members grant no access", async () => {
  await assertFails(db("alice").doc("groups/g1").delete());
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("groups/orphan/members/bob").set({
      userId: "bob", groupId: "orphan", role: "founder",
    });
  });
  await assertFails(db("bob").doc("groups/orphan/members/bob").get());
  await assertFails(db("bob").doc("groups/orphan/messages/m1").set({
    senderId: "bob", type: "text", text: "orphan write",
  }));
  await assertFails(db("bob").doc("groups/orphan/members/bob").update({
    lastReadAt: new Date(),
  }));
});

test("a server deletion marker closes all client group access during cleanup", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("groups/g1").update({ deletionPending: true });
    await admin.doc("groups/g1/messages/bob-message").set({
      senderId: "bob", type: "text", text: "cleanup must block this",
    });
  });
  await assertFails(db("bob").doc("groups/g1").get());
  await assertFails(db("bob").doc("groups/g1/members/bob").get());
  await assertFails(db("bob").doc("groups/g1/messages/bob-message").update({
    text: "a late write",
  }));
  await assertFails(db("bob").doc("groups/g1/messages/bob-message").delete());
});

test("group chat previews and aggregate receipts are server-authoritative", async () => {
  await assertSucceeds(db("bob").doc("groups/g1").update({
    lastMessageAt: new Date(), lastMessageText: "A safe preview",
  }));
  await assertFails(db("bob").doc("groups/g1").update({
    lastMessageAt: new Date(), lastMessageText: "safe", founderId: "bob",
  }));
  await assertFails(db("bob").doc("groups/g1").update({
    lastMessageAt: new Date(), lastMessageText: "x".repeat(81),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("groups/g1/messages/receipt").set({
      senderId: "alice", type: "text", text: "hello", isDelivered: false, isRead: false,
    });
  });
  await assertFails(db("bob").doc("groups/g1/messages/receipt").update({
    deliveredBy: { bob: true }, readBy: { bob: true },
    deliveredCount: 1, readCount: 1,
  }));
  await assertFails(db("bob").doc("groups/g1/messages/receipt").update({
    isRead: false,
  }));
  await assertFails(db("bob").doc("groups/g1/messages/receipt").update({
    senderId: "bob",
  }));
});

test("FCM tokens are writable only through server callables", async () => {
  await assertFails(db("alice").doc("users/alice").update({
    fcmToken: "token-123", tokenUpdatedAt: new Date(),
  }));
  await assertFails(db("alice").doc("users/alice").update({
    fcmToken: require("firebase/firestore").deleteField(),
    tokenUpdatedAt: new Date(),
  }));
  await assertFails(db("alice").doc("users/alice").update({
    fcmToken: "",
  }));
  await assertFails(db("bob").doc("users/alice").update({
    fcmToken: "token-456", tokenUpdatedAt: new Date(),
  }));
  await assertFails(db("alice").doc("users/alice").update({
    fcmToken: "token-456", coinsBalance: 99,
  }));
  await assertFails(db("alice").doc("users/alice/fcmTokens/t1").set({
    uid: "alice", token: "token-123", platform: "web", updatedAt: new Date(),
  }));
});

test("fan works are owner-or-public readable and never client-writable", async () => {
  await assertSucceeds(db("bob").doc("fanWorks/fw-public").get());
  await assertSucceeds(db("alice").doc("fanWorks/fw-draft").get());
  await assertFails(db("bob").doc("fanWorks/fw-draft").get());
  await assertFails(db("bob").doc("fanWorks/fw-rejected").get());
  await assertSucceeds(db("alice").doc("fanWorks/fw-rejected").get());
  await assertFails(db("alice").doc("fanWorks/fw-public").update({
    likesCount: 99, creatorId: "bob", moderationStatus: "approved",
  }));
  await assertFails(db("alice").doc("fanWorks/forged").set({
    creatorId: "alice", status: "published", moderationStatus: "approved",
  }));
  await assertFails(db("bob").doc("fanWorks/fw-public").delete());
  await assertSucceeds(db("bob").doc("fanWorks/fw-public/likes/bob").get());
  await assertFails(db("alice").doc("fanWorks/fw-public/likes/bob").get());
  await assertFails(db("bob").doc("fanWorks/fw-public/likes/bob").set({
    userId: "bob",
  }));
  await assertFails(db("mallory").doc("fanWorks/fw-public/reports/fw-public_bob").set({
    reporterId: "bob", reason: "spam",
  }));
  await assertSucceeds(db("bob").doc("fanWorks/fw-public/reports/fw-public_bob").get());
});

test("clients cannot mutate economy, catalog, inventory, or premium", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("storeCatalog/frame_sakura").set({
      id: "frame_sakura", price: 80, availability: "active",
    });
    await admin.doc("economyTransactions/tx1").set({
      transactionId: "tx1", userId: "alice", amount: 10, type: "earn_event",
    });
    await admin.doc("users/alice/inventory/frame_sakura").set({
      itemId: "frame_sakura", type: "frame",
    });
    await admin.doc("users/alice/transactions/tx1").set({
      amount: 10, type: "earn_event",
    });
    await admin.doc("users/alice").update({
      subscriptionType: "free", premiumExpiresAt: new Date(Date.now() + 86400000),
    });
  });
  await assertSucceeds(db("alice").doc("storeCatalog/frame_sakura").get());
  await assertFails(db("alice").doc("storeCatalog/frame_sakura").update({ price: 1 }));
  await assertFails(db("alice").doc("storeCatalog/hack").set({ price: 1 }));
  await assertSucceeds(db("alice").doc("economyTransactions/tx1").get());
  await assertFails(db("bob").doc("economyTransactions/tx1").get());
  await assertFails(db("alice").doc("economyTransactions/tx1").update({ amount: 999 }));
  await assertFails(db("alice").doc("economyTransactions/forged").set({
    userId: "alice", amount: 500, type: "earn_event",
  }));
  await assertFails(db("alice").doc("economyTransactions/tx1").delete());
  await assertSucceeds(db("alice").doc("users/alice/inventory/frame_sakura").get());
  await assertFails(db("bob").doc("users/alice/inventory/frame_sakura").get());
  await assertFails(db("alice").doc("users/alice/inventory/badge_pioneer").set({
    itemId: "badge_pioneer",
  }));
  await assertFails(db("alice").doc("users/alice/inventory/frame_sakura").delete());
  await assertFails(db("alice").doc("users/alice/transactions/tx1").update({ amount: 99 }));
  await assertFails(db("alice").doc("users/alice/transactions/new").set({ amount: 10 }));
  await assertFails(db("alice").doc("users/alice").update({ subscriptionType: "premium" }));
  await assertFails(db("alice").doc("users/alice").update({
    premiumExpiresAt: serverTimestamp(),
  }));
  await assertFails(db("alice").doc("users/alice").update({ equippedFrameId: "frame_sakura" }));
  await assertFails(db("alice").doc("users/bob").update({ coinsBalance: 0 }));
  await assertFails(db("alice").doc("users/alice/economyRate/purchase").set({ count: 0 }));
});

test("clients cannot write anime lists, ranking scores, or edit metrics", async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("users/alice/anime_lists/21").set({
      animeId: "21", userId: "alice", status: "watching",
    });
    await admin.doc("edits/e1").set({
      creatorId: "alice", status: "published", viewsCount: 2, score: 4,
    });
    await admin.doc("groups/g1").update({ risingScore: 12, activityScore: 12 });
    await admin.doc("fanWorks/fw-public/revisions/1").set({
      version: 1, title: "old", creatorId: "alice",
    });
  });
  await assertSucceeds(db("alice").doc("users/alice/anime_lists/21").get());
  await assertFails(db("bob").doc("users/alice/anime_lists/21").get());
  await assertFails(db("alice").doc("users/alice/anime_lists/21").set({
    animeId: "21", status: "completed", rating: 10,
  }));
  await assertFails(db("alice").doc("users/alice/character_favorites/luffy").set({
    characterId: "luffy",
  }));
  await assertFails(db("alice").doc("edits/e1").update({ viewsCount: 99, score: 99 }));
  await assertFails(db("alice").doc("groups/g1").update({ risingScore: 99 }));
  await assertSucceeds(db("bob").doc("fanWorks/fw-public/revisions/1").get());
  await assertFails(db("alice").doc("fanWorks/fw-public/revisions/2").set({
    version: 2, title: "forged",
  }));
  await assertSucceeds(db("bob").doc("fanWorks/fw-public/comments/c1").get());
  await assertFails(db("bob").doc("fanWorks/fw-public/comments/c1").set({
    authorId: "bob", text: "forged",
  }));
  await assertFails(db("alice").doc("fanWorks/fw-public").update({
    commentsCount: 99,
  }));
  await assertFails(db("bob").doc("fanWorks/fw-public/ratings/bob").set({
    rating: 10,
  }));
  await assertFails(db("alice").doc("fanWorks/fw-public").update({
    ratingsAverage: 10,
  }));
});
