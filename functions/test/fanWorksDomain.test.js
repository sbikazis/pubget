"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createFanWorksDomain,
  normalizeTags,
  publishValidationError,
} = require("../src/fanWorksDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
  increment: (value) => ({ _increment: value }),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

function applyUpdate(current, data) {
  const next = clone(current);
  for (const [key, value] of Object.entries(data)) {
    if (value && value._increment != null) {
      next[key] = (next[key] || 0) + value._increment;
      continue;
    }
    next[key] = clone(value);
  }
  return next;
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  let txQueue = Promise.resolve();
  let autoInc = 0;
  const makeCollection = (base) => ({
    doc(id) {
      const resolvedId = id || `auto-${++autoInc}`;
      const resolvedPath = `${base}/${resolvedId}`;
      const ref = {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return makeCollection(`${resolvedPath}/${name}`);
        },
        async get() {
          const data = store.get(resolvedPath);
          return {
            exists: data !== undefined,
            id: resolvedId,
            ref,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        async set(data) {
          store.set(resolvedPath, clone(data));
        },
        async update(data) {
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath) || {}, data));
        },
        async create(data) {
          if (store.has(resolvedPath)) {
            const error = new Error("already-exists");
            error.code = "already-exists";
            throw error;
          }
          store.set(resolvedPath, clone(data));
        },
      };
      return ref;
    },
  });
  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      const run = txQueue.then(async () => {
        const transaction = {
          async get(ref) {
            const data = store.get(ref.path);
            return {
              exists: data !== undefined,
              ref,
              data: () => (data === undefined ? undefined : clone(data)),
            };
          },
          create(ref, data) {
            if (store.has(ref.path)) {
              const error = new Error("already-exists");
              error.code = "already-exists";
              throw error;
            }
            store.set(ref.path, clone(data));
          },
          set(ref, data) {
            store.set(ref.path, clone(data));
          },
          update(ref, data) {
            if (!store.has(ref.path)) throw new Error("not-found");
            store.set(ref.path, applyUpdate(store.get(ref.path), data));
          },
          delete(ref) {
            store.delete(ref.path);
          },
        };
        return callback(transaction);
      });
      txQueue = run.then(() => undefined, () => undefined);
      return run;
    },
  };
}

function recordingBuilder() {
  const sent = [];
  return {
    sent,
    build: async (payload) => {
      sent.push(payload);
      return { created: payload.recipientIds.length };
    },
  };
}

function createStorage(files = new Map()) {
  return {
    files,
    async metadata(path) {
      const item = files.get(path);
      return item || null;
    },
    put(path, contentType = "image/jpeg", size = 32) {
      files.set(path, { contentType, size });
    },
  };
}

function handlers({ extra = {}, storage, notificationBuilder } = {}) {
  const db = createFakeDb({
    "users/alice": { username: "Alice", avatarUrl: "" },
    "users/bob": { username: "Bob", avatarUrl: "" },
    ...extra,
  });
  return {
    db,
    storage,
    notifications: notificationBuilder || recordingBuilder(),
    domain: createFanWorksDomain({
      db,
      FieldValue,
      HttpsError: TestHttpsError,
      notificationBuilder: notificationBuilder || recordingBuilder(),
      storage: storage || createStorage(),
    }),
  };
}

function authed(uid, data = {}) {
  return { auth: { uid }, data };
}

test("normalizeTags trims, lowercases, and de-duplicates", () => {
  assert.deepEqual(
    normalizeTags(["#DemonSlayer", " demonslayer ", "Tanjiro", "x"]),
    ["demonslayer", "tanjiro"],
  );
});

test("create draft then publish drawing with media", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "drawing",
    title: "Tanjiro sketch",
    description: "A charcoal drawing of Tanjiro.",
    tags: ["#DemonSlayer", "drawing"],
    animeId: "38000",
    animeTitle: "Demon Slayer",
  }));
  const workId = created.workId;
  const ticket = await domain.startFanWorkMediaUpload(authed("alice", {
    workId,
    contentType: "image/jpeg",
  }));
  storage.put(ticket.path, "image/jpeg", 1200);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId,
    mediaId: ticket.mediaId,
    path: ticket.path,
    role: "image",
  }));
  const published = await domain.publishFanWork(authed("alice", { workId }));
  assert.equal(published.workId, workId);
  const stored = db.store.get(`fanWorks/${workId}`);
  assert.equal(stored.status, "published");
  assert.equal(stored.moderationStatus, "approved");
  assert.equal(stored.creatorId, "alice");
  assert.equal(stored.visibility, "public");
  assert.equal(stored.content.images.length, 1);
});

test("incomplete work stays a draft after failed publish", async () => {
  const { domain, db } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "Hi",
  }));
  await assert.rejects(
    () => domain.publishFanWork(authed("alice", { workId: created.workId })),
    (error) => error.code === "failed-precondition",
  );
  const stored = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(stored.status, "draft");
  assert.equal(stored.visibility, "unpublished");
});

