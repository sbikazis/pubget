"use strict";

/**
 * Fan Works schema v2.
 *
 * What changed and why:
 *
 *   - `type` is restricted to the four creatable values on write. Legacy rows
 *     keep whatever they have and are read through `canonicalType()`.
 *   - `content` is no longer a bag of per-type fields that all live side by
 *     side. Each type writes exactly one of `document`, `artwork`, `portrait`,
 *     `characters`, or the legacy prose fields, and the rest are absent. A
 *     manga draft with a 50 MB PDF no longer carries a `body`, `lore`, or
 *     `locations` array alongside it.
 *   - `category` is validated against the closed taxonomy list, so a client
 *     cannot invent an id the picker cannot render.
 *   - `origin` records how a character sheet was made, which is how a legacy
 *     `aiCharacter` row survives as a plain `character`.
 *   - `schemaVersion` moves to 2. Legacy documents are migrated on read by
 *     `upgradeLegacyWork`, so a partially-migrated collection still renders.
 *
 * Migration is deliberately additive and idempotent: it never deletes a legacy
 * field, because a rollback to the previous backend should still find the data
 * it wrote.
 */

const {
  ALL_TYPES,
  CREATABLE_TYPES,
  isKnownType,
  canonicalType,
  normalizeCategory,
  normalizeOrigin,
  supportsCategory,
} = require("./fanWorksTaxonomy");

const SCHEMA_VERSION = 2;

/** Roles the client may ask for. Mirrors `FanWorkMediaRole` on the Dart side. */
const MEDIA_ROLES = Object.freeze([
  "cover",
  "document",
  "artwork",
  "portrait",
  "characterPortrait",
]);

/** Roles that carry a PDF. */
const DOCUMENT_ROLES = Object.freeze(["document"]);

/** Roles that address one slot rather than appending to a list. */
const SINGLE_SLOT_ROLES = Object.freeze(["cover", "artwork", "portrait"]);

const ALLOWED_IMAGE_MIME = Object.freeze({
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
});
const DOCUMENT_MIME = "application/pdf";

const IMAGE_MAX_BYTES = 12 * 1024 * 1024;
const DOCUMENT_MAX_BYTES = 50 * 1024 * 1024;

// Every bound below mirrors `FanWorkLifecycle` in
// lib/features/fan_works/models/fan_work_lifecycle.dart. The server has to
// agree with the editor exactly: a limit the app enforces but the server does
// not is a fake constraint, and a limit the server enforces but the app does
// not is an upload the creator cannot finish. Change both files together.
const TITLE_MIN = 3;
const TITLE_MAX = 80;
const DESCRIPTION_MAX = 4000;
const CREATOR_NOTE_MAX = 1200;
const MAX_TAGS = 8;
const TAG_MIN = 2;
const TAG_MAX = 24;
const MAX_CAST = 24;
const CAST_NAME_MAX = 60;
const CAST_BIO_MAX = 600;
/** A character without this much story is a name, not a character. */
const CHARACTER_STORY_MIN = 40;
/** Pre-rebuild prose rows are read-only, so they only get a looser floor. */
const LEGACY_PROSE_MIN = 20;
const MAX_PERSONALITY = 1000;
const MAX_ABILITIES = 1000;
const MAX_SPECS = 500;
const MAX_CAPTION = 200;
const MAX_ANIME_ID = 64;
const MAX_ANIME_TITLE = 120;
const MAX_MEDIA_ID = 128;
const MAX_PATH = 256;
const MEDIA_ROOT = "fan_works";

/**
 * Which types require a document, an artwork, or nothing at publish time.
 * The four creatable types each have one required attachment.
 */
const TYPE_REQUIREMENTS = Object.freeze({
  manga: Object.freeze({ requiresDocument: true }),
  story: Object.freeze({ requiresDocument: true }),
  drawing: Object.freeze({ requiresArtwork: true }),
  character: Object.freeze({ requiresPortrait: false }),
});

function isDocumentRole(role) {
  return DOCUMENT_ROLES.includes(role);
}

function maxBytesForMime(mime) {
  return mime === DOCUMENT_MIME ? DOCUMENT_MAX_BYTES : IMAGE_MAX_BYTES;
}

/** The MIME a role is allowed to carry. */
function allowedMimeForRole(role) {
  if (isDocumentRole(role)) return DOCUMENT_MIME;
  return ALLOWED_IMAGE_MIME;
}

