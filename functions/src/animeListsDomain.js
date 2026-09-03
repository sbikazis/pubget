"use strict";

const STATUSES = Object.freeze([
  "watching",
  "completed",
  "plan_to_watch",
  "dropped",
  "on_hold",
  "favorites",
]);

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

  function characterRef(userId, characterId) {
    return db.collection("users").doc(userId).collection("character_favorites").doc(characterId);
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
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
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
    await db.runTransaction(async (tx) => {
      const existing = await tx.get(ref);
      if (!existing.exists) return;
      if (existing.data()?.userId && existing.data().userId !== userId) {
        throw new HttpsError("permission-denied", "This list entry belongs to another account.");
      }
      tx.delete(ref);
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
    if (!favorite) {
      await ref.delete();
      return { characterId, favorite: false };
    }
    await ref.set({
      characterId,
      userId,
      name,
      rating,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    return { characterId, favorite: true, rating };
  }

  async function getCharacterFavorites(request) {
    const userId = uid(request);
    const snap = await db.collection("users").doc(userId)
      .collection("character_favorites").limit(80).get();
    const items = (snap.docs || []).map((doc) => ({ id: doc.id, ...doc.data() }));
    return { items };
  }

  return {
    setAnimeListEntry,
    removeAnimeListEntry,
    getAnimeList,
    setCharacterFavorite,
    getCharacterFavorites,
    STATUSES,
  };
}

module.exports = {
  createAnimeListsDomain,
  ANIME_LIST_STATUSES: STATUSES,
};
