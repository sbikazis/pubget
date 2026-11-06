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
 * KIRARI_R2_SERVICE_SECRET must be configured as a Firebase Functions secret
 * and as the Worker KIRARI_R2_SERVICE_SECRET binding before deployment.
 */
function createR2KirariBucket({
  workerUrl = process.env.KIRARI_R2_WORKER_URL || DEFAULT_WORKER_URL,
  secretProvider = () => process.env.KIRARI_R2_SERVICE_SECRET || "",
  fetchImpl = global.fetch,
  tempDir = require("node:os").tmpdir(),
} = {}) {
  const baseUrl = workerUrl.replace(/\/+$/, "");

  function headers(extra = {}) {
    const secret = secretProvider();
    if (!secret || secret.length < 32) {
      throw new Error("Kirari R2 service authentication is not configured.");
    }
    return { authorization: `Bearer ${secret}`, ...extra };
  }

  function validateKey(key) {
    if (typeof key !== "string" || key.length > 512 || key.startsWith("/") ||
        key.includes("..") || key.includes("\\") ||
        !/^(?:kirari\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/(?:source\.mp4|[A-Za-z0-9_-]{1,80}\.mp4|cover\.jpg)|kirari-processed\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/(?:360|540|720)\.mp4|kirari-audio\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,80}\.(?:mp3|m4a|aac|ogg))$/.test(key)) {
      throw new Error("Invalid Kirari R2 object key.");
    }
    return key;
  }

  function file(key) {
    validateKey(key);
    const endpoint = `${baseUrl}/_internal/kirari/objects/${encodeURIComponent(key)}`;

    return {
      async exists() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: headers() });
        if (response.status === 404) return [false];
        if (!response.ok) throw new Error(`Kirari R2 HEAD failed (${response.status}).`);
        return [true];
      },

      async getMetadata() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: headers() });
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
        const response = await fetchImpl(endpoint, { headers: headers() });
        if (!response.ok || !response.body) {
          throw new Error(`Kirari R2 download failed (${response.status}).`);
        }
        await fsp.mkdir(path.dirname(destination), { recursive: true });
        await pipeline(response.body, fs.createWriteStream(destination));
        return [destination];
      },

      async delete({ ignoreNotFound = false } = {}) {
        const response = await fetchImpl(endpoint, { method: "DELETE", headers: headers() });
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
          headers: headers({
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
