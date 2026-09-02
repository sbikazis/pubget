"use strict";

const TYPES = Object.freeze([
  "manga",
  "drawing",
  "story",
  "character",
  "aiCharacter",
  "worldbuilding",
  "other",
]);
const REPORT_REASONS = Object.freeze([
  "inappropriate",
  "spam",
  "copyright",
  "harassment",
  "other",
]);
const MEDIA_ROLES = Object.freeze(["cover", "page", "image", "extra"]);
const ALLOWED_MIME = Object.freeze({
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
});

const TITLE_MIN = 3;
const TITLE_MAX = 80;
const DESCRIPTION_MAX = 2000;
const STORY_BODY_MAX = 20000;
const CHAPTER_BODY_MAX = 8000;
const CHAPTER_TITLE_MAX = 80;
const MAX_CHAPTERS = 20;
const LORE_MAX = 8000;
const ENTRY_NAME_MAX = 80;
const ENTRY_DESCRIPTION_MAX = 500;
const MAX_LOCATIONS = 20;
const MAX_FACTIONS = 20;
const MAX_WORLD_CHARACTERS = 20;
const MAX_TAGS = 8;
const TAG_MIN = 2;
const TAG_MAX = 24;
const MAX_PAGES = 40;
const MAX_IMAGES = 8;
const MAX_ANIME_ID = 64;
const MAX_ANIME_TITLE = 120;
const MAX_CHARACTER_REFS = 8;
const MAX_PERSONALITY = 1000;
const MAX_ABILITIES = 1000;
const MAX_BACKGROUND = 4000;
const MAX_CAPTION = 200;
const MAX_NAME = 80;
const SCHEMA_VERSION = 1;
const MAX_MEDIA_ID = 128;
const MAX_PATH = 256;
const MIN_STORY_CHARS = 20;
const MIN_OTHER_CHARS = 20;

function requireAuth(request, HttpsError) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function validString(value, max, min = 1) {
  return typeof value === "string" &&
    value.trim().length >= min &&
    value.trim().length <= max;
}

function optionalString(value, max) {
  if (value == null || value === "") return "";
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (trimmed.length > max) return null;
  return trimmed;
}

function normalizeTags(raw) {
  if (raw == null) return [];
  const source = Array.isArray(raw)
    ? raw
    : typeof raw === "string"
      ? raw.split(",")
      : [];
  const seen = new Set();
  const out = [];
  for (const item of source) {
    if (typeof item !== "string") continue;
    const tag = item
      .trim()
      .replace(/^#+/, "")
      .toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, "");
    if (tag.length < TAG_MIN || tag.length > TAG_MAX) continue;
    if (seen.has(tag)) continue;
    seen.add(tag);
    out.push(tag);
    if (out.length >= MAX_TAGS) break;
  }
  return out;
}

function normalizeCharacterIds(raw) {
  if (!Array.isArray(raw)) return [];
  const seen = new Set();
  const out = [];
  for (const item of raw) {
    if (typeof item !== "string") continue;
    const id = item.trim();
    if (!validString(id, MAX_ANIME_ID, 1)) continue;
    if (seen.has(id)) continue;
    seen.add(id);
    out.push(id);
    if (out.length >= MAX_CHARACTER_REFS) break;
  }
  return out;
}

function workRef(db, workId) {
  return db.collection("fanWorks").doc(workId);
}

function assertOwnedPath(uid, workId, path, HttpsError) {
  const expected = `fan_works/${uid}/${workId}/`;
  if (typeof path !== "string" || path.length > MAX_PATH || !path.startsWith(expected)) {
    throw new HttpsError("invalid-argument", "Media path is invalid.");
  }
  const parts = path.split("/");
  if (parts.length !== 4 || parts.some((part) => !part || part === "." || part === "..")) {
    throw new HttpsError("invalid-argument", "Media path is invalid.");
  }
}

function mediaFromExisting(item) {
  if (!item || typeof item.path !== "string") return null;
  return {
    mediaId: typeof item.mediaId === "string" ? item.mediaId : "",
    path: item.path,
    contentType: typeof item.contentType === "string" ? item.contentType : "image/jpeg",
  };
}