test("duplicate publish is idempotent", async () => {
  const storage = createStorage();
  const { domain } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "A longer story title",
    body: "Once upon a time in a village far away.",
  }));
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  const again = await domain.publishFanWork(authed("alice", { workId: created.workId }));
  assert.equal(again.alreadyPublished, true);
});

test("user cannot publish another user's draft", async () => {
  const { domain } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "other",
    title: "Notes",
    description: "Enough description for other content.",
  }));
  await assert.rejects(
    () => domain.publishFanWork(authed("bob", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );
});

test("user cannot edit another user's draft or change creatorId", async () => {
  const { domain, db } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "other",
    title: "Mine",
  }));
  await assert.rejects(
    () => domain.saveFanWorkDraft(authed("bob", {
      workId: created.workId,
      type: "other",
      title: "Hijacked",
      creatorId: "bob",
    })),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.get(`fanWorks/${created.workId}`).creatorId, "alice");
});

test("failed media confirm keeps the draft", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "Page one",
  }));
  const ticket = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: created.workId,
    contentType: "image/png",
  }));
  await assert.rejects(
    () => domain.confirmFanWorkMedia(authed("alice", {
      workId: created.workId,
      mediaId: ticket.mediaId,
      path: ticket.path,
      role: "page",
    })),
    (error) => error.code === "failed-precondition",
  );
  assert.equal(db.store.get(`fanWorks/${created.workId}`).status, "draft");
});

test("unauthorized storage path is rejected", async () => {
  const { domain } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "drawing",
    title: "Sketch",
  }));
  await assert.rejects(
    () => domain.confirmFanWorkMedia(authed("alice", {
      workId: created.workId,
      mediaId: "m1",
      path: "fan_works/bob/other/file.jpg",
      role: "cover",
    })),
    (error) => error.code === "invalid-argument",
  );
});

test("likes are uid-based, idempotent, and cannot be client-forged", async () => {
  const storage = createStorage();
  const notifications = recordingBuilder();
  const { domain, db } = handlers({ storage, notificationBuilder: notifications });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "A publishable story title",
    body: "Once upon a time in a village far away.",
  }));
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  await domain.likeFanWork(authed("bob", { workId: created.workId, like: true }));
  await domain.likeFanWork(authed("bob", { workId: created.workId, like: true }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).likesCount, 1);
  await domain.likeFanWork(authed("bob", { workId: created.workId, like: false }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).likesCount, 0);
  assert.equal(notifications.sent.length, 1);
  assert.equal(notifications.sent[0].recipientIds[0], "alice");
});

test("report flags a work and cannot impersonate another reporter", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "A publishable story title",
    body: "Once upon a time in a village far away.",
  }));
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  await domain.reportFanWork(authed("bob", {
    workId: created.workId,
    reason: "spam",
    reporterId: "mallory",
  }));
  const stored = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(stored.moderationStatus, "flagged");
  assert.equal(stored.reportsCount, 1);
  const report = db.store.get(`fanWorks/${created.workId}/reports/${created.workId}_bob`);
  assert.equal(report.reporterId, "bob");
  await domain.reportFanWork(authed("bob", {
    workId: created.workId,
    reason: "spam",
  }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).reportsCount, 1);
});

test("aiCharacter is a distinct type and manga pages stay ordered", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "aiCharacter",
    title: "Original character",
    description: "A traveler with a hidden past.",
    name: "Kiro",
    background: "Raised in a mountain shrine far from home.",
  }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).type, "aiCharacter");
  const manga = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "Chapter zero",
  }));
  const first = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: manga.workId,
    contentType: "image/webp",
  }));
  storage.put(first.path, "image/webp", 40);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId: manga.workId,
    mediaId: first.mediaId,
    path: first.path,
    role: "page",
    caption: "Splash",
  }));
  const second = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: manga.workId,
    contentType: "image/webp",
  }));
  storage.put(second.path, "image/webp", 40);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId: manga.workId,
    mediaId: second.mediaId,
    path: second.path,
    role: "page",
  }));
  const pages = db.store.get(`fanWorks/${manga.workId}`).content.pages;
  assert.equal(pages[0].index, 0);
  assert.equal(pages[1].index, 1);
  assert.equal(pages[0].caption, "Splash");
});

test("other type cannot bypass required content", () => {
  const error = publishValidationError({
    type: "other",
    title: "Untitled extra",
    description: "",
    content: { body: "", images: [] },
    cover: null,
  });
  assert.equal(typeof error, "string");
});

