"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  createFanWorksDomain,
  normalizeTags,
  publishValidationError,
  upgradeLegacyWork,
} = require("../src/fanWorksDomain");
const {
  mergeContent,
  publishValidationError: typePublishValidationError,
} = require("../src/fanWorksSchema");

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

/**
 * A fake signer. It records every capability it is asked to mint so the tests
 * can assert that no permanent token and no public ACL ever appear, which is
 * the whole point of the signed flow.
 */
function createSigner() {
  const issued = { uploads: [], writes: [], reads: [] };
  let counter = 0;
  return {
    issued,
    async signResumableUpload({ userId, workId, mediaId, mime }) {
      issued.uploads.push({ userId, workId, mediaId, mime });
      return {
        sessionUri: `https://storage.test/resumable/${++counter}`,
        path: `fan_works/${userId}/${workId}/session_${mediaId}.pdf`,
        mime,
        maxBytes: 50 * 1024 * 1024,
        expiresAt: 1_000_000,
      };
    },
    async signWriteUrl({ userId, workId, mediaId, mime }) {
      issued.writes.push({ userId, workId, mediaId, mime });
      return {
        url: `https://storage.test/write/${++counter}`,
        path: `fan_works/${userId}/${workId}/put_${mediaId}.jpg`,
        mime,
        maxBytes: 12 * 1024 * 1024,
        expiresAt: 1_000_000,
      };
    },
    async signReadUrl({ path, inline }) {
      issued.reads.push({ path, inline });
      return {
        url: `https://storage.test/read/${++counter}?X-Goog-Signature=deadbeef`,
        expiresAt: 1_000_000,
      };
    },
  };
}

function handlers({ extra = {}, storage, notificationBuilder, signer } = {}) {
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
      signer: signer || createSigner(),
    }),
  };
}

function authed(uid, data = {}) {
  return { auth: { uid }, data: withCategory(data) };
}

/**
 * A valid category per creatable type. The server now rejects a publish with no
 * category (spec §17: the category list is closed), so every draft fixture has
 * to carry one.
 */
/**
 * A placeholder for a *confirmed* media slot. Real stored media always carries
 * a server-minted `mediaId` alongside its path, and `sanitizeMedia` drops
 * anything without one, so a path-only fixture would be testing a shape the
 * system can never actually produce.
 */
const PORTRAIT = { mediaId: "m-portrait", path: "fan_works/alice/w1/portrait.jpg" };
const ARTWORK = { mediaId: "m-artwork", path: "fan_works/alice/w1/artwork.jpg" };

const CATEGORY_BY_TYPE = {
  manga: "action",
  story: "fantasy",
  drawing: "digitalArt",
  character: "demon",
};

/**
 * Stamps the right category onto any payload that names a creatable type. This
 * lives in `authed` so every draft fixture gets one without each test having to
 * remember; calls that pass `categoryId` explicitly keep it.
 */
function withCategory(payload) {
  // The callable payload key is `category`, matching `toCallableMap()`.
  if (payload.category !== undefined) return payload;
  const category = CATEGORY_BY_TYPE[payload.type];
  return category ? { ...payload, category } : payload;
}

/**
 * Creates a draft and attaches a PDF, because schema v2 requires a story or a
 * manga to have a document before it can go live. Tests that only care about
 * likes, comments, or revisions should not have to know that, so this does the
 * upload dance for them.
 */
async function draftWithPdf(uid, overrides = {}, { domain, storage, size = 4096 }) {
  const created = await domain.saveFanWorkDraft(authed(uid, {
    type: "story",
    title: "A publishable story title",
    description: "Once upon a time in a village far away.",
    ...overrides,
  }));
  const ticket = await domain.startFanWorkMediaUpload(authed(uid, {
    workId: created.workId,
    role: "document",
    contentType: "application/pdf",
  }));
  storage.put(ticket.path, "application/pdf", size);
  await domain.confirmFanWorkMedia(authed(uid, {
    workId: created.workId,
    mediaId: ticket.mediaId,
    path: ticket.path,
    role: "document",
    pageCount: 12,
  }));
  return created;
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
    role: "artwork",
    contentType: "image/jpeg",
  }));
  storage.put(ticket.path, "image/jpeg", 1200);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId,
    mediaId: ticket.mediaId,
    path: ticket.path,
    role: "artwork",
  }));
  const published = await domain.publishFanWork(authed("alice", { workId }));
  assert.equal(published.workId, workId);
  const stored = db.store.get(`fanWorks/${workId}`);
  assert.equal(stored.status, "published");
  assert.equal(stored.moderationStatus, "approved");
  assert.equal(stored.creatorId, "alice");
  assert.equal(stored.visibility, "public");
  // Schema v2 stores exactly one artwork slot, not an appendable image list.
  assert.ok(stored.content.artwork);
  assert.equal(stored.content.artwork.mediaId, ticket.mediaId);
  assert.equal(stored.schemaVersion, 2);
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
  const created = await draftWithPdf("alice", {}, { domain, storage });
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  const again = await domain.publishFanWork(authed("alice", { workId: created.workId }));
  assert.equal(again.alreadyPublished, true);
});

