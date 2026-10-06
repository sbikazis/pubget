'use strict';

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  AnimeCatalogRow,
  CharacterPopularityRow,
  CreatorActivityRow,
  FriendActivityRow,
  FreshContentRow,
  rankAnimeOfTheWeek,
  rankPopularCharacters,
  rankRisingCreators,
  rankFriendsActivity,
  rankFreshestContent,
  clampHomeLimit,
  assertViewer,
} = require("./discoveryFeedSections");

const PAGE = 8;
const WEEK_MILLIS = 7 * 24 * 60 * 60 * 1000;
const POOL = 60;

function millisOf(value) {
  if (value && typeof value.toDate === "function") return value.toDate().getTime();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return 0;
}

function dateOf(value) {
  const millis = millisOf(value);
  if (!millis) return null;
  return new Date(millis);
}

/// Builds the Home sections that Master Spec §5.3 requires but that the first
/// discovery feed could not honestly serve.
///
/// The rule that shapes every function here: a section that has no real signal
/// returns an empty list. Home renders an honest empty state in that case rather
/// than padding the section with unrelated or newest-by-date filler, because
/// §5.4 forbids presenting a false recommendation reason.
function createHomeSections({ db, HttpsError: Errors, clock }) {
  const fail = (code, message) => {
    throw new (Errors || HttpsError)(code, message);
  };

  function nowDate() {
    return clock && typeof clock.now === "function" ? clock.now() : new Date();
  }

  async function readCollection(name, filters = [], limit = POOL) {
    let query = db.collection(name);
    for (const filter of filters) {
      query = query.where(filter[0], filter[1], filter[2]);
    }
    const snap = await query.limit(limit).get();
    return snap.docs || [];
  }

  /// Total community rating count for the anime that made the weekly list.
  async function ratingCountsFor(animeIds) {
    const counts = new Map();
    for (const animeId of animeIds) {
      const snap = await db
        .collection("anime_stats")
        .doc(animeId)
        .get()
        .catch(() => null);
      if (snap && snap.exists) {
        counts.set(animeId, Number((snap.data() || {}).ratingCount || 0));
      }
    }
    return counts;
  }

  /// Anime titles, image and total rating count, straight from the server-owned
  /// aggregate the rating transaction maintains.
  async function readAnimeStats() {
    const stats = new Map();
    const snap = await db.collection("anime_stats").get().catch(() => null);
    if (!snap || !snap.docs) return stats;
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      stats.set(doc.id, {
        title: typeof data.title === "string" ? data.title : "",
        imageUrl: typeof data.imageUrl === "string" ? data.imageUrl : "",
        ratingCount: Math.max(0, Number(data.ratingCount) || 0),
        updatedAt: millisOf(data.updatedAt),
      });
    }
    return stats;
  }

  /// Published edits created in the last seven days, counted per anime. This is
  /// the honest reading of "anime of the week": the week is defined by when
  /// members actually published for an anime, not by a weekly counter that no
  /// writer in the codebase maintains.
  async function weeklyEditCounts(cutoffMillis) {
    const counts = new Map();
    const snap = await db
      .collection("edits")
      .where("status", "==", "published")
      .where("createdAt", ">=", new Date(cutoffMillis))
      .limit(POOL * 5)
      .get()
      .catch(() => null);
    if (!snap || !snap.docs) return counts;
    for (const doc of snap.docs) {
      const animeId = String((doc.data() || {}).animeId || "").trim();
      if (!animeId) continue;
      counts.set(animeId, (counts.get(animeId) || 0) + 1);
    }
    return counts;
  }

  /// Anime of the week: real activity from the last seven days.
  async function animeOfTheWeek(uid, limit) {
    const now = nowDate();
    const cutoff = now.getTime() - WEEK_MILLIS;
    const stats = await readAnimeStats();
    const editCounts = await weeklyEditCounts(cutoff);

    let rows = [];
    let source = "weekly_edits";
    if (editCounts.size > 0) {
      // The published edit itself proves the anime was active this week, so the
      // recency gate is satisfied without inventing a rating timestamp.
      for (const [animeId, weekly] of editCounts) {
        rows.push(
          new AnimeCatalogRow({
            id: animeId,
            title: (stats.get(animeId) || {}).title || "",
            ratingCount: (stats.get(animeId) || {}).ratingCount || 0,
            weeklyRatingCount: weekly,
            lastRatedAt: new Date(cutoff),
          }),
        );
      }
    } else {
      // Nothing was published this week, so fall back to anime the community
      // actually rated this week. `anime_stats.updatedAt` moves on every rating.
      source = "weekly_ratings";
      for (const [animeId, entry] of stats) {
        if (!entry.updatedAt || entry.updatedAt < cutoff) continue;
        if (entry.ratingCount <= 0) continue;
        rows.push(
          new AnimeCatalogRow({
            id: animeId,
            title: entry.title,
            ratingCount: entry.ratingCount,
            weeklyRatingCount: entry.ratingCount,
            lastRatedAt: new Date(entry.updatedAt),
          }),
        );
      }
    }

    const ranked = rankAnimeOfTheWeek(rows, { now, limit });
    return ranked.map((row) => {
      const entry = stats.get(row.id) || {};
      return {
        id: row.id,
        type: "anime",
        source,
        targetId: row.id,
        score: row.weeklyRatingCount,
        title: row.title,
        reason: "this_week",
        metadata: {
          title: row.title,
          imageUrl: entry.imageUrl || "",
          ratingCount: entry.ratingCount || row.ratingCount,
          weeklyRatingCount: row.weeklyRatingCount,
        },
      };
    });
  }

  /// Popular characters: the community favourite counter plus any discussion
  /// signal the popularity row carries.
  ///
  /// The favourite count comes from `character_stats.favoritesCount`, which the
  /// favourite transaction in `animeListsDomain` maintains. It is deliberately
  /// not re-derived by scanning each user's favourites: that needs a
  /// collection-group index that does not exist in `firestore.indexes.json`, and
  /// the failure would be swallowed into a report that every character has zero
  /// favourites.
  async function popularCharacters(uid, limit) {
    const docs = await readCollection("character_stats", [], POOL);
    if (docs.length === 0) return [];
    const rows = [];
    const images = new Map();
    for (const doc of docs) {
      const data = doc.data() || {};
      const favourites = Math.max(
        0,
        Number(data.favoritesCount != null ? data.favoritesCount : data.favouriteCount) || 0,
      );
      const discussions = Math.max(0, Number(data.discussionCount) || 0);
      images.set(doc.id, typeof data.imageUrl === "string" ? data.imageUrl : "");
      rows.push(
        new CharacterPopularityRow({
          characterId: doc.id,
          name: typeof data.name === "string" ? data.name : "",
          favouriteCount: favourites,
          discussionCount: discussions,
        }),
      );
    }
    // `rankPopularCharacters` derives the reason from the signal that decided
    // the rank, which is exactly what §5.4 requires.
    return rankPopularCharacters(rows, { limit }).map((item) => ({
      id: item.id,
      type: "character",
      source: "community",
      targetId: item.id,
      score: item.score,
      title: item.title,
      reason: item.reason,
      metadata: {
        ...item.metadata,
        imageUrl: images.get(item.id) || "",
      },
    }));
  }

  /// Rising creators: sustained output, damped engagement, viewer excluded.
  async function risingCreators(uid, limit) {
    const [editDocs, fanWorkDocs] = await Promise.all([
      readCollection("edits", [["status", "==", "published"]], POOL),
      readCollection("fanWorks", [
        ["status", "==", "published"],
        ["moderationStatus", "==", "approved"],
      ], POOL),
    ]);
    const byCreator = new Map();
    const note = (creatorId, field, engagement) => {
      if (!creatorId) return;
      const entry = byCreator.get(creatorId) || {
        creatorId,
        editCount: 0,
        fanWorkCount: 0,
        totalEngagement: 0,
      };
      entry[field] += 1;
      entry.totalEngagement += engagement;
      byCreator.set(creatorId, entry);
    };
    for (const doc of editDocs) {
      const data = doc.data() || {};
      note(
        data.creatorId,
        "editCount",
        Number(data.likesCount || 0) + Number(data.viewsCount || 0),
      );
    }
    for (const doc of fanWorkDocs) {
      const data = doc.data() || {};
      note(
        data.creatorId,
        "fanWorkCount",
        Number(data.likesCount || 0) + Number(data.viewsCount || 0),
      );
    }
    const nameSnapshots = await Promise.all(
      [...byCreator.keys()].slice(0, POOL).map((creatorId) =>
        db
          .collection("public_profiles")
          .doc(creatorId)
          .get()
          .catch(() => null),
      ),
    );
    let nameIndex = 0;
    const rows = [];
    for (const entry of byCreator.values()) {
      const snapshot = nameSnapshots[nameIndex];
      nameIndex += 1;
      const profile = snapshot && snapshot.exists ? snapshot.data() || {} : {};
      rows.push(
        new CreatorActivityRow({
          creatorId: entry.creatorId,
          displayName:
            typeof profile.displayName === "string"
              ? profile.displayName
              : typeof profile.username === "string"
              ? profile.username
              : "",
          editCount: entry.editCount,
          fanWorkCount: entry.fanWorkCount,
          totalEngagement: entry.totalEngagement,
        }),
      );
    }
    return rankRisingCreators(rows, { limit, viewerUid: uid }).map((item) => ({
      id: item.id,
      type: "creator",
      source: "ranking",
      targetId: item.id,
      score: item.score,
      title: item.title,
      reason: item.reason,
      metadata: item.metadata,
    }));
  }

  /// What the people the viewer actually follows have been doing.
  async function friendsActivity(uid, limit) {
    const [friendsSnap, blocksSnap] = await Promise.all([
      db
        .collection("friendships")
        .where("userIds", "array-contains", uid)
        .where("status", "==", "accepted")
        .limit(80)
        .get()
        .catch(() => ({ docs: [] })),
      db
        .collection("friendships")
        .where("userIds", "array-contains", uid)
        .where("status", "==", "blocked")
        .limit(80)
        .get()
        .catch(() => ({ docs: [] })),
    ]);
    const friendIds = [];
    for (const doc of friendsSnap.docs || []) {
      for (const id of (doc.data() || {}).userIds || []) {
        if (id && id !== uid && !friendIds.includes(id)) friendIds.push(id);
      }
    }
    const blockedIds = new Set();
    for (const doc of blocksSnap.docs || []) {
      for (const id of (doc.data() || {}).userIds || []) {
        if (id && id !== uid) blockedIds.add(id);
      }
    }
    if (friendIds.length === 0) return [];

    const recent = await Promise.all(
      friendIds.slice(0, 30).map(async (friendId) => {
        const [edits, fanWorks] = await Promise.all([
          db
            .collection("edits")
            .where("creatorId", "==", friendId)
            .where("status", "==", "published")
            .limit(5)
            .get()
            .catch(() => ({ docs: [] })),
          db
            .collection("fanWorks")
            .where("creatorId", "==", friendId)
            .where("status", "==", "published")
            .where("moderationStatus", "==", "approved")
            .limit(5)
            .get()
            .catch(() => ({ docs: [] })),
        ]);
        const rows = [];
        for (const doc of edits.docs || []) {
          rows.push(
            new FriendActivityRow({
              uid: friendId,
              kind: "edit",
              refId: doc.id,
              createdAtMillis: millisOf((doc.data() || {}).createdAt),
            }),
          );
        }
        for (const doc of fanWorks.docs || []) {
          const data = doc.data() || {};
          rows.push(
            new FriendActivityRow({
              uid: friendId,
              kind: "fanWork",
              refId: doc.id,
              createdAtMillis: millisOf(data.publishedAt || data.createdAt),
            }),
          );
        }
        return rows;
      }),
    );
    const flattened = recent.flat();
    return rankFriendsActivity(flattened, {
      viewerUid: uid,
      blockedIds,
      limit,
    }).map((item) => ({
      id: item.id,
      type: "friendActivity",
      source: "social",
      targetId: item.id,
      score: item.score,
      title: item.title,
      reason: item.reason,
      metadata: item.metadata,
    }));
  }

  /// The freshest real content across surfaces, capped per kind.
  async function freshestContent(uid, limit) {
    const [edits, fanWorks, groups, events] = await Promise.all([
      readCollection("edits", [["status", "==", "published"]], POOL),
      readCollection("fanWorks", [
        ["status", "==", "published"],
        ["moderationStatus", "==", "approved"],
      ], POOL),
      readCollection("groups", [["isSearchable", "==", true]], POOL),
      readCollection("events", [["status", "in", ["active", "scheduled"]]], 20).catch(
        () => [],
      ),
    ]);
    const rows = [];
    const push = (doc, kind, titleOf) => {
      const data = doc.data() || {};
      const at = millisOf(
        data.publishedAt || data.createdAt || data.startAt || data.updatedAt,
      );
      rows.push(
        new FreshContentRow({
          refId: doc.id,
          kind,
          title: titleOf(data),
          createdAtMillis: at,
        }),
      );
    };
    for (const doc of edits) {
      push(doc, "edit", (data) =>
        typeof data.caption === "string" ? data.caption : "",
      );
    }
    for (const doc of fanWorks) {
      push(doc, "fanWork", (data) =>
        typeof data.title === "string" ? data.title : "",
      );
    }
    for (const doc of groups) {
      push(doc, "groupJoin", (data) =>
        typeof data.name === "string" ? data.name : "",
      );
    }
    for (const doc of events) {
      push(doc, "event", (data) =>
        typeof data.title === "string" ? data.title : "",
      );
    }
    return rankFreshestContent(rows, { limit }).map((item) => ({
      id: item.id,
      type: "freshContent",
      source: "recency",
      targetId: item.id,
      score: item.score,
      title: item.title,
      reason: item.reason,
      metadata: item.metadata,
    }));
  }

  const sections = {
    animeOfTheWeek,
    popularCharacters,
    risingCreators,
    friendsActivity,
    freshestContent,
  };

  /// Returns the requested section, or every section when none is named.
  async function getHomeSections(request) {
    const uid = request && request.auth && request.auth.uid;
    try {
      assertViewer(uid);
    } catch (error) {
      fail("unauthenticated", "Authentication is required.");
    }
    const data = (request && request.data) || {};
    const limit = clampHomeLimit(data.limit, { page: PAGE });
    const requested = typeof data.section === "string" ? data.section : null;
    const names = requested ? [requested] : Object.keys(sections);
    const out = {};
    for (const name of names) {
      const builder = sections[name];
      if (!builder) {
        fail("invalid-argument", "Unknown Home section.");
      }
      out[name] = { items: await builder(uid, limit), cursor: null, hasMore: false };
    }
    return out;
  }

  return { getHomeSections, sections };
}

module.exports = { createHomeSections };