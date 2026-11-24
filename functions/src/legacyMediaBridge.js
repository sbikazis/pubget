"use strict";

/**
 * Temporary read bridge for media objects that still live only in the legacy
 * Firebase Storage bucket. The Flutter app no longer depends on the Storage
 * SDK; this callable authorizes the caller against Firestore and returns a
 * short-lived GCS URL. No permanent `token=` URL is ever issued.
 *
 * This module exists only until the GCS -> R2 backfill (including fan_works/)
 * is verified in production. After that, delete it together with
 * `storage.rules` and the migration routes.
 */

const LEGACY_BUCKET = "pubget-aaf27.firebasestorage.app";
const MAX_PATH_LENGTH = 1024;
const DEFAULT_TTL_MS = 5 * 60 * 1000;

/**
 * Accepts either a canonical Firebase download URL or a bare object path.
 * Decodes before validating so an encoded `..` cannot slip through.
 */
function parseLegacyObjectPath(reference) {
  if (typeof reference !== "string") return null;
  const source = reference.trim();
  if (!source || source.length > MAX_PATH_LENGTH) return null;

  let path = source;
  if (/^https?:\/\//i.test(source)) {
    let url;
    try {
      url = new URL(source);
    } catch (error) {
      return null;
    }
    if (url.hostname !== "firebasestorage.googleapis.com") return null;
    const segments = url.pathname.split("/").filter(Boolean);
    if (segments.length < 5 || segments[0] !== "v0" || segments[1] !== "b" ||
        segments[3] !== "o") {
      return null;
    }
    try {
      path = decodeURIComponent(segments.slice(4).join("/"));
    } catch (error) {
      return null;
    }
  }

  if (!path || path.length > MAX_PATH_LENGTH || path.startsWith("/") ||
      path.includes("..") || path.includes("\\") || path.includes("?") ||
      path.includes("#") || /[\u0000-\u001f]/.test(path)) {
    return null;
  }
  return path;
}

/**
 * Mirrors the Worker's media authorization: conversation media requires
 * membership, Fan Works requires ownership or an approved published work,
 * and owner-scoped assets are readable only for public media kinds.
 */
async function authorizeLegacyPath({ db, uid, path }) {
  if (!uid || typeof path !== "string") return false;
  const parts = path.split("/");

  if ((parts[0] === "groups" || parts[0] === "privateChats") &&
      parts.length >= 3) {
    if (!db || !parts[1]) return false;
    const member = await db.collection(parts[0]).doc(parts[1])
      .collection("members").doc(uid).get();
    return member.exists;
  }

  if (parts[0] === "fan_works" && parts.length >= 3) {
    if (parts[1] === uid) return true;
    if (!db || !parts[2]) return false;
    const work = await db.collection("fanWorks").doc(parts[2]).get();
    if (!work.exists) return false;
    const data = work.data() || {};
    return data.status === "published" &&
      data.moderationStatus === "approved";
  }

  // Avatars were signed-in readable under the legacy rules.
  if (parts[0] === "users") return parts.length >= 3;

  if (["images", "reels", "audio"].includes(parts[0])) {
    if (parts.length < 3) return false;
    if (parts[1] === uid) return true;
    // Only published feed media is readable across owners.
    return parts[0] === "reels" || parts[0] === "audio";
  }

  return false;
}

function createLegacyMediaResolver({
  db,
  bucket,
  HttpsError,
  ttlMs = DEFAULT_TTL_MS,
  now = () => Date.now(),
}) {
  if (!bucket || typeof bucket.file !== "function") {
    throw new Error("createLegacyMediaResolver requires a bucket.");
  }
  if (!HttpsError) {
    throw new Error("createLegacyMediaResolver requires HttpsError.");
  }

  return async function resolveLegacyMedia(request) {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError("unauthenticated", "Sign in to open this media.");
    }
    const path = parseLegacyObjectPath(request.data && request.data.path);
    if (!path) throw new HttpsError("invalid-argument", "Invalid media path.");

    const allowed = await authorizeLegacyPath({
      db,
      uid: request.auth.uid,
      path,
    });
    if (!allowed) {
      throw new HttpsError("permission-denied", "This media is not available.");
    }

    const expiresAt = now() + ttlMs;
    let url;
    try {
      [url] = await bucket.file(path).getSignedUrl({
        action: "read",
        expires: expiresAt,
      });
    } catch (error) {
      throw new HttpsError("not-found", "The requested media is not available.");
    }
    if (typeof url !== "string" || !url.startsWith("https://")) {
      throw new HttpsError("not-found", "The requested media is not available.");
    }
    return { url, expiresAt: Math.floor(expiresAt / 1000) };
  };
}

module.exports = Object.freeze({
  LEGACY_BUCKET,
  authorizeLegacyPath,
  createLegacyMediaResolver,
  parseLegacyObjectPath,
});