test("user cannot publish another user's draft", async () => {
  const { domain } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "drawing",
    title: "Notes",
    description: "Enough description for a sketch.",
  }));
  await assert.rejects(
    () => domain.publishFanWork(authed("bob", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );
});

test("user cannot edit another user's draft or change creatorId", async () => {
  const { domain, db } = handlers();
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "drawing",
    title: "Mine",
  }));
  await assert.rejects(
    () => domain.saveFanWorkDraft(authed("bob", {
      workId: created.workId,
      type: "drawing",
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
  // A manga takes a PDF, not a page image, so the role is `document`.
  const ticket = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: created.workId,
    role: "document",
    contentType: "application/pdf",
  }));
  // Nothing was written to storage, so confirming must fail.
  await assert.rejects(
    () => domain.confirmFanWorkMedia(authed("alice", {
      workId: created.workId,
      mediaId: ticket.mediaId,
      path: ticket.path,
      role: "document",
    })),
    (error) => error.code === "failed-precondition",
  );
  assert.equal(db.store.get(`fanWorks/${created.workId}`).status, "draft");
  assert.equal(db.store.get(`fanWorks/${created.workId}`).content.document, null);
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
  const created = await draftWithPdf("alice", {}, { domain, storage });
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
  const created = await draftWithPdf("alice", {}, { domain, storage });
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

test("legacy aiCharacter and worldbuilding cannot be created, but still read", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });

  // The write path refuses the legacy-only types outright.
  for (const type of ["aiCharacter", "worldbuilding", "other"]) {
    await assert.rejects(
      () => domain.saveFanWorkDraft(authed("alice", {
        type,
        title: "Should not exist",
      })),
      (error) => error.code === "invalid-argument",
    );
  }

  // A row written before the rebuild still reads as a plain character with an
  // explicit AI origin, so old data survives the taxonomy change.
  const legacyId = "legacy-ai-1";
  db.store.set(`fanWorks/${legacyId}`, {
    creatorId: "alice",
    type: "aiCharacter",
    title: "Original character",
    description: "A traveler with a hidden past.",
    status: "published",
    moderationStatus: "approved",
    visibility: "public",
    content: {
      name: "Kiro",
      personality: "Wry and watchful",
      abilities: "Reads a room instantly",
      background: "Raised in a mountain shrine far from home.",
      image: { mediaId: "m1", path: "fan_works/alice/legacy-ai-1/portrait.jpg", contentType: "image/jpeg" },
    },
    createdAt: 1,
  });
  const upgraded = upgradeLegacyWork(db.store.get(`fanWorks/${legacyId}`));
  assert.equal(upgraded.type, "character");
  assert.equal(upgraded.origin, "aiGenerated");
  assert.equal(upgraded.content.personality, "Wry and watchful");
  // The legacy `image` field becomes the v2 `portrait` slot.
  assert.ok(upgraded.content.portrait);
  assert.equal(upgraded.content.portrait.mediaId, "m1");
  assert.equal(upgraded.schemaVersion, 2);
});

test("a manga stores one PDF document and refuses a page image", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const manga = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "Chapter zero",
  }));

  // An image cannot be uploaded into the document slot.
  await assert.rejects(
    () => domain.startFanWorkMediaUpload(authed("alice", {
      workId: manga.workId,
      role: "document",
      contentType: "image/webp",
    })),
    (error) => error.code === "invalid-argument",
  );
  // And a manga cannot take a top-level artwork or portrait.
  for (const role of ["artwork", "portrait"]) {
    await assert.rejects(
      () => domain.startFanWorkMediaUpload(authed("alice", {
        workId: manga.workId,
        role,
        contentType: "image/webp",
      })),
      (error) => error.code === "invalid-argument",
    );
  }

  const ticket = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: manga.workId,
    role: "document",
    contentType: "application/pdf",
  }));
  storage.put(ticket.path, "application/pdf", 8192);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId: manga.workId,
    mediaId: ticket.mediaId,
    path: ticket.path,
    role: "document",
    pageCount: 24,
  }));
  const content = db.store.get(`fanWorks/${manga.workId}`).content;
  assert.equal(content.document.pageCount, 24);
  // No appendable page list exists in v2.
  assert.equal(content.pages, undefined);
  const published = await domain.publishFanWork(authed("alice", { workId: manga.workId }));
  assert.equal(published.workId, manga.workId);
});

