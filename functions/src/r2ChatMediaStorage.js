"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");
const { pipeline } = require("node:stream/promises");

const DEFAULT_WORKER_URL = "https://pubget-media.pubget.workers.dev";
const MAX_DERIVATIVE_BYTES = 25 * 1024 * 1024;

/**
 * GCS-shaped adapter over the authenticated Worker's chat object bridge.
 *
 * The chat pipeline writes only derived JPEGs; originals remain client-owned
 * and are uploaded through signed capabilities. Firestore metadata keeps the
 * same scope fields so `/resolve` can authorize group/chat members, and no R2
 * credential is ever present in the Functions runtime.
 */
function createR2ChatMediaStorage({
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
      throw new Error("Chat media Google service identity is not available.");
    }
    return { authorization: `Bearer ${token}`, ...extra };
  }

  function validateKey(key) {
    if (typeof key !== "string" || key.length > 512) {
      throw new Error("Invalid chat R2 object key.");
    }
    const parts = key.split("/");
    const valid = parts.length === 4 &&
      ["groups", "privateChats"].includes(parts[0]) &&
      /^[A-Za-z0-9_:-]{1,320}$/.test(parts[1]) &&
      /^[A-Za-z0-9_-]{1,128}$/.test(parts[2]) &&
      /^[A-Za-z0-9_-]{1,80}\.[a-z0-9]{2,5}$/.test(parts[3]);
    if (!valid) throw new Error("Invalid chat R2 object key.");
    return key;
  }

  function endpoint(key) {
    return `${baseUrl}/_internal/chat/objects/${encodeURIComponent(validateKey(key))}`;
  }

  function file(key) {
    const url = endpoint(key);
    return {
      async exists() {
        const response = await fetchImpl(url, { method: "HEAD", headers: await headers() });
        if (response.status === 404) return [false];
        if (!response.ok) throw new Error(`Chat R2 HEAD failed (${response.status}).`);
        return [true];
      },

      async getMetadata() {
        const response = await fetchImpl(url, { method: "HEAD", headers: await headers() });
        if (response.status === 404) {
          const error = new Error("Chat R2 object not found.");
          error.code = 404;
          throw error;
        }
        if (!response.ok) throw new Error(`Chat R2 metadata failed (${response.status}).`);
        return [{
          size: response.headers.get("content-length") || "0",
          contentType: response.headers.get("content-type") || "application/octet-stream",
        }];
      },

      async download({ destination }) {
        const response = await fetchImpl(url, { headers: await headers() });
        if (!response.ok || !response.body) {
          throw new Error(`Chat R2 download failed (${response.status}).`);
        }
        await fsp.mkdir(path.dirname(destination), { recursive: true });
        await pipeline(response.body, fs.createWriteStream(destination));
        return [destination];
      },

      async delete({ ignoreNotFound = false } = {}) {
        const response = await fetchImpl(url, { method: "DELETE", headers: await headers() });
        if (ignoreNotFound && response.status === 404) return;
        if (!response.ok && response.status !== 404) {
          throw new Error(`Chat R2 delete failed (${response.status}).`);
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
      if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_DERIVATIVE_BYTES) {
        throw new Error("Chat derivative has an invalid size.");
      }
      const contentType = options.metadata?.contentType || "application/octet-stream";
      if (contentType !== "image/jpeg" || !/_(?:thumb|medium)\.jpg$/.test(destination)) {
        throw new Error("Chat pipeline may only upload JPEG derivatives.");
      }
      const response = await fetchImpl(endpoint(destination), {
        method: "PUT",
        headers: await headers({
          "content-type": contentType,
          "content-length": String(stat.size),
        }),
        body: fs.createReadStream(localPath),
        duplex: "half",
      });
      if (!response.ok) {
        throw new Error(`Chat R2 upload failed (${response.status}).`);
      }
      return [{ name: destination }];
    },
  };
}

module.exports = { createR2ChatMediaStorage, MAX_DERIVATIVE_BYTES };