/**
 * Whether this exact MIME may be uploaded into this role. The document role
 * takes only `application/pdf`; the image roles take only the four raster
 * types. An image role never accepts a PDF and the document role never accepts
 * an image, which is what stops a manga from ending up with a JPEG "document".
 */
function mimeAllowedForRole(role, mime) {
  if (isDocumentRole(role)) return mime === DOCUMENT_MIME;
  return typeof mime === "string" && Boolean(ALLOWED_IMAGE_MIME[mime]);
}

function extensionForMime(mime) {
  if (mime === DOCUMENT_MIME) return "pdf";
  return ALLOWED_IMAGE_MIME[mime] || null;
}

/**
 * Rejects a role that the work's type cannot carry.
 *
 * A story cannot get an artwork slot, and a manga cannot get a character
 * portrait at the top level. This is the check that used to be missing and let
 * a single document accumulate every shape of media.
 */
function roleAllowedForType(type, role) {
  const canonical = canonicalType(type);
  switch (canonical) {
    case "manga":
    case "story":
      return role === "document" || role === "characterPortrait" || role === "cover";
    case "drawing":
      return role === "artwork" || role === "cover";
    case "character":
      return role === "portrait" || role === "cover";
    default:
      return role === "cover";
  }
}

/**
 * The empty content for a type: only the fields that type actually writes.
 * Returning the full legacy bag for every type is what made the old schema
 * grow fields no type ever used.
 */
function emptyContentFor(type) {
  switch (canonicalType(type)) {
    case "manga":
    case "story":
      return { document: null, characters: [] };
    case "drawing":
      return { artwork: null };
    case "character":
      return { portrait: null, personality: "", abilities: "", specs: "" };
    default:
      return {};
  }
}

function mediaFromExisting(item, fallbackContentType) {
  if (!item || typeof item.path !== "string" || !item.path) return null;
  const path = item.path;
  // A stored path must never carry a permanent token. If one does, the row was
  // written by the pre-rebuild code and must not be surfaced to a client.
  if (path.includes("token=")) return null;
  if (!path.startsWith(`${MEDIA_ROOT}/`)) return null;
  return {
    mediaId: typeof item.mediaId === "string" ? item.mediaId : "",
    path,
    contentType:
      typeof item.contentType === "string" && item.contentType
        ? item.contentType
        : fallbackContentType || "image/jpeg",
    pageCount:
      Number.isInteger(item.pageCount) && item.pageCount > 0 ? item.pageCount : undefined,
  };
}

/**
 * Drops media entries that no longer point at a real object path.
 * @param {any} raw
 * @param {string} [fallbackContentType]
 */
function sanitizeMedia(raw, fallbackContentType) {
  const media = mediaFromExisting(raw, fallbackContentType);
  if (!media || !media.mediaId) return null;
  return media;
}

/**
 * The cast list: name required, bio optional, portrait optional, order explicit.
 * A member with no name is dropped rather than stored blank, because a blank
 * row is indistinguishable from an empty one when the list is re-rendered.
 */
function sanitizeCast(raw, existingById) {
  if (!Array.isArray(raw)) return [];
  const out = [];
  for (const item of raw) {
    if (!item || typeof item !== "object") continue;
    const name = typeof item.name === "string" ? item.name.trim().slice(0, CAST_NAME_MAX) : "";
    if (!name) continue;
    const id =
      typeof item.id === "string" && item.id.trim()
        ? item.id.trim().slice(0, 64)
        : `cast-${out.length + 1}`;
    const bio = typeof item.bio === "string" ? item.bio.trim().slice(0, CAST_BIO_MAX) : "";
    const existing = existingById.get(id);
    // Reuse the already-uploaded portrait when the client did not pick a new
    // one, so editing a cast name never silently drops its image.
    //
    // A portrait can arrive in either shape: the nested `image` object written
    // by this schema, or the flat `imagePath`/`imageMediaId` pair the Dart
    // `FanWorkCharacter` model stores in its local draft. Accepting both is what
    // keeps a confirmed portrait from being silently dropped when an editor
    // client is older than the server (or newer).
    const portrait =
      sanitizeMedia(item.image, "image/jpeg") ||
      sanitizeMedia(
        item.imagePath || item.imageMediaId
          ? { mediaId: item.imageMediaId, path: item.imagePath }
          : existing,
        "image/jpeg",
      );
    const entry = { id, name, bio, index: out.length };
    if (portrait) {
      entry.image = portrait;
      // Mirror the confirmed portrait into the flat pair as well. The nested
      // object stays canonical (it is the only shape that carries `mediaId`
      // from the server), but the app model reads the flat pair, and writing
      // only one of the two would make portraits vanish on the next round-trip.
      entry.imagePath = portrait.path;
      entry.imageMediaId = portrait.mediaId;
    }
    out.push(entry);
    if (out.length >= MAX_CAST) break;
  }
  return out;
}