function sanitizePages(existingPages, requestedIds, captions) {
  const current = Array.isArray(existingPages) ? existingPages : [];
  const byId = new Map();
  for (const page of current) {
    const media = mediaFromExisting(page);
    if (!media || !media.mediaId) continue;
    byId.set(media.mediaId, {
      ...media,
      caption: typeof page.caption === "string" ? page.caption.slice(0, MAX_CAPTION) : "",
    });
  }
  const order = Array.isArray(requestedIds)
    ? requestedIds.filter((id) => typeof id === "string" && byId.has(id))
    : [...byId.keys()];
  const captionMap = captions && typeof captions === "object" ? captions : {};
  return order.slice(0, MAX_PAGES).map((mediaId, index) => {
    const page = byId.get(mediaId);
    const captionRaw = captionMap[mediaId];
    const caption = typeof captionRaw === "string"
      ? captionRaw.trim().slice(0, MAX_CAPTION)
      : page.caption;
    return { ...page, index, caption: caption || "" };
  });
}

function sanitizeImages(existingImages, requestedIds) {
  const current = Array.isArray(existingImages) ? existingImages : [];
  const byId = new Map();
  for (const image of current) {
    const media = mediaFromExisting(image);
    if (!media || !media.mediaId) continue;
    byId.set(media.mediaId, media);
  }
  const order = Array.isArray(requestedIds)
    ? requestedIds.filter((id) => typeof id === "string" && byId.has(id))
    : [...byId.keys()];
  return order.slice(0, MAX_IMAGES).map((mediaId) => byId.get(mediaId));
}

function sanitizeChapters(raw) {
  if (!Array.isArray(raw)) return [];
  const chapters = [];
  for (let i = 0; i < raw.length && chapters.length < MAX_CHAPTERS; i += 1) {
    const item = raw[i];
    if (!item || typeof item !== "object") continue;
    const title = optionalString(item.title, CHAPTER_TITLE_MAX);
    const body = optionalString(item.body, CHAPTER_BODY_MAX);
    if (title === null || body === null) continue;
    const id = validString(item.id, 64, 1) ? item.id.trim() : `ch-${i + 1}`;
    chapters.push({ id, title, body, index: chapters.length });
  }
  return chapters;
}

function sanitizeNamedEntries(raw, max) {
  if (!Array.isArray(raw)) return [];
  const entries = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const name = optionalString(item.name, ENTRY_NAME_MAX);
    const description = optionalString(item.description, ENTRY_DESCRIPTION_MAX);
    if (!name) continue;
    if (description === null) continue;
    entries.push({ name, description: description || "" });
    if (entries.length >= max) break;
  }
  return entries;
}

function emptyContent() {
  return {
    pages: [],
    images: [],
    body: "",
    chapters: [],
    name: "",
    personality: "",
    abilities: "",
    background: "",
    image: null,
    lore: "",
    locations: [],
    factions: [],
    characters: [],
  };
}

function mergeContent(existing, input, type) {
  const current = { ...emptyContent(), ...(existing || {}) };
  const next = { ...current };
  if (type === "manga") {
    next.pages = sanitizePages(current.pages, input.pageIds, input.pageCaptions);
  }
  if (type === "drawing" || type === "other") {
    next.images = sanitizeImages(current.images, input.imageIds);
  }
  if (type === "story" || type === "other") {
    const body = optionalString(input.body ?? current.body, STORY_BODY_MAX);
    if (body !== null) next.body = body;
    if (input.chapters !== undefined) next.chapters = sanitizeChapters(input.chapters);
  }
  if (type === "character" || type === "aiCharacter") {
    const name = optionalString(input.name ?? current.name, MAX_NAME);
    const personality = optionalString(input.personality ?? current.personality, MAX_PERSONALITY);
    const abilities = optionalString(input.abilities ?? current.abilities, MAX_ABILITIES);
    const background = optionalString(input.background ?? current.background, MAX_BACKGROUND);
    if (name !== null) next.name = name;
    if (personality !== null) next.personality = personality;
    if (abilities !== null) next.abilities = abilities;
    if (background !== null) next.background = background;
  }
  if (type === "worldbuilding") {
    const lore = optionalString(input.lore ?? current.lore, LORE_MAX);
    if (lore !== null) next.lore = lore;
    if (input.locations !== undefined) {
      next.locations = sanitizeNamedEntries(input.locations, MAX_LOCATIONS);
    }
    if (input.factions !== undefined) {
      next.factions = sanitizeNamedEntries(input.factions, MAX_FACTIONS);
    }
    if (input.characters !== undefined) {
      next.characters = sanitizeNamedEntries(input.characters, MAX_WORLD_CHARACTERS);
    }
  }
  return next;
}

