"use strict";

const {
  buildMediaPath,
  extensionFor,
  maxBytesFor,
  UPLOAD_SESSION_TTL_MS,
  READ_URL_TTL_MS,
  DOCUMENT_MIME,
} = require("./fanWorksStorage");

const DEFAULT_WORKER_URL = "https://pubget-media.pubget.workers.dev";

/**
 * R2-backed replacement for the Firebase Storage Fan Works signer.
 *
 * The public contract is deliberately identical to `createFanWorksSigner`:
 * the domain still receives `{ sessionUri, path, mime, maxBytes, expiresAt }`
 * for documents, `{ url, path, mime, maxBytes, expiresAt }` for images, and
 * `{ url, expiresAt }` for reader links. The Flutter client therefore needs
 * no changes — only the bytes' destination and the signature authority move.
 *
 * Functions authenticates to the Worker with a short-lived Google service
 * identity; the HMAC signing secret stays inside the Worker.
 */
function createR2FanWorksSigner({
  workerUrl = process.env.KIRARI_R2_WORKER_URL || DEFAULT_WORKER_URL,
  tokenProvider,
  fetchImpl = global.fetch,
  now = () => Date.now(),
} = {}) {
  const baseUrl = workerUrl.replace(/\/+$/, "");

  async function headers(extra = {}) {
    const audience = process.env.KIRARI_R2_WORKER_AUDIENCE ||
      "https://pubget-media.pubget.workers.dev";
    const getToken = tokenProvider || (async () => {
      const metadataUrl = new URL(
        "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity",
      );
      metadataUrl.searchParams.set("audience", audience);
      metadataUrl.searchParams.set("format", "full");
      const response = await fetchImpl(metadataUrl, {
        headers: { "Metadata-Flavor": "Google" },
      });
      if (!response.ok) {
        throw new Error(`Fan Works Google service identity failed (${response.status}).`);
      }
      return (await response.text()).trim();
    });
    const token = await getToken();
    if (!token || typeof token !== "string" || token.split(".").length !== 3) {
      throw new Error("Fan Works Google service identity is not available.");
    }
    return { authorization: `Bearer ${token}`, "content-type": "application/json", ...extra };
  }

  async function sign(op, payload) {
    const response = await fetchImpl(`${baseUrl}/_internal/fanworks/sign`, {
      method: "POST",
      headers: await headers(),
      body: JSON.stringify({ op, ...payload }),
    });
    if (!response.ok) {
      throw new Error(`Fan Works R2 sign failed (${response.status}).`);
    }
    return response.json();
  }

  return Object.freeze({
    /**
     * The shape `readMediaMetadata` in fanWorksDomain.js expects. It first
     * looks for a `metadata(path)` function, so exposing that is enough to
     * keep the domain's size/MIME verification intact after confirmMedia.
     */
    async metadata(path) {
      if (typeof path !== "string" || !path.startsWith("fan_works/")) return null;
      let response;
      try {
        response = await fetchImpl(`${baseUrl}/_internal/fanworks/sign`, {
          method: "POST",
          headers: await headers(),
          body: JSON.stringify({ op: "metadata", key: path }),
        });
      } catch {
        return null;
      }
      if (response.status === 404) return null;
      if (!response.ok) return null;
      const meta = await response.json();
      return {
        contentType: String(meta.contentType || ""),
        size: Number(meta.size) || 0,
      };
    },

    async signResumableUpload({ userId, workId, mediaId, mime, nonce }) {
      const path = buildMediaPath({ userId, workId, mediaId, mime, nonce });
      if (!path) throw new Error("Invalid Fan Works document path.");
      const signed = await sign("upload", {
        key: path,
        contentType: mime || DOCUMENT_MIME,
        size: maxBytesFor(mime || DOCUMENT_MIME),
      });
      return {
        sessionUri: signed.sessionUrl,
        path,
        mime,
        maxBytes: maxBytesFor(mime),
        expiresAt: signed.expiresAt || now() + UPLOAD_SESSION_TTL_MS,
      };
    },

    async signWriteUrl({ userId, workId, mediaId, mime, nonce }) {
      const path = buildMediaPath({ userId, workId, mediaId, mime, nonce });
      if (!path) throw new Error("Invalid Fan Works image path.");
      const signed = await sign("upload", {
        key: path,
        contentType: mime,
        size: maxBytesFor(mime),
      });
      return {
        url: signed.uploadUrl,
        path,
        mime,
        maxBytes: maxBytesFor(mime),
        expiresAt: signed.expiresAt || now() + UPLOAD_SESSION_TTL_MS,
      };
    },

    async signReadUrl({ path, inline = true }) {
      if (typeof path !== "string" || !path.startsWith("fan_works/") || path.includes("..")) {
        throw new Error("Invalid Fan Works read path.");
      }
      const signed = await sign("read", {
        key: path,
        disposition: inline ? "inline" : "attachment",
      });
      return {
        url: signed.url,
        expiresAt: signed.expiresAt || now() + READ_URL_TTL_MS,
      };
    },
  });
}

module.exports = { createR2FanWorksSigner };
