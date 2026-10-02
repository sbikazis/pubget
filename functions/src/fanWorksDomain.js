"use strict";

// The type list, category gate, media roles, MIME table, size ceilings, and
// content shape all live in `fanWorksSchema.js` so the server has exactly one
// definition and it is the same one `fanWorksTaxonomy.js` exposes to the picker.
const {
  SCHEMA_VERSION,
  TITLE_MAX,
  DESCRIPTION_MAX,
  MAX_TAGS,
  MAX_ANIME_ID,
  MAX_ANIME_TITLE,
  MAX_CAPTION,
  MEDIA_ROLES,
  ALLOWED_IMAGE_MIME,
  DOCUMENT_MIME,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
  MAX_CAST,
  MAX_MEDIA_ID,
  MAX_PATH,
  isDocumentRole,
  maxBytesForMime,
  allowedMimeForRole,
  mimeAllowedForRole,
  extensionForMime,
  roleAllowedForType,
  emptyContentFor,
  mergeContent: mergeTypeContent,
  upgradeLegacyWork,
  publishValidationError: typePublishValidationError,
  canonicalType,
  normalizeCategory,
  normalizeOrigin,
} = require("./fanWorksSchema");

const {
  CREATABLE_TYPES,
  isKnownType,
} = require("./fanWorksTaxonomy");

/** Read-facing type list, including the legacy read-only values. */
const TYPES = Object.freeze(require("./fanWorksTaxonomy").ALL_TYPES);

const REPORT_REASONS = Object.freeze([
  "inappropriate",
  "spam",
  "copyright",
  "harassment",
  "other",
]);

const TITLE_MIN = 3;
const TAG_MIN = 2;
const TAG_MAX = 24;
const MIN_STORY_CHARS = 20;
const COMMENT_MAX = 500;
const COMMENT_COOLDOWN_MS = 2000;

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