function publishValidationError(work) {
  const title = typeof work.title === "string" ? work.title.trim() : "";
  if (title.length < TITLE_MIN || title.length > TITLE_MAX) {
    return "A title between 3 and 80 characters is required.";
  }
  if (!TYPES.includes(work.type)) {
    return "A valid Fan Work type is required.";
  }
  const content = work.content || {};
  const cover = work.cover;
  const tags = Array.isArray(work.tags) ? work.tags : [];
  if (tags.length > MAX_TAGS) return "Too many tags.";
  if (work.visibility && work.visibility !== "public" && work.visibility !== "unpublished") {
    return "Visibility is invalid.";
  }
  if (work.type === "manga") {
    const pages = Array.isArray(content.pages) ? content.pages : [];
    if (pages.length < 1) return "Manga needs at least one page.";
    if (pages.length > MAX_PAGES) return "Manga has too many pages.";
    for (let i = 0; i < pages.length; i += 1) {
      if (!pages[i] || !pages[i].path || pages[i].index !== i) {
        return "Manga pages must be ordered media references.";
      }
    }
  }
  if (work.type === "drawing") {
    const images = Array.isArray(content.images) ? content.images : [];
    if (images.length < 1 && !(cover && cover.path)) {
      return "A drawing needs at least one image.";
    }
    if (images.length > MAX_IMAGES) return "Too many drawing images.";
  }
  if (work.type === "story") {
    const body = typeof content.body === "string" ? content.body.trim() : "";
    const chapters = Array.isArray(content.chapters) ? content.chapters : [];
    const chapterText = chapters.some((chapter) =>
      typeof chapter.body === "string" && chapter.body.trim().length >= MIN_STORY_CHARS);
    if (body.length < MIN_STORY_CHARS && !chapterText) {
      return "A story needs written content.";
    }
    if (body.length > STORY_BODY_MAX) return "Story content is too long.";
    if (chapters.length > MAX_CHAPTERS) return "Too many chapters.";
  }
  if (work.type === "character" || work.type === "aiCharacter") {
    const name = typeof content.name === "string" ? content.name.trim() : "";
    const description = typeof work.description === "string" ? work.description.trim() : "";
    const background = typeof content.background === "string" ? content.background.trim() : "";
    if (name.length < 2) return "A character name is required.";
    if (description.length < 10 && background.length < 10) {
      return "A character needs a description or background.";
    }
  }
  if (work.type === "worldbuilding") {
    const lore = typeof content.lore === "string" ? content.lore.trim() : "";
    const description = typeof work.description === "string" ? work.description.trim() : "";
    if (lore.length < MIN_STORY_CHARS && description.length < MIN_STORY_CHARS) {
      return "Worldbuilding needs lore or a description.";
    }
  }
  if (work.type === "other") {
    const description = typeof work.description === "string" ? work.description.trim() : "";
    const body = typeof content.body === "string" ? content.body.trim() : "";
    const images = Array.isArray(content.images) ? content.images : [];
    const hasMedia = images.length > 0 || (cover && cover.path);
    if (description.length < MIN_OTHER_CHARS && body.length < MIN_OTHER_CHARS && !hasMedia) {
      return "This work needs a description, written content, or media.";
    }
  }
  return null;
}

function isPubliclyListed(work) {
  return work &&
    work.status === "published" &&
    work.moderationStatus === "approved" &&
    work.visibility === "public";
}

async function creatorSnapshot(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  const data = (snap.exists && snap.data()) || {};
  return {
    username: typeof data.username === "string" ? data.username.slice(0, 48) : "",
    avatarUrl: typeof data.avatarUrl === "string" ? data.avatarUrl.slice(0, 512) : "",
  };
}

async function notifySafe(notificationBuilder, payload) {
  if (!notificationBuilder || typeof notificationBuilder.build !== "function") return;
  try {
    await notificationBuilder.build(payload);
  } catch (_) {
    // Notifications must never roll back a successful Fan Work mutation.
  }
}

