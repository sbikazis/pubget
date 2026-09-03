"use strict";

const {
  scoreEdit,
  scoreGroup,
  scorePerson,
  scoreFanWork,
  scoreEvent,
  scoreAnime,
  applyDiversity,
  isColdStart,
  mixExploration,
} = require("./ranking");

const POOL = 40;
const PAGE = 8;

function asList(value) {
  return Array.isArray(value) ? value.filter((item) => typeof item === "string" && item) : [];
}

function dateOf(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  return new Date(value);
}

function item(type, doc, score, extra = {}) {
  return {
    id: `${type}:${doc.id}`,
    type,
    source: extra.source || "ranking",
    score: Math.round(score * 10) / 10,
    createdAt: extra.createdAt || null,
    targetId: doc.id,
    creatorId: extra.creatorId || doc.data && (doc.data.creatorId || doc.data.founderId) || null,
    groupId: extra.groupId || (doc.data && doc.data.groupId) || null,
    metadata: extra.metadata || doc.data || {},
  };
}

function createRecommendationEngine({ db, HttpsError, clock }) {
  function now() {
    return clock && typeof clock.now === "function" ? clock.now() : new Date();
  }

  function requireUid(request) {
    if (!request || !request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    return request.auth.uid;
  }

  async function loadProfile(uid) {
    const userSnap = await db.collection("users").doc(uid).get();
    const user = userSnap.exists ? userSnap.data() || {} : {};
    const [members, friends, blocks, lists, characters] = await Promise.all([
      db.collectionGroup("members").where("userId", "==", uid).limit(80).get()
        .catch(() => ({ docs: [] })),
      db.collection("friendships")
        .where("userIds", "array-contains", uid)
        .where("status", "==", "accepted")
        .limit(80)
        .get()
        .catch(() => ({ docs: [] })),
      db.collection("friendships")
        .where("userIds", "array-contains", uid)
        .where("status", "==", "blocked")
        .limit(80)
        .get()
        .catch(() => ({ docs: [] })),
      db.collection("users").doc(uid).collection("anime_lists").limit(100).get()
        .catch(() => ({ docs: [] })),
      db.collection("users").doc(uid).collection("character_favorites").limit(50).get()
        .catch(() => ({ docs: [] })),
    ]);
    const memberGroupIds = new Set((members.docs || []).map((doc) => {
      const path = doc.ref.path || "";
      const parts = path.split("/");
      const idx = parts.indexOf("groups");
      return idx >= 0 ? parts[idx + 1] : doc.data()?.groupId;
    }).filter(Boolean));
    const friendIds = new Set();
    (friends.docs || []).forEach((doc) => {
      const ids = doc.data()?.userIds || [];
      ids.forEach((id) => {
        if (id && id !== uid) friendIds.add(id);
      });
    });
    const blockedIds = new Set();
    (blocks.docs || []).forEach((doc) => {
      const ids = doc.data()?.userIds || [];
      ids.forEach((id) => {
        if (id && id !== uid) blockedIds.add(id);
      });
    });
    const listedAnimeIds = new Set((lists.docs || []).map((doc) => doc.id));
    const animeIds = [
      ...asList(user.favoriteAnimeIds),
      ...[...listedAnimeIds],
    ];
    return {
      userId: uid,
      animeIds,
      characterIds: (characters.docs || []).map((doc) => doc.id),
      memberGroupIds,
      friendIds,
      blockedIds,
      listedAnimeIds,
      friendGroupIds: new Set(),
      creatorIds: new Set(),
      mutualFriendIds: new Set(),
      mutualFanIds: new Set(),
      sharedGroupIds: {},
      seenIds: new Set(),
      seenCreators: new Map(),
    };
  }

  async function loadPool(collection, filters, limit) {
    let query = db.collection(collection);
    for (const filter of filters) {
      query = query.where(filter[0], filter[1], filter[2]);
    }
    const snap = await query.limit(limit).get();
    return (snap.docs || []).map((doc) => ({ id: doc.id, data: doc.data() || {}, ref: doc.ref }));
  }

  function visibleToViewer(entry, profile) {
    if (!entry || entry.score <= 0) return false;
    const blocked = profile.blockedIds;
    if (!blocked || blocked.size === 0) return true;
    const creatorId = entry.creatorId || (entry.metadata && entry.metadata.creatorId);
    if (creatorId && blocked.has(creatorId)) return false;
    if (entry.type === "person" && blocked.has(entry.targetId)) return false;
    if (entry.type === "creator" && blocked.has(entry.targetId)) return false;
    return true;
  }

  function paginate(items, cursor, limit) {
    const start = cursor
      ? items.findIndex((item) => item.targetId === cursor || item.id === cursor) + 1
      : 0;
    const sliceStart = start < 0 ? 0 : start;
    const page = items.slice(sliceStart, sliceStart + limit);
    return {
      items: page,
      cursor: page.length ? page[page.length - 1].targetId : null,
      hasMore: sliceStart + page.length < items.length,
    };
  }

  async function buildFeed(uid) {
    const profile = await loadProfile(uid);
    const coldStart = isColdStart(profile);
    const current = now();
    const [groups, people, edits, fanWorks, events] = await Promise.all([
      loadPool("groups", [["isSearchable", "==", true]], POOL),
      loadPool("public_profiles", [], POOL),
      loadPool("edits", [["status", "==", "published"]], POOL),
      loadPool("fanWorks", [["status", "==", "published"]], POOL),
      loadPool("events", [["status", "in", ["active", "scheduled"]]], 20)
        .catch(() => loadPool("events", [["status", "==", "active"]], 20)),
    ]);

    const peopleRanked = applyDiversity(people
      .map((doc) => {
        const data = { ...doc.data, uid: doc.id, favoriteAnimeIds: asList(doc.data.favoriteAnimeIds) };
        return item("person", doc, scorePerson(data, profile), {
          metadata: data,
          creatorId: doc.id,
        });
      })
      .filter((entry) => visibleToViewer(entry, profile))
      .sort((a, b) => b.score - a.score));

    const groupsRanked = applyDiversity(groups
      .map((doc) => item("group", doc, scoreGroup({
        ...doc.data,
        id: doc.id,
        risingScore: doc.data.risingScore || doc.data.activityScore,
      }, profile, current), {
        metadata: doc.data,
        groupId: doc.id,
        creatorId: doc.data.founderId,
        createdAt: dateOf(doc.data.createdAt),
        source: coldStart ? "cold_start" : "ranking",
      }))
      .filter((entry) => visibleToViewer(entry, profile))
      .sort((a, b) => b.score - a.score));

    const editsRanked = mixExploration(applyDiversity(edits
      .map((doc) => item("edit", doc, scoreEdit(doc.data, profile, current), {
        metadata: {
          creatorId: doc.data.creatorId,
          animeTag: doc.data.animeTag,
          thumbnailUrl: doc.data.thumbnailUrl,
          caption: doc.data.caption,
        },
        creatorId: doc.data.creatorId,
        createdAt: dateOf(doc.data.createdAt),
      }))
      .filter((entry) => visibleToViewer(entry, profile))
      .sort((a, b) => b.score - a.score)));

    const fanWorksRanked = applyDiversity(fanWorks
      .filter((doc) => doc.data.moderationStatus === "approved")
      .map((doc) => item("fanWork", doc, scoreFanWork(doc.data, profile, current), {
        metadata: {
          title: doc.data.title,
          type: doc.data.type,
          cover: doc.data.cover,
          creatorId: doc.data.creatorId,
          animeId: doc.data.animeId,
        },
        creatorId: doc.data.creatorId,
        createdAt: dateOf(doc.data.publishedAt || doc.data.createdAt),
      }))
      .filter((entry) => visibleToViewer(entry, profile))
      .sort((a, b) => b.score - a.score));

    const eventsRanked = events
      .map((doc) => item("event", doc, scoreEvent(doc.data, profile, current), {
        metadata: {
          title: doc.data.title,
          type: doc.data.type,
          groupId: doc.data.groupId,
        },
        groupId: doc.data.groupId,
        createdAt: dateOf(doc.data.startAt || doc.data.createdAt),
      }))
      .filter((entry) => entry.score > 0)
      .sort((a, b) => b.score - a.score);

    const animeCandidates = new Map();
    const rememberAnime = (id, extra = {}) => {
      if (!id) return;
      const key = String(id);
      if (!animeCandidates.has(key)) {
        animeCandidates.set(key, {
          id: key, relatedIds: [key], genres: [], score: 6, ...extra,
        });
      }
    };
    groups.forEach((doc) => rememberAnime(doc.data.animeId, { score: 7 }));
    edits.forEach((doc) => rememberAnime(doc.data.animeTag));
    fanWorks.forEach((doc) => rememberAnime(doc.data.animeId));
    asList(profile.animeIds).forEach((id) => rememberAnime(id, { score: 8 }));
    const animeRanked = [...animeCandidates.values()]
      .map((anime) => item("anime", { id: anime.id, data: anime }, scoreAnime(anime, profile), {
        metadata: { title: anime.id },
        source: coldStart ? "cold_start" : "ranking",
      }))
      .filter((entry) => entry.score > 0)
      .sort((a, b) => b.score - a.score);

    const risingCreators = [...editsRanked, ...fanWorksRanked]
      .reduce((map, entry) => {
        const id = entry.creatorId;
        if (!id || id === uid) return map;
        map.set(id, (map.get(id) || 0) + entry.score);
        return map;
      }, new Map());
    const creatorItems = [...risingCreators.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([creatorId, score]) => ({
        id: `creator:${creatorId}`,
        type: "creator",
        source: "ranking",
        score: Math.round(score * 10) / 10,
        targetId: creatorId,
        creatorId,
        metadata: {},
      }))
      .filter((entry) => visibleToViewer(entry, profile));

    return {
      coldStart,
      ranked: {
        recommendedGroups: groupsRanked,
        recommendedPeople: peopleRanked,
        recommendedEdits: editsRanked,
        recommendedFanWorks: fanWorksRanked,
        recommendedEvents: eventsRanked,
        recommendedAnime: animeRanked,
        risingCreators: creatorItems,
      },
    };
  }

  async function getDiscoveryFeed(request) {
    const uid = requireUid(request);
    const section = request.data && request.data.section;
    const cursor = request.data && request.data.cursor;
    const limit = Math.min(20, Math.max(1, Number(request.data && request.data.limit) || PAGE));
    const feed = await buildFeed(uid);
    const sections = {};
    for (const [key, ranked] of Object.entries(feed.ranked)) {
      sections[key] = paginate(ranked, section === key ? cursor : null, PAGE);
    }
    if (!section) {
      return { coldStart: feed.coldStart, sections };
    }
    if (!feed.ranked[section]) {
      throw new HttpsError("invalid-argument", "Unknown discovery section.");
    }
    return {
      coldStart: feed.coldStart,
      section,
      ...paginate(feed.ranked[section], cursor, limit),
    };
  }

  return {
    getDiscoveryFeed,
    buildFeed,
    loadProfile,
  };
}

module.exports = {
  createRecommendationEngine,
};
