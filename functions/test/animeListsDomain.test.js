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
  // Reconstruct path on doc()
  const original = db.collection;
  db.collection = (name) => {
    const col = original(name);
    const origDoc = col.doc;
    col.doc = (id) => {
      const ref = origDoc(id);
      ref.path = `${name}/${id}`;
      const origChild = ref.collection;
      ref.collection = (child) => {
        const nested = origChild(child);
        const nestedDoc = nested.doc;
        nested.doc = (childId) => {
          const inner = nestedDoc(childId);
          inner.path = `${name}/${id}/${child}/${childId}`;
          inner.set = async (data) => {
            db.store.set(inner.path, { ...(db.store.get(inner.path) || {}), ...data });
          };
          inner.delete = async () => {
            db.store.delete(inner.path);
          };
          return inner;
        };
        nested.where = () => nested;
        nested.orderBy = () => nested;
        nested.limit = () => nested;
        nested.startAfter = () => nested;
        nested.get = async () => ({
          docs: [...db.store.entries()]
            .filter(([path]) => path.startsWith(`${name}/${id}/${child}/`))
            .map(([path, data]) => ({ id: path.split("/").pop(), data: () => data })),
        });
        return nested;
      };
      return ref;
    };
    return col;
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