async function readMediaMetadata(storage, path) {
  if (!storage) return { contentType: "image/jpeg", size: 1 };
  if (typeof storage.metadata === "function") {
    const meta = await storage.metadata(path);
    if (!meta) return null;
    return {
      contentType: meta.contentType || "",
      size: Number(meta.size) || 0,
    };
  }
  if (typeof storage.file === "function") {
    try {
      const file = storage.file(path);
      if (typeof file.exists === "function") {
        const existsResult = await file.exists();
        const exists = Array.isArray(existsResult) ? existsResult[0] : existsResult;
        if (!exists) return null;
      }
      if (typeof file.getMetadata === "function") {
        const result = await file.getMetadata();
        const meta = Array.isArray(result) ? result[0] : result;
        return {
          contentType: meta?.contentType || "",
          size: Number(meta?.size) || 0,
        };
      }
      return { contentType: "image/jpeg", size: 1 };
    } catch (_) {
      return null;
    }
  }
  return { contentType: "image/jpeg", size: 1 };
}

function createFanWorksDomain({
  db,
  FieldValue,
  HttpsError,
  notificationBuilder,
  storage,
}) {
  async function saveFanWorkDraft(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const type = TYPES.includes(input.type) ? input.type : null;
    if (!type) {
      throw new HttpsError("invalid-argument", "A valid Fan Work type is required.");
    }
    const title = optionalString(input.title ?? "", TITLE_MAX);
    if (title === null) {
      throw new HttpsError("invalid-argument", "Title is too long.");
    }
    const description = optionalString(input.description ?? "", DESCRIPTION_MAX);
    if (description === null) {
      throw new HttpsError("invalid-argument", "Description is too long.");
    }
    const animeId = optionalString(input.animeId ?? "", MAX_ANIME_ID);
    const animeTitle = optionalString(input.animeTitle ?? "", MAX_ANIME_TITLE);
    if (animeId === null || animeTitle === null) {
      throw new HttpsError("invalid-argument", "Anime reference is invalid.");
    }
    const tags = normalizeTags(input.tags);
    const characterIds = normalizeCharacterIds(input.characterIds);
    const existingId = validString(input.workId, 128) ? input.workId.trim() : null;
    const ref = existingId ? workRef(db, existingId) : db.collection("fanWorks").doc();
    const snapshot = await creatorSnapshot(db, uid);

    await db.runTransaction(async (transaction) => {
      const existing = await transaction.get(ref);
      if (existing.exists) {
        const current = existing.data() || {};
        if (current.creatorId !== uid) {
          throw new HttpsError("permission-denied", "You cannot edit this Fan Work.");
        }
        if (current.status !== "draft") {
          throw new HttpsError("failed-precondition", "Only drafts can be edited.");
        }
        const content = mergeContent(current.content, input, type);
        const update = {
          type,
          title,
          description,
          tags,
          animeId,
          animeTitle,
          characterIds,
          content,
          creatorSnapshot: snapshot,
          searchTitle: title.toLowerCase(),
          updatedAt: FieldValue.serverTimestamp(),
          version: (Number(current.version) || 1) + 1,
          schemaVersion: SCHEMA_VERSION,
        };
        if (input.clearCover === true) update.cover = null;
        transaction.update(ref, update);
        return;
      }
      transaction.create(ref, {
        creatorId: uid,
        creatorSnapshot: snapshot,
        type,
        title,
        description,
        cover: null,
        content: mergeContent(emptyContent(), input, type),
        tags,
        animeId,
        animeTitle,
        characterIds,
        visibility: "unpublished",
        status: "draft",
        moderationStatus: "pending",
        likesCount: 0,
        bookmarksCount: 0,
        reportsCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        publishedAt: null,
        version: 1,
        schemaVersion: SCHEMA_VERSION,
        searchTitle: title.toLowerCase(),
      });
    });
    return { workId: ref.id };
  }

  async function publishFanWork(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    let alreadyPublished = false;
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot publish this Fan Work.");
      }
      if (current.status === "published") {
        alreadyPublished = true;
        return;
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Only drafts can be published.");
      }
      const error = publishValidationError(current);
      if (error) throw new HttpsError("failed-precondition", error);
      transaction.update(ref, {
        status: "published",
        visibility: "public",
        moderationStatus: "approved",
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        version: (Number(current.version) || 1) + 1,
      });
    });
    return { workId, alreadyPublished };
  }

  async function archiveFanWork(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot archive this Fan Work.");
      }
      if (current.status === "archived") return;
      if (current.status !== "published") {
        throw new HttpsError("failed-precondition", "Only published Fan Works can be archived.");
      }
      transaction.update(ref, {
        status: "archived",
        visibility: "unpublished",
        updatedAt: FieldValue.serverTimestamp(),
        archivedAt: FieldValue.serverTimestamp(),
        version: (Number(current.version) || 1) + 1,
      });
    });
    return { ok: true };
  }

  async function deleteFanWorkDraft(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) return;
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot delete this Fan Work.");
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Only drafts can be deleted.");
      }
      transaction.delete(ref);
    });
    return { ok: true };
  }

  async function startFanWorkMediaUpload(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const contentType = typeof request.data?.contentType === "string"
      ? request.data.contentType.trim().toLowerCase()
      : "";
    const ext = ALLOWED_MIME[contentType];
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    if (!ext) {
      throw new HttpsError("invalid-argument", "Unsupported image type.");
    }
    const ref = workRef(db, workId);
    await db.runTransaction(async (transaction) => {
      const currentSnap = await transaction.get(ref);
      if (!currentSnap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = currentSnap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot upload media for this Fan Work.");
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Media can only be added to drafts.");
      }
    });
    const mediaId = db.collection("fanWorks").doc().id;
    const path = `fan_works/${uid}/${workId}/${mediaId}.${ext}`;
    return { workId, mediaId, path, contentType };
  }

  async function confirmFanWorkMedia(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const workId = validString(input.workId, 128) ? input.workId.trim() : null;
    const mediaId = validString(input.mediaId, MAX_MEDIA_ID) ? input.mediaId.trim() : null;
    const path = typeof input.path === "string" ? input.path.trim() : "";
    const role = MEDIA_ROLES.includes(input.role) ? input.role : null;
    const caption = optionalString(input.caption ?? "", MAX_CAPTION);
    if (!workId || !mediaId || !role) {
      throw new HttpsError("invalid-argument", "Media confirmation data is invalid.");
    }
    if (caption === null) {
      throw new HttpsError("invalid-argument", "Caption is too long.");
    }
    assertOwnedPath(uid, workId, path, HttpsError);
    const meta = await readMediaMetadata(storage, path);
    if (!meta) {
      throw new HttpsError("failed-precondition", "Upload the file before confirming it.");
    }
    if (!ALLOWED_MIME[meta.contentType]) {
      throw new HttpsError("invalid-argument", "Unsupported image type.");
    }
    if (meta.size > 10 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "That image is too large.");
    }
    const ref = workRef(db, workId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot attach media to this Fan Work.");
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Media can only be added to drafts.");
      }
      const media = { mediaId, path, contentType: meta.contentType };
      const content = { ...emptyContent(), ...(current.content || {}) };
      if (role === "cover") {
        transaction.update(ref, {
          cover: media,
          updatedAt: FieldValue.serverTimestamp(),
          version: (Number(current.version) || 1) + 1,
        });
        return;
      }
      if (role === "page") {
        const pages = Array.isArray(content.pages) ? [...content.pages] : [];
        const existingIndex = pages.findIndex((page) => page.mediaId === mediaId);
        if (existingIndex >= 0) {
          pages[existingIndex] = { ...media, index: existingIndex, caption };
        } else {
          if (pages.length >= MAX_PAGES) {
            throw new HttpsError("failed-precondition", "Manga has too many pages.");
          }
          pages.push({ ...media, index: pages.length, caption });
        }
        content.pages = pages.map((page, index) => ({ ...page, index }));
      } else if (role === "image" && (current.type === "character" || current.type === "aiCharacter")) {
        content.image = media;
      } else {
        const images = Array.isArray(content.images) ? [...content.images] : [];
        if (!images.some((image) => image.mediaId === mediaId)) {
          if (images.length >= MAX_IMAGES) {
            throw new HttpsError("failed-precondition", "Too many images.");
          }
          images.push(media);
        }
        content.images = images;
      }
      transaction.update(ref, {
        content,
        updatedAt: FieldValue.serverTimestamp(),
        version: (Number(current.version) || 1) + 1,
      });
    });
    return { ok: true, mediaId, path };
  }

  async function likeFanWork(request) {
    const actor = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const shouldLike = request.data?.like !== false;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    const likeRef = ref.collection("likes").doc(actor);
    let creatorId = "";
    let title = "";
    let createdLike = false;
    await db.runTransaction(async (transaction) => {
      const [work, existing] = await Promise.all([transaction.get(ref), transaction.get(likeRef)]);
      if (!work.exists || !isPubliclyListed(work.data())) {
        throw new HttpsError("not-found", "Fan Work not found.");
      }
      creatorId = work.data().creatorId;
      title = work.data().title || "";
      const alreadyLiked = Boolean(existing && existing.exists);
      if (shouldLike && !alreadyLiked) {
        transaction.create(likeRef, {
          userId: actor,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.update(ref, { likesCount: FieldValue.increment(1) });
        createdLike = true;
      } else if (!shouldLike && existing.exists) {
        transaction.delete(likeRef);
        transaction.update(ref, { likesCount: FieldValue.increment(-1) });
      }
    });
    if (createdLike && creatorId && creatorId !== actor) {
      await notifySafe(notificationBuilder, {
        id: `fan-work-like-${workId}-${actor}`,
        recipientIds: [creatorId],
        type: "fan_work_liked",
        actorId: actor,
        targetId: workId,
        action: "liked",
        destination: `/fan-work/${workId}`,
        metadata: { workId },
        title: "New like on your Fan Work",
        body: title || "Someone liked your Fan Work.",
        pushWorthy: false,
      });
    }
    return { ok: true };
  }

  async function bookmarkFanWork(request) {
    const actor = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const shouldBookmark = request.data?.bookmark !== false;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    const bookmarkRef = ref.collection("bookmarks").doc(actor);
    await db.runTransaction(async (transaction) => {
      const [work, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(bookmarkRef),
      ]);
      if (!work.exists || !isPubliclyListed(work.data())) {
        throw new HttpsError("not-found", "Fan Work not found.");
      }
      if (shouldBookmark && !existing.exists) {
        transaction.create(bookmarkRef, {
          userId: actor,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.update(ref, { bookmarksCount: FieldValue.increment(1) });
      } else if (!shouldBookmark && existing.exists) {
        transaction.delete(bookmarkRef);
        transaction.update(ref, { bookmarksCount: FieldValue.increment(-1) });
      }
    });
    return { ok: true };
  }

  async function reportFanWork(request) {
    const reporterId = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const reason = REPORT_REASONS.includes(request.data?.reason) ? request.data.reason : null;
    const details = optionalString(request.data?.details ?? "", 500);
    if (!workId || !reason) {
      throw new HttpsError("invalid-argument", "A structured report reason is required.");
    }
    if (details === null) {
      throw new HttpsError("invalid-argument", "Report details are too long.");
    }
    const ref = workRef(db, workId);
    const reportId = `${workId}_${reporterId}`;
    const reportRef = ref.collection("reports").doc(reportId);
    await db.runTransaction(async (transaction) => {
      const [work, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(reportRef),
      ]);
      if (!work.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = work.data() || {};
      if (current.creatorId === reporterId) {
        throw new HttpsError("failed-precondition", "You cannot report your own Fan Work.");
      }
      if (current.status !== "published") {
        throw new HttpsError("failed-precondition", "Only published Fan Works can be reported.");
      }
      if (existing.exists) return;
      transaction.create(reportRef, {
        reporterId,
        reason,
        details,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(ref, {
        reportsCount: FieldValue.increment(1),
        moderationStatus: "flagged",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  return {
    saveFanWorkDraft,
    publishFanWork,
    archiveFanWork,
    deleteFanWorkDraft,
    startFanWorkMediaUpload,
    confirmFanWorkMedia,
    likeFanWork,
    bookmarkFanWork,
    reportFanWork,
    TYPES,
    REPORT_REASONS,
    publishValidationError,
    normalizeTags,
  };
}

module.exports = {
  createFanWorksDomain,
  TYPES,
  REPORT_REASONS,
  SCHEMA_VERSION,
  publishValidationError,
  normalizeTags,
};
