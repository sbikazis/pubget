"use strict";

/**
 * Signed, short-lived access to Fan Works media.
 *
 * The threat model, stated honestly: a PDF that a client can render is a PDF a
 * determined user can extract. What this module removes is every *casual* copy
 * path:
 *
 *   1. No permanent download token. The pre-rebuild code called
 *      `getDownloadURL()`, which mints a `token=` URL that is valid forever and
 *      works in any browser, any proxy, and any shared chat. Nothing here ever
 *      mints one, and `assertNoDownloadToken` fails loudly if a stored path
 *      carries a token.
 *   2. Uploads are resumable sessions scoped to one object, not public-write.
 *   3. Reads are V4-signed URLs that expire in minutes, are forced
 *      `Content-Disposition: inline` so the browser never treats the PDF as a
 *      file to save, and carry `X-Content-Type-Options: nosniff` via the
 *      response type so a stored HTML payload cannot be re-served as markup.
 *
 * What it does NOT do: stop a determined user from screenshotting the reader,
 * or from copying bytes out of memory. `FLAG_SECURE` plus a session watermark
 * on the client raise the cost of that; they do not make it impossible. The
 * report says this in as many words rather than promising DRM.
 *
 * The bucket handle is injected so the unit tests can drive a fake client and
 * assert on the exact options (no `predefinedAcl: publicRead`, no token) without
 * any credentials. That is the only reason `getSignedUrl` failing with
 * "Could not load the default credentials" no longer blocks the test suite.
 */

/**
 * Matches the path that `storage.rules` already gates and that every file
 * published before the rebuild sits at. The uid stays in the path because the
 * rules read it, `assertOwnedPath` in `fanWorksDomain.js` parses it, and
 * changing the convention would orphan existing media.
 */
const MEDIA_ROOT = "fan_works";
const UPLOAD_SESSION_TTL_MS = 15 * 60 * 1000;
const READ_URL_TTL_MS = 3 * 60 * 1000;

/** Media roles that may hold a PDF, and therefore need the strictest path. */
const DOCUMENT_ROLES = Object.freeze(["document"]);

const ALLOWED_IMAGE_MIME = Object.freeze({
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/gif": "gif",
});

const DOCUMENT_MIME = "application/pdf";

const IMAGE_MAX_BYTES = 12 * 1024 * 1024;
const DOCUMENT_MAX_BYTES = 50 * 1024 * 1024;

function extensionFor(mime) {
  if (mime === DOCUMENT_MIME) return "pdf";
  return ALLOWED_IMAGE_MIME[mime] || null;
}

function maxBytesFor(mime) {
  return mime === DOCUMENT_MIME ? DOCUMENT_MAX_BYTES : IMAGE_MAX_BYTES;
}

/**
 * Builds the object path. The nonce makes every attempt a new object so a
 * retried upload can never overwrite a half-finished or already-published file.
 */