function normalizeCopyright(raw) {
  if (!raw || typeof raw !== "object") {
    return {
      originalWorkId: "",
      sourceTitle: "",
      credit: "",
      license: "fan-work",
    };
  }
  return {
    originalWorkId: optionalString(raw.originalWorkId ?? "", 128) || "",
    sourceTitle: optionalString(raw.sourceTitle ?? "", 200) || "",
    credit: optionalString(raw.credit ?? "", 200) || "",
    license: optionalString(raw.license ?? "fan-work", 64) || "fan-work",
  };
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

function emptyContent(type) {
  return emptyContentFor(type);
}

/**
 * Normalizes the client's draft payload into the stored content for `type`.
 * The type check and slot assignment both live in the schema module.
 */
function mergeContent(existing, input, type) {
  return mergeTypeContent(existing, input, type);
}

/**
 * Publish-time completeness for the v2 shape.
 */
function publishValidationError(work) {
  return typePublishValidationError(upgradeLegacyWork(work));
}

function isPubliclyListed(work) {
  return work &&
    work.status === "published" &&
    work.moderationStatus === "approved" &&
    work.visibility === "public";
}

function extractMentions(text) {
  const matches = String(text || "").match(/@([A-Za-z0-9_]{2,32})/g) || [];
  const seen = new Set();
  const out = [];
  for (const raw of matches) {
    const handle = raw.slice(1).toLowerCase();
    if (seen.has(handle)) continue;
    seen.add(handle);
    out.push(handle);
    if (out.length >= 8) break;
  }
  return out;
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
  signer,
  economy,
  achievements,
}) {
  async function saveFanWorkDraft(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    // Only the four creatable types may be written. A legacy read-only type in
    // the payload is refused rather than silently accepted, because accepting
    // it would let a client create something the picker cannot produce.
    const type = CREATABLE_TYPES.includes(input.type) ? input.type : null;
    if (!type) {
      throw new HttpsError(
        "invalid-argument",
        "Type must be one of manga, story, drawing, or character.",
      );
    }
    const category = normalizeCategory(type, input.category ?? "");
    const origin = normalizeOrigin(input.origin);
    const title = optionalString(input.title ?? "", TITLE_MAX);
    if (title === null) {
      throw new HttpsError("invalid-argument", "Title is too long.");
    }
    const description = optionalString(input.description ?? "", DESCRIPTION_MAX);
    if (description === null) {
      throw new HttpsError("invalid-argument", "Description is too long.");
    }
    const creatorNote = optionalString(input.creatorNote ?? "", 1000);
    const animeId = optionalString(input.animeId ?? "", MAX_ANIME_ID);
    const animeTitle = optionalString(input.animeTitle ?? "", MAX_ANIME_TITLE);
    if (animeId === null || animeTitle === null || creatorNote === null) {
      throw new HttpsError("invalid-argument", "Fan Work metadata is invalid.");
    }
    const tags = normalizeTags(input.tags);
    const characterIds = normalizeCharacterIds(input.characterIds);
    const copyright = normalizeCopyright(input.copyright);
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
          category,
          origin,
          creatorNote,
          tags,
          animeId,
          animeTitle,
          characterIds,
          copyright,
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
        content: mergeContent(emptyContent(type), input, type),
        category,
        origin,
        creatorNote,
        tags,
        animeId,
        animeTitle,
        characterIds,
        copyright,
        visibility: "unpublished",
        status: "draft",
        moderationStatus: "pending",
        likesCount: 0,
        commentsCount: 0,
        bookmarksCount: 0,
        reportsCount: 0,
        ratingsCount: 0,
        ratingsSum: 0,
        ratingsAverage: 0,
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
    if (!alreadyPublished && economy && typeof economy.applyReward === "function") {
      await economy.applyReward({
        userId: uid,
        type: "earn_publish",
        referenceId: workId,
        source: "fan_work",
      });
    }
    if (!alreadyPublished && achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "fan_work_published",
        userId: uid,
        source: "fan_work",
        metadata: { workId },
      });
    }
    return { workId, alreadyPublished };
  }

  async function revisePublishedFanWork(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    let version = 1;
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot revise this Fan Work.");
      }
      if (current.status !== "published") {
        throw new HttpsError("failed-precondition", "Only published Fan Works can be revised.");
      }
      version = (Number(current.version) || 1) + 1;
      const revisionRef = ref.collection("revisions").doc(String(current.version || 1));
      transaction.set(revisionRef, {
        version: Number(current.version) || 1,
        title: current.title || "",
        description: current.description || "",
        content: current.content || {},
        copyright: current.copyright || normalizeCopyright({}),
        createdAt: FieldValue.serverTimestamp(),
        creatorId: uid,
      });
      const title = optionalString(request.data?.title ?? current.title ?? "", TITLE_MAX);
      const description = optionalString(
        request.data?.description ?? current.description ?? "",
        DESCRIPTION_MAX,
      );
      if (title === null || description === null) {
        throw new HttpsError("invalid-argument", "Revision text is invalid.");
      }
      transaction.update(ref, {
        title,
        description,
        copyright: normalizeCopyright(request.data?.copyright || current.copyright),
        tags: request.data?.tags ? normalizeTags(request.data.tags) : current.tags,
        updatedAt: FieldValue.serverTimestamp(),
        version,
        schemaVersion: SCHEMA_VERSION,
        searchTitle: (title || current.title || "").toLowerCase(),
      });
    });
    return { workId, version };
  }

  async function requestFanWorkRemoval(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const details = optionalString(request.data?.details ?? "", 500) || "";
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const ref = workRef(db, workId);
    const reportRef = ref.collection("reports").doc(`${workId}_${uid}_removal`);
    await db.runTransaction(async (transaction) => {
      const [snap, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(reportRef),
      ]);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      if (existing.exists) return;
      transaction.create(reportRef, {
        reporterId: uid,
        reason: "copyright",
        kind: "removal_request",
        details,
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.update(ref, {
        reportsCount: FieldValue.increment(1),
        moderationStatus: "flagged",
        removalRequested: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
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

  /**
   * Opens an upload for one media slot.
   *
   * The returned `uploadUrl` is a V4-signed URL (resumable session for a PDF, a
   * bounded `PUT` for a small image). Nothing here mints a permanent
   * `downloadToken`, and no ACL is set, so an object stays private by
   * inheritance and reading it later requires a fresh signed read grant.
   */
  async function startFanWorkMediaUpload(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const workId = validString(input.workId, 128) ? input.workId.trim() : null;
    const role = MEDIA_ROLES.includes(input.role) ? input.role : null;
    const contentType = typeof input.contentType === "string"
      ? input.contentType.trim().toLowerCase()
      : "";
    const characterId = validString(input.characterId, 64)
      ? input.characterId.trim()
      : "";
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    if (!role) throw new HttpsError("invalid-argument", "A valid media role is required.");
    if (!signer) {
      throw new HttpsError("failed-precondition", "Fan Work storage is not configured.");
    }

    let workType = null;
    const ref = workRef(db, workId);
    await db.runTransaction(async (transaction) => {
      const snap = await transaction.get(ref);
      if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
      const current = snap.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot upload media for this Fan Work.");
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Media can only be added to drafts.");
      }
      workType = canonicalType(current.type);
      if (!roleAllowedForType(workType, role)) {
        throw new HttpsError(
          "invalid-argument",
          `A ${workType} Fan Work cannot have a ${role} file.`,
        );
      }
    });

    // A cast portrait must name a member that actually exists, otherwise the
    // upload would land in the bucket with nothing pointing at it.
    if (role === "characterPortrait") {
      if (!characterId) {
        throw new HttpsError("invalid-argument", "characterId is required for a cast portrait.");
      }
      const snap = await ref.get();
      const content = (snap.data() && snap.data().content) || {};
      const cast = Array.isArray(content.characters) ? content.characters : [];
      if (!cast.some((entry) => entry && entry.id === characterId)) {
        throw new HttpsError("not-found", "That cast member is not on this Fan Work.");
      }
    }

    if (!mimeAllowedForRole(role, contentType)) {
      throw new HttpsError(
        "invalid-argument",
        role === "document"
          ? "A document must be a PDF."
          : "Only JPEG, PNG, WEBP, or GIF images are allowed.",
      );
    }

    const mediaId = db.collection("fanWorks").doc().id;
    const nonce = db.collection("fanWorks").doc().id;
    const signed = isDocumentRole(role)
      ? await signer.signResumableUpload({ userId: uid, workId, mediaId, mime: contentType, nonce })
      : await signer.signWriteUrl({ userId: uid, workId, mediaId, mime: contentType, nonce });

    return {
      workId,
      mediaId,
      role,
      contentType,
      path: signed.path,
      uploadUrl: isDocumentRole(role) ? signed.sessionUri : signed.url,
      maxBytes: signed.maxBytes || maxBytesForMime(contentType),
      expiresAt: signed.expiresAt || Date.now() + 15 * 60 * 1000,
    };
  }

  /**
   * Attaches a previously uploaded object to its slot.
   *
   * The bytes are not re-checked against a client claim: the size and MIME come
   * from the object's own metadata, so a client cannot lie about either. A
   * PDF's page count is taken from the metadata when the uploader recorded it
   * and left null otherwise, because counting pages server-side would mean
   * parsing an untrusted PDF.
   */
  async function confirmFanWorkMedia(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const workId = validString(input.workId, 128) ? input.workId.trim() : null;
    const mediaId = validString(input.mediaId, MAX_MEDIA_ID) ? input.mediaId.trim() : null;
    const path = typeof input.path === "string" ? input.path.trim() : "";
    const role = MEDIA_ROLES.includes(input.role) ? input.role : null;
    const characterId = validString(input.characterId, 64) ? input.characterId.trim() : "";
    const caption = optionalString(input.caption ?? "", MAX_CAPTION);
    if (!workId || !mediaId || !role || !path) {
      throw new HttpsError("invalid-argument", "Media confirmation data is invalid.");
    }
    if (caption === null) {
      throw new HttpsError("invalid-argument", "Caption is too long.");
    }
    if (role === "characterPortrait" && !characterId) {
      throw new HttpsError("invalid-argument", "characterId is required for a cast portrait.");
    }
    assertOwnedPath(uid, workId, path, HttpsError);

    const meta = await readMediaMetadata(storage, path);
    if (!meta) {
      throw new HttpsError("failed-precondition", "Upload the file before confirming it.");
    }
    const actualType = String(meta.contentType || "").toLowerCase();
    if (role === "document") {
      if (actualType !== DOCUMENT_MIME) {
        throw new HttpsError("invalid-argument", "A document must be a PDF.");
      }
      if (meta.size > DOCUMENT_MAX_BYTES) {
        throw new HttpsError("invalid-argument", "A PDF must be 50 MB or smaller.");
      }
    } else {
      if (!ALLOWED_IMAGE_MIME[actualType]) {
        throw new HttpsError("invalid-argument", "That file is not an allowed image type.");
      }
      if (meta.size > IMAGE_MAX_BYTES) {
        throw new HttpsError("invalid-argument", "An image must be 12 MB or smaller.");
      }
    }

    const ref = workRef(db, workId);
    let confirmed = null;
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
      const type = canonicalType(current.type);
      if (!roleAllowedForType(type, role)) {
        throw new HttpsError(
          "invalid-argument",
          `A ${type} Fan Work cannot have a ${role} file.`,
        );
      }
      const content = mergeContent(current.content, {}, type);
      const media = { mediaId, path, contentType: actualType };

      if (role === "cover") {
        transaction.update(ref, {
          cover: media,
          updatedAt: FieldValue.serverTimestamp(),
          version: (Number(current.version) || 1) + 1,
        });
        confirmed = media;
        return;
      }

      if (role === "document") {
        const pageCount = Number(input.pageCount);
        content.document = Number.isInteger(pageCount) && pageCount > 0
          ? { ...media, pageCount }
          : media;
      } else if (role === "artwork") {
        content.artwork = media;
      } else if (role === "portrait") {
        content.portrait = media;
      } else if (role === "characterPortrait") {
        const cast = Array.isArray(content.characters) ? content.characters : [];
        const index = cast.findIndex((entry) => entry && entry.id === characterId);
        if (index < 0) {
          throw new HttpsError("not-found", "That cast member is not on this Fan Work.");
        }
        if (cast.length >= MAX_CAST && index < 0) {
          throw new HttpsError("failed-precondition", "This Fan Work has too many cast members.");
        }
        cast[index] = {
          ...cast[index],
          image: { ...media, ...(caption ? { caption } : {}) },
        };
        content.characters = cast.map((entry, position) => ({ ...entry, index: position }));
      }

      transaction.update(ref, {
        content,
        updatedAt: FieldValue.serverTimestamp(),
        version: (Number(current.version) || 1) + 1,
      });
      confirmed = media;
    });
    return { ok: true, mediaId, path: confirmed.path, contentType: confirmed.contentType };
  }

  /**
   * Mints a short-lived inline read URL for a document.
   *
   * Authorization is checked on every call: the owner can read their own draft,
   * anyone can read a published, approved, public work, and nobody can read a
   * flagged or removed one. The response is a bearer credential for a few
   * minutes and is never persisted.
   */
  async function getFanWorkDocumentAccess(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    if (!signer) {
      throw new HttpsError("failed-precondition", "Fan Work storage is not configured.");
    }
    const snap = await workRef(db, workId).get();
    if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
    const work = snap.data() || {};
    const type = canonicalType(work.type);
    const content = work.content || {};

    // Legacy page-image manga has no document at all; the client routes those to
    // the image viewer instead, so refusing here keeps the two paths disjoint.
    const document = content.document;
    if (!document || !document.path) {
      throw new HttpsError("failed-precondition", "This Fan Work has no PDF document.");
    }
    if (type !== "manga" && type !== "story") {
      throw new HttpsError("failed-precondition", "This Fan Work has no PDF document.");
    }

    const isOwner = work.creatorId === uid;
    const isReadable = work.status === "published" &&
      work.moderationStatus === "approved" &&
      work.visibility === "public";
    if (!isOwner && !isReadable) {
      throw new HttpsError("permission-denied", "You cannot read this Fan Work.");
    }
    if (work.status === "published" && work.moderationStatus === "removed") {
      throw new HttpsError("permission-denied", "You cannot read this Fan Work.");
    }

    const signed = await signer.signReadUrl({ path: document.path, inline: true });
    return {
      workId,
      url: signed.url,
      expiresAt: signed.expiresAt,
      pageCount: Number.isInteger(document.pageCount) ? document.pageCount : null,
    };
  }

  /**
   * Records how far the reader got.
   *
   * Progress only ever moves forward: a rewind on the client must not lower the
   * stored value, otherwise "continue reading" would jump backwards after any
   * correction. The stored page is clamped to the document's page count.
   */
  async function saveFanWorkReadingProgress(request) {
    const uid = requireAuth(request, HttpsError);
    const input = request.data || {};
    const workId = validString(input.workId, 128) ? input.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const snap = await workRef(db, workId).get();
    if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
    const work = snap.data() || {};
    if (!canReadWork(work, uid)) {
      throw new HttpsError("permission-denied", "You cannot read this Fan Work.");
    }
    const content = work.content || {};
    const totalRaw = Number(input.pageCount);
    const total = Number.isInteger(totalRaw) && totalRaw > 0
      ? totalRaw
      : (Number.isInteger(content.document?.pageCount) ? content.document.pageCount : null);
    let page = Number(input.page);
    if (!Number.isInteger(page) || page < 0) page = 0;
    if (total) page = Math.min(page, total - 1);
    const ratioRaw = Number(input.progress);
    const progress = total && total > 0
      ? Math.min(Math.max(page / (total - 1 || 1), 0), 1)
      : Number.isFinite(ratioRaw) ? Math.min(Math.max(ratioRaw, 0), 1) : 0;

    const ref = workRef(db, workId).collection("readingProgress").doc(uid);
    const existing = await ref.get();
    const previous = existing.exists ? (existing.data() || {}) : {};
    const previousPage = Number(previous.page) || 0;
    // Monotonic: never move a stored position backwards.
    const nextPage = Math.max(page, previousPage);
    const nextProgress = Math.max(progress, Number(previous.progress) || 0);
    await ref.set({
      userId: uid,
      workId,
      page: nextPage,
      pageCount: total ?? null,
      progress: nextProgress,
      completed: Boolean(previous.completed),
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, page: nextPage, progress: nextProgress };
  }

  /**
   * Flags a work as finished. Sets `completed` rather than clearing progress, so
   * "read" survives a later rewind.
   */
  async function markFanWorkAsRead(request) {
    const uid = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    if (!workId) throw new HttpsError("invalid-argument", "workId is required.");
    const snap = await workRef(db, workId).get();
    if (!snap.exists) throw new HttpsError("not-found", "Fan Work not found.");
    const work = snap.data() || {};
    if (!canReadWork(work, uid)) {
      throw new HttpsError("permission-denied", "You cannot read this Fan Work.");
    }
    const ref = workRef(db, workId).collection("readingProgress").doc(uid);
    const existing = await ref.get();
    const previous = existing.exists ? (existing.data() || {}) : {};
    const content = work.content || {};
    const totalRaw = Number(previous.pageCount);
    const total = Number.isInteger(totalRaw) && totalRaw > 0
      ? totalRaw
      : (Number.isInteger(content.document?.pageCount) ? content.document.pageCount : null);
    await ref.set({
      userId: uid,
      workId,
      page: total ? total - 1 : Number(previous.page) || 0,
      pageCount: total ?? null,
      progress: 1,
      completed: true,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, completed: true };
  }

  /** Owner, or a reader on a live public work. Removed works are never readable. */
  function canReadWork(work, uid) {
    if (!work) return false;
    if (work.creatorId === uid) return work.status !== "archived";
    return work.status === "published" &&
      work.moderationStatus === "approved" &&
      work.visibility === "public";
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

  async function rateFanWork(request) {
    const actor = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const rating = Number(request.data?.rating);
    if (!workId || !Number.isInteger(rating) || rating < 1 || rating > 10) {
      throw new HttpsError("invalid-argument", "Rating must be an integer from 1 to 10.");
    }
    const ref = workRef(db, workId);
    const ratingRef = ref.collection("ratings").doc(actor);
    await db.runTransaction(async (transaction) => {
      const [work, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(ratingRef),
      ]);
      if (!work.exists || !isPubliclyListed(work.data())) {
        throw new HttpsError("not-found", "Fan Work not found.");
      }
      const current = work.data() || {};
      let count = Number(current.ratingsCount) || 0;
      let sum = Number(current.ratingsSum) || 0;
      const previous = existing.exists ? Number(existing.data()?.rating) : 0;
      if (existing.exists && previous === rating) return;
      if (existing.exists) {
        sum -= previous;
      } else {
        count += 1;
      }
      sum += rating;
      transaction.set(ratingRef, {
        userId: actor,
        rating,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(ref, {
        ratingsCount: count,
        ratingsSum: sum,
        ratingsAverage: count > 0 ? Math.round((sum / count) * 10) / 10 : 0,
      });
    });
    return { ok: true, rating };
  }

  async function commentFanWork(request) {
    const authorId = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const text = validString(request.data?.text, COMMENT_MAX) ? request.data.text.trim() : null;
    const replyRaw = request.data?.replyToCommentId;
    const replyToCommentId = replyRaw == null || replyRaw === ""
      ? null
      : (validString(replyRaw, 128) ? String(replyRaw).trim() : null);
    if (replyRaw && !replyToCommentId) {
      throw new HttpsError("invalid-argument", "Reply target is invalid.");
    }
    const eventId = validString(request.data?.eventId, 128)
      ? request.data.eventId.trim()
      : null;
    if (!workId || !text) {
      throw new HttpsError("invalid-argument", "A comment is required.");
    }
    const ref = workRef(db, workId);
    const commentRef = eventId
      ? ref.collection("comments").doc(eventId)
      : ref.collection("comments").doc();
    const rateRef = ref.collection("commentRate").doc(authorId);
    let created = false;
    let creatorId = "";
    let title = "";
    await db.runTransaction(async (transaction) => {
      const [work, existing, rate] = await Promise.all([
        transaction.get(ref),
        transaction.get(commentRef),
        transaction.get(rateRef),
      ]);
      if (!work.exists || !isPubliclyListed(work.data())) {
        throw new HttpsError("not-found", "Fan Work not found.");
      }
      creatorId = work.data().creatorId || "";
      title = work.data().title || "";
      if (existing.exists) {
        if (existing.data()?.authorId !== authorId) {
          throw new HttpsError("already-exists", "That comment id is already used.");
        }
        return;
      }
      const lastAtMs = Number(rate.data()?.lastAtMs) || 0;
      if (lastAtMs && Date.now() - lastAtMs < COMMENT_COOLDOWN_MS) {
        throw new HttpsError("resource-exhausted", "Wait a moment before commenting again.");
      }
      if (replyToCommentId) {
        const parent = await transaction.get(ref.collection("comments").doc(replyToCommentId));
        if (!parent.exists) {
          throw new HttpsError("not-found", "The comment you are replying to is gone.");
        }
      }
      transaction.create(commentRef, {
        authorId,
        text,
        likesCount: 0,
        replyToCommentId,
        mentions: extractMentions(text),
        createdAt: FieldValue.serverTimestamp(),
      });
      transaction.set(rateRef, {
        userId: authorId,
        lastAtMs: Date.now(),
        lastText: text,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(ref, {
        commentsCount: FieldValue.increment(1),
      });
      created = true;
    });
    if (created && creatorId && creatorId !== authorId) {
      await notifySafe(notificationBuilder, {
        id: `fan-work-comment-${workId}-${commentRef.id}`,
        recipientIds: [creatorId],
        type: "fan_work_commented",
        actorId: authorId,
        targetId: workId,
        action: "commented",
        destination: `/fan-work/${workId}`,
        metadata: { workId, commentId: commentRef.id },
        title: "New comment on your Fan Work",
        body: title || "Someone commented on your Fan Work.",
        pushWorthy: false,
      });
    }
    return { commentId: commentRef.id };
  }

  async function fanWorkCommentAction(request) {
    const actor = requireAuth(request, HttpsError);
    const workId = validString(request.data?.workId, 128) ? request.data.workId.trim() : null;
    const commentId = validString(request.data?.commentId, 128)
      ? request.data.commentId.trim()
      : null;
    const action = request.data?.action;
    if (!workId || !commentId || !["like", "unlike", "delete", "report"].includes(action)) {
      throw new HttpsError("invalid-argument", "Comment action is invalid.");
    }
    const ref = workRef(db, workId);
    const commentRef = ref.collection("comments").doc(commentId);
    await db.runTransaction(async (transaction) => {
      const [work, comment] = await Promise.all([
        transaction.get(ref),
        transaction.get(commentRef),
      ]);
      if (!work.exists || !isPubliclyListed(work.data())) {
        throw new HttpsError("not-found", "Fan Work not found.");
      }
      if (!comment.exists) return;
      if (action === "delete") {
        if (comment.data()?.authorId !== actor) {
          throw new HttpsError("permission-denied", "Only the author can delete this comment.");
        }
        transaction.delete(commentRef);
        transaction.update(ref, {
          commentsCount: FieldValue.increment(-1),
        });
        return;
      }
      if (action === "report") {
        const reportRef = commentRef.collection("reports").doc(actor);
        const existing = await transaction.get(reportRef);
        if (existing.exists) return;
        if (comment.data()?.authorId === actor) {
          throw new HttpsError("failed-precondition", "You cannot report your own comment.");
        }
        transaction.create(reportRef, {
          reporterId: actor,
          createdAt: FieldValue.serverTimestamp(),
        });
        transaction.update(commentRef, { reported: true });
        return;
      }
      const likeRef = commentRef.collection("likes").doc(actor);
      const existing = await transaction.get(likeRef);
      if (action === "like" && !existing.exists) {
        transaction.create(likeRef, { actor, createdAt: FieldValue.serverTimestamp() });
        transaction.update(commentRef, { likesCount: FieldValue.increment(1) });
      } else if (action === "unlike" && existing.exists) {
        transaction.delete(likeRef);
        transaction.update(commentRef, { likesCount: FieldValue.increment(-1) });
      }
    });
    return { ok: true };
  }

  return {
    saveFanWorkDraft,
    publishFanWork,
    revisePublishedFanWork,
    requestFanWorkRemoval,
    archiveFanWork,
    deleteFanWorkDraft,
    startFanWorkMediaUpload,
    confirmFanWorkMedia,
    getFanWorkDocumentAccess,
    saveFanWorkReadingProgress,
    markFanWorkAsRead,
    likeFanWork,
    bookmarkFanWork,
    reportFanWork,
    rateFanWork,
    commentFanWork,
    fanWorkCommentAction,
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
  upgradeLegacyWork,
};
