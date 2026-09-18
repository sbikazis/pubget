"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createAnimeListsDomain } = require("../src/animeListsDomain");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const FieldValue = { serverTimestamp: () => ({ _ts: true }) };

function createFakeDb() {
  const store = new Map();
  function collection(base) {
    return {
      doc(id) {
        const path = `${base}/${id}`;
        return {
          id,
          path,
          collection: (name) => collection(`${path}/${name}`),
          async get() {
            return { exists: store.has(path), id, data: () => store.get(path) };
          },
          async set(data) {
            store.set(path, { ...data });
          },
          async delete() {
            store.delete(path);
          },
        };
      },
    };
  }
  return {
    store,
    collection,
    async runTransaction(fn) {
      const tx = {
        async get(ref) {
          return {
            exists: store.has(ref.id ? `${ref.path || ""}` : false) || store.has(pathOf(ref)),
            data: () => store.get(pathOf(ref)),
          };
        },
        create(ref, data) { store.set(pathOf(ref), { ...data }); },
        set(ref, data) {
          store.set(pathOf(ref), { ...(store.get(pathOf(ref)) || {}), ...data });
        },
        update(ref, data) {
          store.set(pathOf(ref), { ...(store.get(pathOf(ref)) || {}), ...data });
        },
        delete(ref) { store.delete(pathOf(ref)); },
      };
      return fn(tx);
    },
  };
}

function pathOf(ref) {
  return ref.path || `users/unknown/anime_lists/${ref.id}`;
}

function domain() {
  const db = createFakeDb();
  let autoId = 0;
  db.collection = (basePath) => {
    function wrapCollection(path) {
      return {
        doc(docId) {
          const resolved = docId == null ? `auto${++autoId}` : docId;
          const refPath = `${path}/${resolved}`;
          return {
            id: resolved,
            path: refPath,
            collection: (child) => wrapCollection(`${refPath}/${child}`),
            async get() {
              return {
                exists: db.store.has(refPath),
                id: resolved,
                data: () => db.store.get(refPath),
              };
            },
            async set(data) {
              db.store.set(refPath, { ...(db.store.get(refPath) || {}), ...data });
            },
            async update(data) {
              db.store.set(refPath, { ...(db.store.get(refPath) || {}), ...data });
            },
            async delete() {
              db.store.delete(refPath);
            },
          };
        },
        where: () => wrapCollection(path),
        orderBy: () => wrapCollection(path),
        limit: () => wrapCollection(path),
        startAfter: () => wrapCollection(path),
        async get() {
          const depth = path.split("/").length;
          const docs = [...db.store.entries()]
            .filter(
              ([p]) =>
                p.startsWith(`${path}/`) && p.split("/").length === depth + 1,
            )
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([refPath, data]) => ({ id: refPath.split("/").pop(), data: () => data }));
          return { docs };
        },
      };
    }
    return wrapCollection(basePath);
  };
  return {
    db,
    lists: createAnimeListsDomain({ db, FieldValue, HttpsError: TestHttpsError }),
  };
}

test("anime list entries are upserted once per anime and reject forged ratings", async () => {
  const { lists, db } = domain();
  const first = await lists.setAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21", status: "watching", title: "One Piece", rating: 9 },
  });
  assert.equal(first.status, "watching");
  await lists.setAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21", status: "completed", title: "One Piece", rating: 10 },
  });
  const stored = db.store.get("users/alice/anime_lists/21");
  assert.equal(stored.status, "completed");
  assert.equal(stored.rating, 10);
  await assert.rejects(
    lists.setAnimeListEntry({
      auth: { uid: "alice" },
      data: { animeId: "21", status: "watching", rating: 99 },
    }),
    (error) => error.code === "invalid-argument",
  );
});

test("anime_stats listedCount tracks users who added the anime to a list", async () => {
  const { lists, db } = domain();
  await lists.setAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21", status: "watching", title: "One Piece" },
  });
  assert.equal(db.store.get("anime_stats/21").listedCount, 1);
  await lists.setAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21", status: "completed", title: "One Piece" },
  });
  assert.equal(db.store.get("anime_stats/21").listedCount, 1);
  await lists.setAnimeListEntry({
    auth: { uid: "bob" },
    data: { animeId: "21", status: "plan_to_watch" },
  });
  assert.equal(db.store.get("anime_stats/21").listedCount, 2);
  await lists.removeAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21" },
  });
  assert.equal(db.store.get("anime_stats/21").listedCount, 1);
  await lists.removeAnimeListEntry({
    auth: { uid: "alice" },
    data: { animeId: "21" },
  });
  assert.equal(db.store.get("anime_stats/21").listedCount, 1);
});