/**
 * Normalizes draft input into the stored content shape for this type.
 *
 * @param {object} existingContent the row's current content, for partial edits
 * @param {object} input the client payload
 * @param {string} type canonical type
 */
function mergeContent(existingContent, input, type) {
  const canonical = canonicalType(type);
  const current = existingContent && typeof existingContent === "object" ? existingContent : {};
  const next = { ...emptyContentFor(canonical) };
  const data = input && typeof input === "object" ? input : {};

  if (canonical === "manga" || canonical === "story") {
    next.document = sanitizeMedia(data.document, DOCUMENT_MIME) ||
      sanitizeMedia(current.document, DOCUMENT_MIME) || null;
    const existingById = new Map(
      (Array.isArray(current.characters) ? current.characters : [])
        .filter((entry) => entry && typeof entry.id === "string")
        .map((entry) => [entry.id, entry]),
    );
    if (data.characters !== undefined) {
      next.characters = sanitizeCast(data.characters, existingById);
    } else {
      next.characters = sanitizeCast(
        Array.isArray(current.characters) ? current.characters : [],
        existingById,
      );
    }
    return next;
  }

  if (canonical === "drawing") {
    next.artwork = sanitizeMedia(data.artwork, "image/jpeg") ||
      sanitizeMedia(current.artwork, "image/jpeg") || null;
    return next;
  }

  if (canonical === "character") {
    next.portrait =
      sanitizeMedia(data.portrait, "image/jpeg") ||
      sanitizeMedia(current.portrait, "image/jpeg") ||
      null;
    for (const [field, max] of [
      ["personality", MAX_PERSONALITY],
      ["abilities", MAX_ABILITIES],
      ["specs", MAX_SPECS],
    ]) {
      const incoming = data[field];
      const raw = typeof incoming === "string" ? incoming : current[field];
      next[field] = typeof raw === "string" ? raw.trim().slice(0, max) : "";
    }
    return next;
  }

  // Legacy read-only types keep whatever they already had. They are never
  // written by the new client, so there is nothing to normalize.
  return { ...current };
}

/**
 * Brings a stored row up to what the v2 readers expect, in place.
 *
 * Idempotent by construction: running it twice produces the same object, which
 * is what makes it safe to call on every read while a migration sweep runs in
 * the background.
 *
 * Legacy prose and page-image fields are *preserved*, not dropped. A manga
 * published before the rebuild has `content.pages` and no `document`; the client
 * still renders those pages from that array, so erasing it would turn every
 * existing manga into an empty work. New writes use `emptyContentFor`, which is
 * what keeps the schema narrow going forward; this function is the read path
 * and its job is to add, never to subtract.
 */
function upgradeLegacyWork(raw) {
  if (!raw || typeof raw !== "object") return null;
  const work = { ...raw };
  const originalType = typeof work.type === "string" ? work.type : "";
  const canonical = canonicalType(originalType);
  work.type = canonical;
  if (canonical === "character" && originalType === "aiCharacter") {
    work.origin = "aiGenerated";
  }
  work.origin = normalizeOrigin(work.origin);
  work.schemaVersion = SCHEMA_VERSION;

  const content = work.content && typeof work.content === "object" ? work.content : {};

  if (canonical === "manga" || canonical === "story") {
    work.content = {
      document: sanitizeMedia(content.document, DOCUMENT_MIME) || null,
      characters: sanitizeCast(
        Array.isArray(content.characters) ? content.characters : [],
        new Map(),
      ),
      // Legacy carriers, kept so old rows still render.
      body: typeof content.body === "string" ? content.body : "",
      chapters: Array.isArray(content.chapters) ? content.chapters : [],
      pages: Array.isArray(content.pages) ? content.pages : [],
      lore: typeof content.lore === "string" ? content.lore : "",
    };
  } else if (canonical === "drawing") {
    work.content = {
      artwork:
        sanitizeMedia(content.artwork, "image/jpeg") ||
        // Pre-rebuild drawings stored an `images` array; take the first entry so
        // an old drawing is not left with no artwork at all.
        sanitizeMedia(Array.isArray(content.images) ? content.images[0] : null, "image/jpeg") ||
        null,
      images: Array.isArray(content.images) ? content.images : [],
    };
  } else if (canonical === "character") {
    work.content = {
      portrait:
        sanitizeMedia(content.portrait, "image/jpeg") ||
        sanitizeMedia(content.image, "image/jpeg") ||
        null,
      personality: typeof content.personality === "string" ? content.personality : "",
      abilities: typeof content.abilities === "string" ? content.abilities : "",
      // `specs` is the v2 name for what a legacy row called `background`.
      specs: typeof content.specs === "string" ? content.specs : content.background || "",
      // Legacy carriers, kept so old rows still render.
      name: typeof content.name === "string" ? content.name : "",
      background: typeof content.background === "string" ? content.background : "",
      image: content.image || null,
      lore: typeof content.lore === "string" ? content.lore : "",
    };
  } else {
    // worldbuilding / other: read-only, pass the legacy bag through untouched.
    work.content = content;
  }

  work.category = supportsCategory(canonical)
    ? normalizeCategory(canonical, work.category || "")
    : "";
  return work;
}