function buildMediaPath({ userId, workId, mediaId, mime, nonce }) {
  const ext = extensionFor(mime);
  if (!ext) return null;
  const safeUser = String(userId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeWork = String(workId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeMedia = String(mediaId || "").replace(/[^A-Za-z0-9_-]/g, "");
  const safeNonce = String(nonce || "").replace(/[^A-Za-z0-9]/g, "");
  if (!safeUser || !safeWork || !safeMedia || !safeNonce) return null;
  return `${MEDIA_ROOT}/${safeUser}/${safeWork}/${safeNonce}_${safeMedia}.${ext}`;
}

function assertNoDownloadToken(path, HttpsError) {
  if (typeof path === "string" && path.includes("token=")) {
    throw new HttpsError(
      "failed-precondition",
      "This media path carries a permanent download token.",
    );
  }
}

/** Refuses to read anything outside the Fan Works tree. */
function assertInsideFanWorks(path, HttpsError) {
  if (typeof path !== "string" || !path.startsWith(`${MEDIA_ROOT}/`)) {
    throw new HttpsError("permission-denied", "That media path is not readable.");
  }
  if (path.includes("..")) {
    throw new HttpsError("permission-denied", "That media path is not readable.");
  }
}

function createFanWorksSigner({ bucket, HttpsError, now = () => Date.now() }) {
  if (!bucket) throw new Error("createFanWorksSigner requires a bucket.");
  if (!HttpsError) throw new Error("createFanWorksSigner requires HttpsError.");

  return {
    /**
     * Opens a resumable upload session. Returns the session URI the client
     * `PUT`s bytes to, plus the ceiling the client is already enforcing.
     *
     * No `predefinedAcl` is passed on purpose: an omitted ACL means the object
     * inherits the bucket's uniform bucket-level access, which is private.
     */
    async signResumableUpload({
      userId,
      workId,
      mediaId,
      mime,
      nonce,
      origin = null,
    }) {
      const ext = extensionFor(mime);
      if (!ext) {
        throw new HttpsError(
          "invalid-argument",
          "Only JPEG, PNG, WEBP, GIF, or PDF uploads are allowed.",
        );
      }
      const path = buildMediaPath({ userId, workId, mediaId, mime, nonce });
      if (!path) {
        throw new HttpsError("invalid-argument", "That media path is not valid.");
      }
      const file = bucket.file(path);
      const result = await file.createResumableUpload({
        origin: origin || undefined,
        metadata: { contentType: mime },
        // Private by inheritance; never `publicRead`.
        validation: "crc32c",
      });
      // @google-cloud/storage resolves to [uri] on some versions and to a bare
      // string on others, so normalize instead of assuming.
      const sessionUri = Array.isArray(result) ? result[0] : result;
      if (typeof sessionUri !== "string" || !sessionUri.startsWith("http")) {
        throw new HttpsError(
          "internal",
          "The upload session could not be created.",
        );
      }
      const issuedAt = now();
      return {
        sessionUri,
        path,
        mime,
        maxBytes: maxBytesFor(mime),
        expiresAt: issuedAt + UPLOAD_SESSION_TTL_MS,
      };
    },

    /**
     * A short-lived inline read URL. `disposition: "inline"` plus
     * `responseType` stops a browser from turning the response into a
     * download, and the short TTL means a leaked URL dies quickly.
     */
    async signReadUrl({ path, inline = true }) {
      assertInsideFanWorks(path, HttpsError);
      assertNoDownloadToken(path, HttpsError);
      const issuedAt = now();
      const expires = new Date(issuedAt + READ_URL_TTL_MS);
      const [url] = await bucket.file(path).getSignedUrl({
        version: "v4",
        action: "read",
        expires,
        responseDisposition: inline ? "inline" : "attachment",
        responseType: "application/pdf",
      });
      if (typeof url !== "string" || !url.startsWith("http")) {
        throw new HttpsError("internal", "The reading link could not be created.");
      }
      return { url, expiresAt: issuedAt + READ_URL_TTL_MS };
    },

    /**
     * A tokenless write URL for a single small image, used for covers and
     * portraits. Signed `PUT` with a bounded expiry means the client can retry
     * a failed image upload without asking the server for a new ticket, and
     * nothing is ever publicly readable.
     */
    async signWriteUrl({ userId, workId, mediaId, mime, nonce }) {
      const ext = extensionFor(mime);
      if (!ext || mime === DOCUMENT_MIME) {
        throw new HttpsError(
          "invalid-argument",
          "Only image uploads are allowed here.",
        );
      }
      const path = buildMediaPath({ userId, workId, mediaId, mime, nonce });
      if (!path) {
        throw new HttpsError("invalid-argument", "That media path is not valid.");
      }
      const issuedAt = now();
      const expires = new Date(issuedAt + UPLOAD_SESSION_TTL_MS);
      const [url] = await bucket.file(path).getSignedUrl({
        version: "v4",
        action: "write",
        expires,
        contentType: mime,
        extensionHeaders: {
          "x-goog-content-length-range": `1,${maxBytesFor(mime)}`,
        },
      });
      if (typeof url !== "string" || !url.startsWith("http")) {
        throw new HttpsError("internal", "The upload link could not be created.");
      }
      return {
        url,
        path,
        mime,
        maxBytes: maxBytesFor(mime),
        expiresAt: issuedAt + UPLOAD_SESSION_TTL_MS,
      };
    },
  };
}

module.exports = Object.freeze({
  createFanWorksSigner,
  buildMediaPath,
  maxBytesFor,
  extensionFor,
  MEDIA_ROOT,
  UPLOAD_SESSION_TTL_MS,
  READ_URL_TTL_MS,
  DOCUMENT_ROLES,
  ALLOWED_IMAGE_MIME,
  DOCUMENT_MIME,
  IMAGE_MAX_BYTES,
  DOCUMENT_MAX_BYTES,
});