test("unauthenticated list writes are rejected", async () => {
  const { lists } = domain();
  await assert.rejects(
    lists.setAnimeListEntry({
      data: { animeId: "21", status: "completed" },
    }),
    (error) => error.code === "unauthenticated",
  );
});

test("character favorites are explicit and removable", async () => {
  const { lists, db } = domain();
  await lists.setCharacterFavorite({
    auth: { uid: "alice" },
    data: { characterId: "luffy", name: "Luffy", rating: 10 },
  });
  assert.equal(db.store.get("users/alice/character_favorites/luffy").rating, 10);
  await lists.setCharacterFavorite({
    auth: { uid: "alice" },
    data: { characterId: "luffy", favorite: false },
  });
  assert.equal(db.store.has("users/alice/character_favorites/luffy"), false);
});

test("character favorite listing is owner-scoped", async () => {
  const { lists } = domain();
  await lists.setCharacterFavorite({
    auth: { uid: "alice" },
    data: { characterId: "nami", name: "Nami" },
  });
  const page = await lists.getCharacterFavorites({ auth: { uid: "alice" } });
  assert.equal(page.items.some((item) => item.characterId === "nami" || item.id === "nami"), true);
});

test("character favorites maintain a server-side aggregate count", async () => {
  const { lists, db } = domain();
  await lists.setCharacterFavorite({
    auth: { uid: "alice" },
    data: { characterId: "luffy", name: "Luffy", imageUrl: "https://example.test/l.png" },
  });
  assert.equal(db.store.get("character_stats/luffy").favoritesCount, 1);
  await lists.setCharacterFavorite({
    auth: { uid: "alice" },
    data: { characterId: "luffy", favorite: false },
  });
  assert.equal(db.store.get("character_stats/luffy").favoritesCount, 0);
});

test("custom lists can be created with a seed and counted", async () => {
  const { lists, db } = domain();
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: {
      name: "Raise blood pressure",
      description: "Intense shows",
      private: false,
      animeIds: ["21", "22"],
    },
  });
  const meta = db.store.get(`users/alice/anime_custom_lists/${created.id}`);
  assert.equal(meta.name, "Raise blood pressure");
  assert.equal(meta.itemsCount, 2);
  assert.equal(
    db.store.get(`users/alice/anime_custom_lists/${created.id}/items/21`).animeId,
    "21",
  );
  assert.equal(db.store.get(`users/alice/custom_lists_meta/count`).count, 1);
});

test("custom list creation is capped and name-validated", async () => {
  const { lists } = domain();
  await assert.rejects(
    lists.createCustomAnimeList({ auth: { uid: "alice" }, data: { name: "" } }),
    (error) => error.code === "invalid-argument",
  );
  for (let i = 0; i < 30; i += 1) {
    await lists.createCustomAnimeList({
      auth: { uid: "alice" },
      data: { name: `List ${i}` },
    });
  }
  await assert.rejects(
    lists.createCustomAnimeList({
      auth: { uid: "alice" },
      data: { name: "One too many" },
    }),
    (error) => error.code === "resource-exhausted",
  );
});

test("add/remove maintain custom list item counts", async () => {
  const { lists: listsA, db } = domain();
  const lists = listsA;
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Watch later" },
  });
  await lists.addAnimeToCustomList({
    auth: { uid: "alice" },
    data: { listId: created.id, animeId: "99", title: "Code Geass" },
  });
  let meta = db.store.get(`users/alice/anime_custom_lists/${created.id}`);
  assert.equal(meta.itemsCount, 1);
  assert.equal(
    db.store.get(`users/alice/anime_custom_lists/${created.id}/items/99`).title,
    "Code Geass",
  );
  await lists.addAnimeToCustomList({
    auth: { uid: "alice" },
    data: { listId: created.id, animeId: "99" },
  });
  meta = db.store.get(`users/alice/anime_custom_lists/${created.id}`);
  assert.equal(meta.itemsCount, 1);
  await lists.removeAnimeFromCustomList({
    auth: { uid: "alice" },
    data: { listId: created.id, animeId: "99" },
  });
  meta = db.store.get(`users/alice/anime_custom_lists/${created.id}`);
  assert.equal(meta.itemsCount, 0);
  assert.equal(
    db.store.has(`users/alice/anime_custom_lists/${created.id}/items/99`),
    false,
  );
});

