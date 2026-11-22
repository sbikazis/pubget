"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");
const { pipeline } = require("node:stream/promises");

const DEFAULT_WORKER_URL = "https://pubget-media.pubget.workers.dev";
const MAX_AUDIO_BYTES = 25 * 1024 * 1024;

/**
 * Minimal Google-Cloud-Storage-compatible adapter for Reel audio extraction.
 * Source reads use the published Edits object keys; generated audio is written
 * only to server-owned `reelAudios/{uid}/{audioId}.m4a` keys through the
 * authenticated Worker bridge. No R2 credentials are exposed to clients.
 */
function createR2AudioBucket({
  workerUrl = process.env.KIRARI_R2_WORKER_URL || DEFAULT_WORKER_URL,
  tokenProvider,
  fetchImpl = global.fetch,
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
        throw new Error(`Google service identity token request failed (${response.status}).`);
      }
      return (await response.text()).trim();
    });
    const token = await getToken();
    if (!token || typeof token !== "string" || token.split(".").length !== 3) {
      throw new Error("Audio Google service identity is not available.");
    }
    return { authorization: `Bearer ${token}`, ...extra };
  }

  function validateKey(key) {
    const valid = typeof key === "string" && key.length <= 512 &&
      /^edits\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\.mp4$|^edits-processed\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}(?:_(?:720|480))?\.mp4$|^reelAudios\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\.m4a$/.test(key);
    if (!valid) throw new Error("Invalid audio R2 object key.");
    return key;
  }

  function validateUploadKey(key) {
    validateKey(key);
    if (!/^reelAudios\//.test(key)) {
      throw new Error("Audio pipeline may only write reelAudios objects.");
    }
    return key;
  }

  function file(key) {
    validateKey(key);
    const endpoint = `${baseUrl}/_internal/audio/objects/${encodeURIComponent(key)}`;

    return {
      async exists() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) return [false];
        if (!response.ok) throw new Error(`Audio R2 HEAD failed (${response.status}).`);
        return [true];
      },

      async getMetadata() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) {
          const error = new Error("Audio R2 object not found.");
          error.code = 404;
          throw error;
        }
        if (!response.ok) throw new Error(`Audio R2 metadata failed (${response.status}).`);
        return [{
          size: response.headers.get("content-length") || "0",
          contentType: response.headers.get("content-type") || "application/octet-stream",
        }];
      },

      async download({ destination }) {
        const response = await fetchImpl(endpoint, { headers: await headers() });
        if (!response.ok || !response.body) {
          throw new Error(`Audio R2 download failed (${response.status}).`);
        }
        await fsp.mkdir(path.dirname(destination), { recursive: true });
        await pipeline(response.body, fs.createWriteStream(destination));
        return [destination];
      },

      async delete({ ignoreNotFound = false } = {}) {
        validateUploadKey(key);
        const response = await fetchImpl(endpoint, { method: "DELETE", headers: await headers() });
        if (ignoreNotFound && response.status === 404) return;
        if (!response.ok && response.status !== 404) {
          throw new Error(`Audio R2 delete failed (${response.status}).`);
        }
      },
    };
  }

  return {
    name: "pubget-media",
    file,
    async upload(localPath, options = {}) {
      const destination = validateUploadKey(options.destination);
      const stat = await fsp.stat(localPath);
      if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_AUDIO_BYTES) {
        throw new Error("Extracted audio has an invalid size.");
      }
      const contentType = options.metadata?.contentType || "audio/mp4";
      if (!["audio/mp4", "audio/m4a"].includes(contentType)) {
        throw new Error("Extracted audio must be audio/mp4 or audio/m4a.");
      }
      const response = await fetchImpl(
        `${baseUrl}/_internal/audio/objects/${encodeURIComponent(destination)}`,
        {
          method: "PUT",
          headers: await headers({
            "content-type": contentType,
            "content-length": String(stat.size),
          }),
          body: fs.createReadStream(localPath),
          duplex: "half",
        },
      );
      if (!response.ok) {
        throw new Error(`Audio R2 upload failed (${response.status}).`);
      }
      return [{ name: destination }];
    },
  };
}

module.exports = { createR2AudioBucket, MAX_AUDIO_BYTES };
