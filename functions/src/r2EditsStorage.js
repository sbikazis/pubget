"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const path = require("node:path");
const { pipeline } = require("node:stream/promises");

const DEFAULT_WORKER_URL = "https://pubget-media.pubget.workers.dev";
const MAX_EDITS_BYTES = 100 * 1024 * 1024;

/**
 * Minimal Google-Cloud-Storage-compatible adapter for the existing Edits
 * FFmpeg pipeline. All object bytes flow through authenticated Worker
 * endpoints; no R2 credentials or service secret are exposed to clients.
 *
 * Firebase Functions obtains a short-lived Google-signed identity token from
 * the Cloud Run metadata server. No shared Firebase/Worker secret is needed.
 */
function createR2EditsBucket({
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
      throw new Error("Edits Google service identity is not available.");
    }
    return { authorization: `Bearer ${token}`, ...extra };
  }

  function validateKey(key) {
    const valid = typeof key === "string" && key.length <= 512 &&
            /^edits\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\.mp4$|^edits-processed\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}(?:_(?:720|480))?\.mp4$|^edits\/[A-Za-z0-9_-]{1,128}\/t_[A-Za-z0-9_-]{1,128}\.jpg$/.test(key);
    if (!valid) throw new Error("Invalid Edits R2 object key.");
    return key;
  }
  function file(key) {
    validateKey(key);
    const endpoint = `${baseUrl}/_internal/edits/objects/${encodeURIComponent(key)}`;

    return {
      async exists() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) return [false];
        if (!response.ok) throw new Error(`Edits R2 HEAD failed (${response.status}).`);
        return [true];
      },

      async getMetadata() {
        const response = await fetchImpl(endpoint, { method: "HEAD", headers: await headers() });
        if (response.status === 404) {
          const error = new Error("Edits R2 object not found.");
          error.code = 404;
          throw error;
        }
        if (!response.ok) throw new Error(`Edits R2 metadata failed (${response.status}).`);
        return [{
          size: response.headers.get("content-length") || "0",
          contentType: response.headers.get("content-type") || "application/octet-stream",
        }];
      },

      async download({ destination }) {
        const response = await fetchImpl(endpoint, { headers: await headers() });
        if (!response.ok || !response.body) {
          throw new Error(`Edits R2 download failed (${response.status}).`);
        }
        await fsp.mkdir(path.dirname(destination), { recursive: true });
        await pipeline(response.body, fs.createWriteStream(destination));
        return [destination];
      },



      async delete({ ignoreNotFound = false } = {}) {
        const response = await fetchImpl(endpoint, { method: "DELETE", headers: await headers() });
        if (ignoreNotFound && response.status === 404) return;
        if (!response.ok && response.status !== 404) {
          throw new Error(`Edits R2 delete failed (${response.status}).`);
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
      if (!stat.isFile() || stat.size <= 0 || stat.size > MAX_EDITS_BYTES) {
        throw new Error("Edits output has an invalid size.");
      }
      const contentType = options.metadata?.contentType || "application/octet-stream";
      const stream = fs.createReadStream(localPath);
      const response = await fetchImpl(
        `${baseUrl}/_internal/edits/objects/${encodeURIComponent(destination)}`,
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
        throw new Error(`Edits R2 upload failed (${response.status}).`);
      }
      return [{ name: destination }];
    },
  };
}

module.exports = { createR2EditsBucket, MAX_EDITS_BYTES };