test("custom lists are owner-scoped and updateable", async () => {
  const { lists, db } = domain();
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Mine" },
  });
  await lists.updateCustomAnimeList({
    auth: { uid: "alice" },
    data: { listId: created.id, name: "Ours", private: true },
  });
  assert.equal(db.store.get(`users/alice/anime_custom_lists/${created.id}`).private, true);
  await assert.rejects(
    lists.updateCustomAnimeList({
      auth: { uid: "bob" },
      data: { listId: created.id, name: "Stolen" },
    }),
    (error) => error.code === "not-found",
  );
  await assert.rejects(
    lists.getCustomAnimeList({
      auth: { uid: "bob" },
      data: { userId: "alice", listId: created.id },
    }),
    (error) => error.code === "permission-denied",
  );
});

test("private custom lists are hidden from others but visible to the owner", async () => {
  const { lists } = domain();
  const visible = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Public", private: false },
  });
  await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Secret", private: true },
  });
  const theirs = await lists.getCustomAnimeLists({
    auth: { uid: "bob" },
    data: { userId: "alice" },
  });
  assert.deepEqual(
    theirs.items.map((item) => item.id).sort(),
    [visible.id],
  );
  const own = await lists.getCustomAnimeLists({ auth: { uid: "alice" } });
  assert.equal(own.items.length, 2);
});

test("deleting a custom list removes its items and decrements the count", async () => {
  const { lists, db } = domain();
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Temp", animeIds: ["1", "2"] },
  });
  await lists.deleteCustomAnimeList({
    auth: { uid: "alice" },
    data: { listId: created.id },
  });
  assert.equal(db.store.has(`users/alice/anime_custom_lists/${created.id}`), false);
  assert.equal(
    db.store.has(`users/alice/anime_custom_lists/${created.id}/items/1`),
    false,
  );
  assert.equal(db.store.get(`users/alice/custom_lists_meta/count`).count, 0);
});

test("getCustomAnimeList returns meta plus items", async () => {
  const { lists } = domain();
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Long form", animeIds: ["7"] },
  });
  const detail = await lists.getCustomAnimeList({
    auth: { uid: "alice" },
    data: { listId: created.id },
  });
  assert.equal(detail.list.name, "Long form");
  assert.equal(detail.items.some((item) => item.id === "7" || item.animeId === "7"), true);
});

test("unauthenticated custom list writes are rejected", async () => {
  const { lists } = domain();
  await assert.rejects(
    lists.createCustomAnimeList({ data: { name: "X" } }),
    (error) => error.code === "unauthenticated",
  );
  await assert.rejects(
    lists.getCustomAnimeLists({ data: { userId: "alice" } }),
    (error) => error.code === "unauthenticated",
  );
});

test("getCustomListsForAnime returns only lists containing the anime", async () => {
  const { lists } = domain();
  const created = await lists.createCustomAnimeList({
    auth: { uid: "alice" },
    data: { name: "Shounen" },
  });
  await lists.addAnimeToCustomList({
    auth: { uid: "alice" },
    data: { listId: created.id, animeId: "21", title: "One Piece" },
  });
  const memberships = await lists.getCustomListsForAnime({
    auth: { uid: "alice" },
    data: { animeId: "21" },
  });
  assert.equal(memberships.items.length, 1);
  assert.equal(memberships.items[0].listId, created.id);
  const empty = await lists.getCustomListsForAnime({
    auth: { uid: "alice" },
    data: { animeId: "42" },
  });
  assert.equal(empty.items.length, 0);
  await assert.rejects(
    lists.getCustomListsForAnime({ auth: { uid: "alice" }, data: {} }),
    (error) => error.code === "invalid-argument",
  );
});