test("a cast portrait attaches to the named member only", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "Chapter one",
    characters: [
      { id: "c1", name: "Kiro", bio: "The guide" },
      { id: "c2", name: "Rin", bio: "The rival" },
    ],
  }));
  // A portrait for a member that is not on the work is refused.
  await assert.rejects(
    () => domain.startFanWorkMediaUpload(authed("alice", {
      workId: created.workId,
      role: "characterPortrait",
      characterId: "nope",
      contentType: "image/png",
    })),
    (error) => error.code === "not-found",
  );
  const ticket = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: created.workId,
    role: "characterPortrait",
    characterId: "c2",
    contentType: "image/png",
  }));
  storage.put(ticket.path, "image/png", 900);
  await domain.confirmFanWorkMedia(authed("alice", {
    workId: created.workId,
    mediaId: ticket.mediaId,
    path: ticket.path,
    role: "characterPortrait",
    characterId: "c2",
  }));
  const cast = db.store.get(`fanWorks/${created.workId}`).content.characters;
  assert.equal(cast[0].image, undefined);
  assert.equal(cast[1].image.mediaId, ticket.mediaId);
  assert.deepEqual(cast.map((entry) => entry.index), [0, 1]);
});

test("a cast member with no name is dropped rather than stored blank", () => {
  const merged = mergeContent({}, {
    characters: [
      { id: "c1", name: "  ", bio: "nameless" },
      { id: "c2", name: "Kiro" },
    ],
  }, "manga");
  assert.equal(merged.characters.length, 1);
  assert.equal(merged.characters[0].name, "Kiro");
});

test("every creatable type refuses to publish without its required slot", () => {
  // A valid category is stamped in, otherwise the category rule fires first and
  // this test would pass without ever reaching the slot rules it is about.
  const base = { title: "A valid title here", description: "", cover: null };
  for (const type of ["manga", "story"]) {
    const error = publishValidationError({
      ...base,
      type,
      category: CATEGORY_BY_TYPE[type],
      content: { document: null },
    });
    assert.equal(typeof error, "string");
    assert.match(error, /PDF/);
  }
  const drawing = publishValidationError({
    ...base,
    type: "drawing",
    category: CATEGORY_BY_TYPE.drawing,
    content: { artwork: null },
  });
  assert.match(drawing, /image/);
  // A character needs both a real story and a portrait, checked in that order.
  const noStory = publishValidationError({
    ...base,
    type: "character",
    category: CATEGORY_BY_TYPE.character,
    content: { portrait: PORTRAIT, personality: "", abilities: "", specs: "" },
  });
  assert.match(noStory, /at least 40 characters/);
  const noPortrait = publishValidationError({
    ...base,
    type: "character",
    description: "A watcher of village gates who never blinks and never sleeps.",
    category: CATEGORY_BY_TYPE.character,
    content: { portrait: null, personality: "", abilities: "", specs: "" },
  });
  assert.match(noPortrait, /portrait/);
  const complete = publishValidationError({
    ...base,
    type: "character",
    description: "A watcher of village gates who never blinks and never sleeps.",
    category: CATEGORY_BY_TYPE.character,
    content: {
      portrait: PORTRAIT,
      personality: "",
      abilities: "",
      specs: "",
    },
  });
  assert.equal(complete, null);
  // The story floor is enforced on trimmed text, not on padding whitespace.
  assert.match(
    publishValidationError({
      ...base,
      type: "character",
      description: "x".repeat(39),
      category: CATEGORY_BY_TYPE.character,
      content: { portrait: PORTRAIT },
    }),
    /at least 40 characters/,
  );
  assert.equal(
    publishValidationError({
      ...base,
      type: "character",
      description: "x".repeat(40),
      category: CATEGORY_BY_TYPE.character,
      content: { portrait: PORTRAIT },
    }),
    null,
  );
  // A category from another type's closed list is refused. Through this domain
  // entry point it surfaces as "missing" rather than "invalid", because
  // `upgradeLegacyWork` normalizes an unknown id to the empty string before the
  // validator ever sees it. That is deliberate: the creator is told to pick a
  // category, which is the only action that can actually fix it.
  assert.equal(
    publishValidationError({
      ...base,
      type: "drawing",
      category: "fantasy",
      content: { artwork: ARTWORK },
    }),
    "Choose a category.",
  );
  // The same work with no category at all is refused identically.
  assert.equal(
    publishValidationError({ ...base, type: "drawing", content: { artwork: ARTWORK } }),
    "Choose a category.",
  );
  // The distinct "invalid" wording still guards the schema-level entry point,
  // which the Dart editor mirrors as `publishInvalidCategory`.
  assert.equal(
    typePublishValidationError({
      ...base,
      type: "drawing",
      category: "fantasy",
      content: { artwork: ARTWORK },
    }),
    "Choose a valid category.",
  );
  // A legacy-only type can never be published.
  assert.equal(
    typeof publishValidationError({ ...base, type: "worldbuilding", content: { lore: "x".repeat(50) } }),
    "string",
  );
});