test("archive is owner-only and delete only works for drafts", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "A publishable story title",
    body: "Once upon a time in a village far away.",
  }));
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  await assert.rejects(
    () => domain.deleteFanWorkDraft(authed("alice", { workId: created.workId })),
    (error) => error.code === "failed-precondition",
  );
  await assert.rejects(
    () => domain.archiveFanWork(authed("bob", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );
  await domain.archiveFanWork(authed("alice", { workId: created.workId }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).status, "archived");
  const draft = await domain.saveFanWorkDraft(authed("alice", {
    type: "other",
    title: "temp",
  }));
  await domain.deleteFanWorkDraft(authed("alice", { workId: draft.workId }));
  await domain.deleteFanWorkDraft(authed("alice", { workId: draft.workId }));
  assert.equal(db.store.has(`fanWorks/${draft.workId}`), false);
});

test("unauthenticated mutations fail", async () => {
  const { domain } = handlers();
  await assert.rejects(
    () => domain.saveFanWorkDraft({ data: { type: "drawing", title: "X" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("copyright metadata, published revision, and removal request are server-owned", async () => {
  const { domain, db } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "Log pose",
    description: "Nami charts a new route across the Grand Line.",
    body: "The sea stretched farther than any map she had drawn before.",
    copyright: {
      originalWorkId: "one-piece",
      sourceTitle: "One Piece",
      credit: "Fan work inspired by Eiichiro Oda",
    },
  }));
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  const published = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(published.copyright.originalWorkId, "one-piece");
  const revised = await domain.revisePublishedFanWork(authed("alice", {
    workId: created.workId,
    title: "Log pose revised",
    copyright: { originalWorkId: "one-piece", sourceTitle: "One Piece", credit: "Nami" },
  }));
  assert.equal(revised.version, (published.version || 1) + 1);
  assert.ok(db.store.get(`fanWorks/${created.workId}/revisions/${published.version || 1}`));
  await domain.requestFanWorkRemoval(authed("bob", {
    workId: created.workId,
    details: "Please take this down",
  }));
  const flagged = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(flagged.removalRequested, true);
  assert.equal(flagged.moderationStatus, "flagged");
});

test("fan work comments are server-owned with replies, likes, mentions, and cooldown", async () => {
  const notifications = recordingBuilder();
  const { domain, db } = handlers({ notificationBuilder: notifications });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "story",
    title: "A publishable story title",
    body: "Once upon a time in a village far away.",
  }));
  await assert.rejects(
    () => domain.commentFanWork(authed("bob", {
      workId: created.workId,
      text: "Too early",
    })),
    (error) => error.code === "not-found",
  );
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).commentsCount, 0);
  const first = await domain.commentFanWork(authed("bob", {
    workId: created.workId,
    text: "Loved the ending @alice",
    eventId: "evt-1",
  }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).commentsCount, 1);
  const comment = db.store.get(`fanWorks/${created.workId}/comments/${first.commentId}`);
  assert.equal(comment.authorId, "bob");
  assert.deepEqual(comment.mentions, ["alice"]);
  const replay = await domain.commentFanWork(authed("bob", {
    workId: created.workId,
    text: "Loved the ending @alice",
    eventId: "evt-1",
  }));
  assert.equal(replay.commentId, first.commentId);
  assert.equal(db.store.get(`fanWorks/${created.workId}`).commentsCount, 1);
  await assert.rejects(
    () => domain.commentFanWork(authed("bob", {
      workId: created.workId,
      text: "Another take",
    })),
    (error) => error.code === "resource-exhausted",
  );
  const reply = await domain.commentFanWork(authed("alice", {
    workId: created.workId,
    text: "Thank you",
    replyToCommentId: first.commentId,
  }));
  assert.equal(
    db.store.get(`fanWorks/${created.workId}/comments/${reply.commentId}`).replyToCommentId,
    first.commentId,
  );
  await domain.fanWorkCommentAction(authed("alice", {
    workId: created.workId,
    commentId: first.commentId,
    action: "like",
  }));
  assert.equal(
    db.store.get(`fanWorks/${created.workId}/comments/${first.commentId}`).likesCount,
    1,
  );
  await domain.fanWorkCommentAction(authed("alice", {
    workId: created.workId,
    commentId: first.commentId,
    action: "like",
  }));
  assert.equal(
    db.store.get(`fanWorks/${created.workId}/comments/${first.commentId}`).likesCount,
    1,
  );
  await assert.rejects(
    () => domain.fanWorkCommentAction(authed("alice", {
      workId: created.workId,
      commentId: first.commentId,
      action: "delete",
    })),
    (error) => error.code === "permission-denied",
  );
  await domain.fanWorkCommentAction(authed("alice", {
    workId: created.workId,
    commentId: reply.commentId,
    action: "delete",
  }));
  assert.equal(db.store.get(`fanWorks/${created.workId}`).commentsCount, 1);
  await domain.fanWorkCommentAction(authed("alice", {
    workId: created.workId,
    commentId: first.commentId,
    action: "report",
  }));
  assert.equal(
    db.store.get(`fanWorks/${created.workId}/comments/${first.commentId}`).reported,
    true,
  );
  assert.equal(
    notifications.sent.some((item) => item.type === "fan_work_commented"),
    true,
  );
});
