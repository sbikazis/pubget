"use strict";

const STATUSES = Object.freeze([
  "watching",
  "completed",
  "plan_to_watch",
  "dropped",
  "on_hold",
  "favorites",
]);

const MAX_CUSTOM_LISTS = 30;
const MAX_CUSTOM_LIST_ITEMS = 500;
const MAX_CUSTOM_LIST_SEED_ITEMS = 200;

function validString(value, max) {
  return typeof value === "string" && value.trim().length > 0 && value.trim().length <= max;
}

function createAnimeListsDomain({ db, FieldValue, HttpsError }) {
  function uid(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  function entryRef(userId, animeId) {
    return db.collection("users").doc(userId).collection("anime_lists").doc(animeId);
  }

  function statsRef(animeId) {
    return db.collection("anime_stats").doc(animeId);
  }

  function characterRef(userId, characterId) {
    return db.collection("users").doc(userId).collection("character_favorites").doc(characterId);
  }

  function customListRef(userId, listId) {
    return db.collection("users").doc(userId).collection("anime_custom_lists").doc(listId);
  }

  function customListCountRef(userId) {
    return db.collection("users").doc(userId).collection("custom_lists_meta").doc("count");
  }

  function customListItemRef(userId, listId, animeId) {
    return db.collection("users").doc(userId)
      .collection("anime_custom_lists").doc(listId)
      .collection("items").doc(animeId);
  }

  function ensureOwnedList(tx, meta, userId, listId) {
    if (!meta.exists) {
      throw new HttpsError("not-found", "This list does not exist.");
    }
    const data = meta.data() || {};
    if (data.ownerUid && data.ownerUid !== userId) {
      throw new HttpsError("permission-denied", "This list belongs to another account.");
    }
    return data;
  }

  async function setAnimeListEntry(request) {
    const userId = uid(request);
    const animeId = validString(request.data && request.data.animeId, 64)
      ? request.data.animeId.trim()
      : null;
    const status = STATUSES.includes(request.data && request.data.status)
      ? request.data.status
      : null;
    const title = validString(request.data && request.data.title, 200)
      ? request.data.title.trim()
      : "";
    const ratingRaw = request.data && request.data.rating;
    const rating = ratingRaw == null ? null : Number(ratingRaw);
    if (!animeId || !status) {
      throw new HttpsError("invalid-argument", "animeId and a valid status are required.");
    }
    if (rating != null && (!Number.isInteger(rating) || rating < 1 || rating > 10)) {
      throw new HttpsError("invalid-argument", "Rating must be an integer from 1 to 10.");
    }
    const ref = entryRef(userId, animeId);
    const stats = statsRef(animeId);
    await db.runTransaction(async (tx) => {
      const [existing, statsSnap] = await Promise.all([tx.get(ref), tx.get(stats)]);
      const payload = {
        animeId,
        userId,
        status,
        title,
        rating,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        payload.createdAt = FieldValue.serverTimestamp();
        tx.create(ref, payload);
        tx.set(stats, {
          animeId,
          title,
          listedCount: (Number(statsSnap.data()?.listedCount) || 0) + 1,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
        return;
      }
      if (existing.data()?.userId && existing.data().userId !== userId) {
        throw new HttpsError("permission-denied", "This list entry belongs to another account.");
      }
      tx.update(ref, payload);
    });
    return { animeId, status, rating };
  }

  async function removeAnimeListEntry(request) {
    const userId = uid(request);
    const animeId = validString(request.data && request.data.animeId, 64)
      ? request.data.animeId.trim()
      : null;
    if (!animeId) throw new HttpsError("invalid-argument", "animeId is required.");
    const ref = entryRef(userId, animeId);
    const stats = statsRef(animeId);
    await db.runTransaction(async (tx) => {
      const [existing, statsSnap] = await Promise.all([tx.get(ref), tx.get(stats)]);
      if (!existing.exists) return;
      if (existing.data()?.userId && existing.data().userId !== userId) {
        throw new HttpsError("permission-denied", "This list entry belongs to another account.");
      }
      tx.delete(ref);
      if (statsSnap.exists) {
        tx.set(stats, {
          animeId,
          listedCount: Math.max(0, (Number(statsSnap.data()?.listedCount) || 0) - 1),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
    });
    return { ok: true };
  }

  async function getAnimeList(request) {
    const userId = uid(request);
    const status = request.data && request.data.status;
    const cursor = request.data && request.data.cursor;
    const limit = Math.min(50, Math.max(1, Number(request.data && request.data.limit) || 20));
    let query = db.collection("users").doc(userId).collection("anime_lists")
      .orderBy("updatedAt", "desc")
      .limit(limit);
    if (STATUSES.includes(status)) query = query.where("status", "==", status);
    if (cursor) {
      const cursorSnap = await entryRef(userId, cursor).get();
      if (cursorSnap.exists) query = query.startAfter(cursorSnap);
    }
    const snap = await query.get();
    const items = (snap.docs || []).map((doc) => ({ id: doc.id, ...doc.data() }));
    return {
      items,
      cursor: items.length ? items[items.length - 1].animeId || items[items.length - 1].id : null,
      hasMore: items.length === limit,
    };
  }

  async function setCharacterFavorite(request) {
    const userId = uid(request);
    const characterId = validString(request.data && request.data.characterId, 64)
      ? request.data.characterId.trim()
      : null;
    const name = validString(request.data && request.data.name, 120)
      ? request.data.name.trim()
      : "";
    const imageUrl = validString(request.data && request.data.imageUrl, 2048)
      ? request.data.imageUrl.trim()
      : "";
    const favorite = request.data && request.data.favorite !== false;
    const ratingRaw = request.data && request.data.rating;
    const rating = ratingRaw == null ? null : Number(ratingRaw);
    if (!characterId) {
      throw new HttpsError("invalid-argument", "characterId is required.");
    }
    if (rating != null && (!Number.isInteger(rating) || rating < 1 || rating > 10)) {
      throw new HttpsError("invalid-argument", "Rating must be an integer from 1 to 10.");
    }
    const ref = characterRef(userId, characterId);
    const statsRef = db.collection("character_stats").doc(characterId);
    await db.runTransaction(async (tx) => {
      const [existing, stats] = await Promise.all([tx.get(ref), tx.get(statsRef)]);
      if (!favorite) {
        if (!existing.exists) return;
        if (existing.data()?.userId && existing.data().userId !== userId) {
          throw new HttpsError("permission-denied", "This favorite belongs to another account.");
        }
        tx.delete(ref);
        if (stats.exists) {
          const count = Math.max(0, (Number(stats.data()?.favoritesCount) || 0) - 1);
          tx.update(statsRef, {
            favoritesCount: count,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return;
      }
      const payload = {
        characterId,
        userId,
        name,
        imageUrl,
        rating,
        updatedAt: FieldValue.serverTimestamp(),
      };
      const already = existing.exists;
      if (!already) payload.createdAt = FieldValue.serverTimestamp();
      tx.set(ref, payload, { merge: true });
      const nextCount = already
        ? Number(stats.data()?.favoritesCount) || 0
        : (Number(stats.data()?.favoritesCount) || 0) + 1;
      tx.set(statsRef, {
        characterId,
        name: name || stats.data()?.name || "",
        imageUrl: imageUrl || stats.data()?.imageUrl || "",
        favoritesCount: nextCount,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return { characterId, favorite, rating };
  }

  async function getCharacterFavorites(request) {
    const userId = uid(request);
    const snap = await db.collection("users").doc(userId)
      .collection("character_favorites").limit(80).get();
    const items = (snap.docs || []).map((doc) => ({ id: doc.id, ...doc.data() }));
    return { items };
  }

  async function createCustomAnimeList(request) {
    const userId = uid(request);
    const name = validString(request.data && request.data.name, 80)
      ? request.data.name.trim()
      : null;
    if (!name) {
      throw new HttpsError("invalid-argument", "A list name (1–80 characters) is required.");
    }
    const description = validString(request.data && request.data.description, 300)
      ? request.data.description.trim()
      : "";
    const isPrivate = !!(request.data && request.data.private);
    const rawIds = Array.isArray(request.data && request.data.animeIds)
      ? request.data.animeIds
      : [];
    const animeIds = [...new Set(
      rawIds
        .map((value) => (validString(value, 64) ? String(value).trim() : null))
        .filter(Boolean),
    )].slice(0, MAX_CUSTOM_LIST_SEED_ITEMS);
    const col = db.collection("users").doc(userId).collection("anime_custom_lists");
    const id = col.doc().id;
    const metaRef = customListRef(userId, id);
    const countRef = customListCountRef(userId);
    await db.runTransaction(async (tx) => {
      const countSnap = await tx.get(countRef);
      const count = Number(countSnap.data() && countSnap.data().count) || 0;
      if (count >= MAX_CUSTOM_LISTS) {
        throw new HttpsError(
          "resource-exhausted",
          `You can create up to ${MAX_CUSTOM_LISTS} custom lists.`,
        );
      }
      tx.create(metaRef, {
        ownerUid: userId,
        name,
        description,
        private: isPrivate,
        itemsCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(countRef, { count: count + 1 }, { merge: true });
    });
    if (animeIds.length) {
      await Promise.all(
        animeIds.map((animeId) => customListItemRef(userId, id, animeId).set({
          animeId,
          title: "",
          addedAt: FieldValue.serverTimestamp(),
        })),
      );
      await metaRef.update({ itemsCount: animeIds.length });
    }
    return { id, name, description, private: isPrivate, itemsCount: animeIds.length };
  }

  async function updateCustomAnimeList(request) {
    const userId = uid(request);
    const listId = validString(request.data && request.data.listId, 64)
      ? request.data.listId.trim()
      : null;
    if (!listId) throw new HttpsError("invalid-argument", "listId is required.");
    const payload = {};
    if (request.data && request.data.name !== undefined) {
      const name = validString(request.data.name, 80)
        ? request.data.name.trim()
        : null;
      if (!name) throw new HttpsError("invalid-argument", "A list name (1–80 characters) is required.");
      payload.name = name;
    }
    if (request.data && request.data.description !== undefined) {
      payload.description = validString(request.data.description, 300)
        ? request.data.description.trim()
        : "";
    }
    if (request.data && request.data.private !== undefined) {
      payload.private = !!request.data.private;
    }
    if (!Object.keys(payload).length) {
      throw new HttpsError("invalid-argument", "Nothing to update.");
    }
    payload.updatedAt = FieldValue.serverTimestamp();
    const ref = customListRef(userId, listId);
    await db.runTransaction(async (tx) => {
      const doc = await tx.get(ref);
      const data = ensureOwnedList(tx, doc, userId, listId);
      tx.update(ref, payload);
      return data;
    });
    return { ok: true };
  }

  async function deleteCustomAnimeList(request) {
    const userId = uid(request);
    const listId = validString(request.data && request.data.listId, 64)
      ? request.data.listId.trim()
      : null;
    if (!listId) throw new HttpsError("invalid-argument", "listId is required.");
    const ref = customListRef(userId, listId);
    const meta = await ref.get();
    const data = meta.data() || {};
    if (!meta.exists) throw new HttpsError("not-found", "This list does not exist.");
    if (data.ownerUid && data.ownerUid !== userId) {
      throw new HttpsError("permission-denied", "This list belongs to another account.");
    }
    const itemsSnap = await ref.collection("items").get();
    await Promise.all(
      (itemsSnap.docs || []).map((doc) => ref.collection("items").doc(doc.id).delete()),
    );
    await ref.delete();
    const countRef = customListCountRef(userId);
    const countSnap = await countRef.get();
    const count = Math.max(0, Number(countSnap.data() && countSnap.data().count) || 0);
    await db.runTransaction(async (tx) => {
      tx.set(countRef, { count: Math.max(0, count - 1) });
    });
    return { ok: true };
  }

  async function addAnimeToCustomList(request) {
    const userId = uid(request);
    const listId = validString(request.data && request.data.listId, 64)
      ? request.data.listId.trim()
      : null;
    const animeId = validString(request.data && request.data.animeId, 64)
      ? request.data.animeId.trim()
      : null;
    if (!listId || !animeId) {
      throw new HttpsError("invalid-argument", "listId and animeId are required.");
    }
    const title = validString(request.data && request.data.title, 200)
      ? request.data.title.trim()
      : "";
    const metaRef = customListRef(userId, listId);
    const itemRef = customListItemRef(userId, listId, animeId);
    await db.runTransaction(async (tx) => {
      const meta = await tx.get(metaRef);
      ensureOwnedList(tx, meta, userId, listId);
      const existing = await tx.get(itemRef);
      if (existing.exists) {
        tx.update(itemRef, {
          title: title || existing.data()?.title || "",
          addedAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      const count = Number(meta.data() && meta.data().itemsCount) || 0;
      if (count >= MAX_CUSTOM_LIST_ITEMS) {
        throw new HttpsError(
          "resource-exhausted",
          `This list can hold up to ${MAX_CUSTOM_LIST_ITEMS} anime.`,
        );
      }
      tx.create(itemRef, {
        animeId,
        title,
        addedAt: FieldValue.serverTimestamp(),
      });
      tx.update(metaRef, {
        itemsCount: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function removeAnimeFromCustomList(request) {
    const userId = uid(request);
    const listId = validString(request.data && request.data.listId, 64)
      ? request.data.listId.trim()
      : null;
    const animeId = validString(request.data && request.data.animeId, 64)
      ? request.data.animeId.trim()
      : null;
    if (!listId || !animeId) {
      throw new HttpsError("invalid-argument", "listId and animeId are required.");
    }
    const metaRef = customListRef(userId, listId);
    const itemRef = customListItemRef(userId, listId, animeId);
    await db.runTransaction(async (tx) => {
      const meta = await tx.get(metaRef);
      ensureOwnedList(tx, meta, userId, listId);
      const existing = await tx.get(itemRef);
      if (!existing.exists) return;
      tx.delete(itemRef);
      const count = Math.max(0, (Number(meta.data() && meta.data().itemsCount) || 0) - 1);
      tx.update(metaRef, {
        itemsCount: count,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function getCustomAnimeLists(request) {
    const requestingUid = uid(request);
    const userId = validString(request.data && request.data.userId, 128)
      ? request.data.userId.trim()
      : requestingUid;
    const own = userId === requestingUid;
    const snap = await db.collection("users").doc(userId)
      .collection("anime_custom_lists")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();
    const items = (snap.docs || [])
      .map((doc) => ({ id: doc.id, ...doc.data() }))
      .filter((item) => own || !item.private);
    return { userId, items };
  }

  async function getCustomAnimeList(request) {
    const requestingUid = uid(request);
    const userId = validString(request.data && request.data.userId, 128)
      ? request.data.userId.trim()
      : requestingUid;
    const listId = validString(request.data && request.data.listId, 64)
      ? request.data.listId.trim()
      : null;
    if (!listId) throw new HttpsError("invalid-argument", "listId is required.");
    const own = userId === requestingUid;
    const ref = customListRef(userId, listId);
    const meta = await ref.get();
    if (!meta.exists) throw new HttpsError("not-found", "This list does not exist.");
    const data = meta.data() || {};
    if (data.private && !own) {
      throw new HttpsError("permission-denied", "This list is private.");
    }
    const itemsSnap = await ref.collection("items")
      .orderBy("addedAt", "desc")
      .limit(500)
      .get();
    const items = (itemsSnap.docs || []).map((doc) => ({ id: doc.id, ...doc.data() }));
    return { list: { id: listId, ...data }, items };
  }

  async function getCustomListsForAnime(request) {
    const userId = uid(request);
    const animeId = validString(request.data && request.data.animeId, 64)
      ? request.data.animeId.trim()
      : null;
    if (!animeId) throw new HttpsError("invalid-argument", "animeId is required.");
    const col = db.collection("users").doc(userId).collection("anime_custom_lists");
    const listsSnap = await col.limit(100).get();
    const memberships = await Promise.all(
      (listsSnap.docs || []).map(async (doc) => {
        const item = await customListItemRef(userId, doc.id, animeId).get();
        if (!item.exists) return null;
        return { listId: doc.id, name: doc.data()?.name || "" };
      }),
    );
    return {
      animeId,
      items: memberships.filter((item) => item !== null),
    };
  }

  return {
    setAnimeListEntry,
    removeAnimeListEntry,
    getAnimeList,
    setCharacterFavorite,
    getCharacterFavorites,
    createCustomAnimeList,
    updateCustomAnimeList,
    deleteCustomAnimeList,
    addAnimeToCustomList,
    removeAnimeFromCustomList,
    getCustomAnimeLists,
    getCustomAnimeList,
    getCustomListsForAnime,
    STATUSES,
  };
}

module.exports = {
  createAnimeListsDomain,
  ANIME_LIST_STATUSES: STATUSES,
};