test("archive is owner-only and delete only works for drafts", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
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
    type: "drawing",
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
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await draftWithPdf("alice", {
    title: "Log pose",
    description: "Nami charts a new route across the Grand Line.",
    copyright: {
      originalWorkId: "one-piece",
      sourceTitle: "One Piece",
      credit: "Fan work inspired by Eiichiro Oda",
    },
  }, { domain, storage });
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
  const storage = createStorage();
  const { domain, db } = handlers({ notificationBuilder: notifications, storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
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

test("fan work ratings are server-owned and upserted per user", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  await domain.rateFanWork(authed("bob", { workId: created.workId, rating: 9 }));
  let stored = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(stored.ratingsCount, 1);
  assert.equal(stored.ratingsAverage, 9);
  await domain.rateFanWork(authed("bob", { workId: created.workId, rating: 7 }));
  stored = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(stored.ratingsCount, 1);
  assert.equal(stored.ratingsAverage, 7);
  await domain.rateFanWork(authed("alice", { workId: created.workId, rating: 5 }));
  stored = db.store.get(`fanWorks/${created.workId}`);
  assert.equal(stored.ratingsCount, 2);
  assert.equal(stored.ratingsAverage, 6);
  await assert.rejects(
    () => domain.rateFanWork(authed("bob", { workId: created.workId, rating: 11 })),
    (error) => error.code === "invalid-argument",
  );
});

test("document access mints a short-lived inline read and hides drafts from others", async () => {
  const storage = createStorage();
  const signer = createSigner();
  const { domain } = handlers({ storage, signer });
  const created = await draftWithPdf("alice", {}, { domain, storage });

  // The owner can read their own draft.
  const ownerGrant = await domain.getFanWorkDocumentAccess(
    authed("alice", { workId: created.workId }),
  );
  assert.match(ownerGrant.url, /^https:\/\//);
  assert.equal(ownerGrant.pageCount, 12);
  assert.ok(ownerGrant.expiresAt);
  // Inline, never attachment: the browser must not treat it as a download.
  assert.equal(signer.issued.reads[0].inline, true);
  // No permanent token anywhere in the grant or the signed read.
  assert.ok(!ownerGrant.url.includes("token="));

  // A stranger cannot read an unpublished draft.
  await assert.rejects(
    () => domain.getFanWorkDocumentAccess(authed("bob", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );

  // Once it is live, a stranger can.
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  const publicGrant = await domain.getFanWorkDocumentAccess(
    authed("bob", { workId: created.workId }),
  );
  assert.match(publicGrant.url, /^https:\/\//);

  // A flagged work stops being readable by anyone but its owner.
  await domain.reportFanWork(authed("bob", {
    workId: created.workId,
    reason: "spam",
  }));
  await assert.rejects(
    () => domain.getFanWorkDocumentAccess(authed("carol", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );
});

test("a work with no PDF refuses a read grant rather than serving nothing", async () => {
  const storage = createStorage();
  const { domain } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "drawing",
    title: "A sketch with no PDF",
    description: "There is nothing to read here.",
  }));
  await assert.rejects(
    () => domain.getFanWorkDocumentAccess(authed("alice", { workId: created.workId })),
    (error) => error.code === "failed-precondition",
  );
});

test("reading progress only moves forward and is clamped to the page count", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
  await domain.publishFanWork(authed("alice", { workId: created.workId }));

  await domain.saveFanWorkReadingProgress(authed("bob", {
    workId: created.workId,
    page: 6,
    pageCount: 12,
  }));
  const key = `fanWorks/${created.workId}/readingProgress/bob`;
  assert.equal(db.store.get(key).page, 6);

  // Rewinding on the client must not lower the stored position.
  await domain.saveFanWorkReadingProgress(authed("bob", {
    workId: created.workId,
    page: 2,
    pageCount: 12,
  }));
  assert.equal(db.store.get(key).page, 6);

  // A page beyond the document is clamped to the last page.
  await domain.saveFanWorkReadingProgress(authed("bob", {
    workId: created.workId,
    page: 999,
    pageCount: 12,
  }));
  assert.equal(db.store.get(key).page, 11);

  // Reading progress is per user, never shared.
  await domain.saveFanWorkReadingProgress(authed("carol", {
    workId: created.workId,
    page: 1,
    pageCount: 12,
  }));
  assert.equal(db.store.get(`fanWorks/${created.workId}/readingProgress/carol`).page, 1);
  assert.equal(db.store.get(key).page, 11);
});

test("marking as read is terminal and survives a later rewind", async () => {
  const storage = createStorage();
  const { domain, db } = handlers({ storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
  await domain.publishFanWork(authed("alice", { workId: created.workId }));
  const key = `fanWorks/${created.workId}/readingProgress/bob`;

  await domain.markFanWorkAsRead(authed("bob", { workId: created.workId }));
  const marked = db.store.get(key);
  assert.equal(marked.completed, true);
  assert.equal(marked.progress, 1);
  assert.equal(marked.page, 11);

  // A rewind afterwards must not un-complete the work.
  await domain.saveFanWorkReadingProgress(authed("bob", {
    workId: created.workId,
    page: 3,
    pageCount: 12,
  }));
  assert.equal(db.store.get(key).completed, true);
});

test("reading a draft's progress is refused for a stranger", async () => {
  const storage = createStorage();
  const { domain } = handlers({ storage });
  const created = await draftWithPdf("alice", {}, { domain, storage });
  await assert.rejects(
    () => domain.saveFanWorkReadingProgress(authed("mallory", {
      workId: created.workId,
      page: 1,
    })),
    (error) => error.code === "permission-denied",
  );
  await assert.rejects(
    () => domain.markFanWorkAsRead(authed("mallory", { workId: created.workId })),
    (error) => error.code === "permission-denied",
  );
});

test("an oversized upload is rejected against the object's real size", async () => {
  const storage = createStorage();
  const { domain } = handlers({ storage });
  const created = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "A big chapter",
  }));
  const pdf = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: created.workId,
    role: "document",
    contentType: "application/pdf",
  }));
  // 60 MB, over the 50 MB ceiling.
  storage.put(pdf.path, "application/pdf", 60 * 1024 * 1024);
  await assert.rejects(
    () => domain.confirmFanWorkMedia(authed("alice", {
      workId: created.workId,
      mediaId: pdf.mediaId,
      path: pdf.path,
      role: "document",
    })),
    (error) => error.code === "invalid-argument",
  );

  const image = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: created.workId,
    role: "cover",
    contentType: "image/png",
  }));
  storage.put(image.path, "image/png", 13 * 1024 * 1024);
  await assert.rejects(
    () => domain.confirmFanWorkMedia(authed("alice", {
      workId: created.workId,
      mediaId: image.mediaId,
      path: image.path,
      role: "cover",
    })),
    (error) => error.code === "invalid-argument",
  );
});

test("the ticket ceiling is the one the role actually enforces", async () => {
  const storage = createStorage();
  const { domain } = handlers({ storage });
  const manga = await domain.saveFanWorkDraft(authed("alice", {
    type: "manga",
    title: "A chapter with pages",
  }));
  const pdf = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: manga.workId,
    role: "document",
    contentType: "application/pdf",
  }));
  assert.equal(pdf.maxBytes, 50 * 1024 * 1024);
  assert.match(pdf.uploadUrl, /^https:\/\//);
  // The session path is a PDF under the creator's own tree.
  assert.match(pdf.path, /^fan_works\/alice\//);
  assert.match(pdf.path, /\.pdf$/);

  const cover = await domain.startFanWorkMediaUpload(authed("alice", {
    workId: manga.workId,
    role: "cover",
    contentType: "image/jpeg",
  }));
  assert.equal(cover.maxBytes, 12 * 1024 * 1024);
  assert.ok(!cover.uploadUrl.includes("token="));
});
