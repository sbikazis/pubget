"use strict";

/**
 * Converts a Firestore media-state transition into the Storage-compatible
 * event contract consumed by the existing Kirari FFmpeg pipeline.
 *
 * Only R2-backed records entering processing are handled here. Legacy
 * Firebase Storage records continue through their object-finalize trigger.
 */
function createKirariR2ProcessingTrigger({ bucket, processVideo }) {
  if (!bucket || typeof bucket.file !== "function" ||
      typeof processVideo !== "function") {
    throw new TypeError("R2 bucket and Kirari processor are required.");
  }

  return async (event) => {
    const before = event.data?.before?.data?.();
    const after = event.data?.after?.data?.();
    if (!before || !after || before.status === after.status ||
        after.status !== "processing" || after.mediaBackend !== "r2") {
      return null;
    }

    const storagePath = after.originalStoragePath || after.storagePath;
    if (typeof storagePath !== "string" ||
        !/^kirari\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/source\.mp4$/.test(storagePath)) {
      return null;
    }

    const [metadata] = await bucket.file(storagePath).getMetadata();
    return processVideo({ data: {
      name: storagePath,
      bucket: bucket.name,
      size: Number(metadata.size || 0),
      contentType: metadata.contentType || "video/mp4",
      generation: event.id || `firestore-${Date.now()}`,
    } });
  };
}

module.exports = { createKirariR2ProcessingTrigger };