/**
 * The publish-time completeness check.
 *
 * Returns `null` when the work may go live, or a human-readable reason when it
 * may not. The check is intentionally about *presence of required media*, not
 * about text length: a one-sentence story with a PDF is publishable, and an
 * empty one with a PDF is not.
 */
function publishValidationError(work) {
  if (!work || typeof work !== "object") return "Fan Work data is missing.";
  const type = canonicalType(work.type);
  if (!CREATABLE_TYPES.includes(type)) {
    return "Only manga, story, drawing, and character can be published.";
  }
  const title = typeof work.title === "string" ? work.title.trim() : "";
  if (title.length < TITLE_MIN || title.length > TITLE_MAX) {
    return "A title between 3 and 80 characters is required.";
  }
  const content = work.content && typeof work.content === "object" ? work.content : {};
  const requirements = TYPE_REQUIREMENTS[type];

  if (requirements.requiresDocument) {
    const document = content.document;
    if (!document || !document.path) {
      return type === "manga" ? "Manga needs a PDF." : "Story needs a PDF.";
    }
  }
  if (requirements.requiresArtwork) {
    if (!content.artwork || !content.artwork.path) {
      return "A drawing needs an image.";
    }
  }
  if (typeof work.description === "string" && work.description.length > DESCRIPTION_MAX) {
    return "The description is too long.";
  }
  if (typeof work.creatorNote === "string" && work.creatorNote.length > CREATOR_NOTE_MAX) {
    return "The creator note is too long.";
  }
  // The stored field is `category` (see `FanWork.fromMap`), not `categoryId`.
  if (typeof work.category === "string" && work.category.length > 0) {
    if (!normalizeCategory(type, work.category)) return "Choose a valid category.";
  } else if (supportsCategory(type)) {
    return "Choose a category.";
  }
  const cast = Array.isArray(content.characters) ? content.characters : [];
  if (cast.length > MAX_CAST) return "Too many characters.";
  if (type === "character") {
    // Same two rules the editor enforces, in the same order, so the creator
    // never gets past the editor and is then rejected on publish.
    const description = typeof work.description === "string" ? work.description.trim() : "";
    if (description.length < CHARACTER_STORY_MIN) {
      return "Tell the character story in at least 40 characters.";
    }
    if (!content.portrait || !content.portrait.path) {
      return "Attach the character portrait.";
    }
  }
  return null;
}

module.exports = Object.freeze({
  SCHEMA_VERSION,
  TITLE_MIN,
  TITLE_MAX,
  DESCRIPTION_MAX,
  MAX_TAGS,
  MAX_ANIME_ID,
  MAX_ANIME_TITLE,
  MAX_PERSONALITY,
  MAX_ABILITIES,
  MAX_SPECS,
  MAX_CAPTION,
  MEDIA_ROLES,
  DOCUMENT_ROLES,
  SINGLE_SLOT_ROLES,
  ALLOWED_IMAGE_MIME,
  DOCUMENT_MIME,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
  MAX_CAST,
  CHARACTER_STORY_MIN,
  LEGACY_PROSE_MIN,
  MAX_MEDIA_ID,
  MAX_PATH,
  MEDIA_ROOT,
  isDocumentRole,
  maxBytesForMime,
  allowedMimeForRole,
  mimeAllowedForRole,
  extensionForMime,
  roleAllowedForType,
  emptyContentFor,
  mergeContent,
  sanitizeMedia,
  sanitizeCast,
  upgradeLegacyWork,
  publishValidationError,
  isKnownType,
  canonicalType,
  normalizeCategory,
  normalizeOrigin,
  allTypes: ALL_TYPES,
});
