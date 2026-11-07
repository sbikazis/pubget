"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");
const { pipeline } = require("node:stream/promises");

const DEFAULT_WORKER_URL = "https://pubget-media.pubget.workers.dev";
const MAX_KIRARI_BYTES = 500 * 1024 * 1024;

/**
 * Minimal Google-Cloud-Storage-compatible adapter for the existing Kirari
 * FFmpeg pipeline. All object bytes flow through authenticated Worker
 * endpoints; no R2 credentials or service secret are exposed to clients.
 *
 * Firebase Functions obtains a short-lived Google-signed identity token from
 * the Cloud Run metadata server. No shared Firebase/Worker secret is needed.
 */
function createR2KirariBucket({
  workerUrl = process.env.KIRARI_R2_WORKER_URL || DEFAULT_WORKER_URL,
  tokenProvider,
  fetchImpl = global.fetch,
  tempDir = require("node:os").tmpdir(),
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
      throw new Error("Kirari Google service identity is not available.");
    }
    return { authorization: `Bearer ${token}`, ...extra };
  }

  function validateKey(key) {
    const valid = typeof key === "string" && key.length <= 512 &&
      /^(?:kirari\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/source\.mp4|kirari-processed\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/(?:360|540|720)\.mp4|kirari-processed\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/cover\.jpg|kirari-audio\/[A-Za-z0-9_-]{1,128}\/audio\.(?:mp3|m4a|aac|ogg))$/.test(key);
    if (!valid) throw new Error("Invalid Kirari R2 object key.");
    return key;
  }
  function file(key) {
    validateKey(key);
    const endpoint = `${baseUrl}/_internal/kirari/objects/${encodeURIComponent(key)}`;

    return {
      async exists() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) return [false];
        if (!response.ok) throw new Error(`Kirari R2 HEAD failed (${response.status}).`);
        return [true];
      },

      async getMetadata() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) {
          const error = new Error("Kirari R2 object not found.");
          error.code = 404;
          throw error;
        }
        if (!response.ok) throw new Error(`Kirari R2 metadata failed (${response.status}).`);
        return [{
          size: response.headers.get("content-length") || "0",
          contentType: response.headers.get("content-type") || "application/octet-stream",
        }];
      },

      async download({ destination }) {
        const response = await fetchImpl(endpoint, { headers: await headers() });
        if (!response.ok || !response.body) {
          throw new Error(`Kirari R2 download failed (${response.status}).`);
        }
        await fsp.mkdir(path.dirname(destination), { recursive: true });
        await pipeline(response.body, fs.createWriteStream(destination));
        return [destination];
      },

      async getSignedUrl({ expires }) {
        const expiry = Number(expires);
        const response = await fetchImpl(`${baseUrl}/_internal/kirari/sign`, {
          method: "POST",
          headers: await headers({ "content-type": "application/json" }),
          body: JSON.stringify({ key, expires: Math.floor(expiry / 1000) }),
        });
        if (!response.ok) throw new Error(`Kirari R2 signing failed (${response.status}).`);
        const payload = await response.json();
        if (!payload.url || typeof payload.url !== "string") {
          throw new Error("Kirari R2 signer returned an invalid URL.");
        }
        return [payload.url];
      },

      async delete({ ignoreNotFound = false } = {}) {
        const response = await fetchImpl(endpoint, { method: "DELETE", headers: await headers() });
        if (ignoreNotFound && response.status === 404) return;
        if (!response.ok && response.status !== 404) {
          throw new Error(`Kirari R2 delete failed (${response.status}).`);
        }
      },
    };
  }

  return {
    name: "pubget-media",
    file,
    async upload(localPath, options = {}) {
      const destination = validateKey(options.destination);
      const stat = await fsp.stat(localPath);
      if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_KIRARI_BYTES) {
        throw new Error("Kirari output has an invalid size.");
      }
      const contentType = options.metadata?.contentType || "application/octet-stream";
      const stream = fs.createReadStream(localPath);
      const response = await fetchImpl(
        `${baseUrl}/_internal/kirari/objects/${encodeURIComponent(destination)}`,
        {
          method: "PUT",
          headers: await headers({
            "content-type": contentType,
            "content-length": String(stat.size),
          }),
          body: stream,
          duplex: "half",
        },
      );
      if (!response.ok) {
        throw new Error(`Kirari R2 upload failed (${response.status}).`);
      }
      return [{ name: destination }];
    },
  };
}

module.exports = { createR2KirariBucket, MAX_KIRARI_BYTES };
