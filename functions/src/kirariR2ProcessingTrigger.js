"use strict";

/**
 * Converts a Firestore media-state transition into the Storage-compatible
 * event contract consumed by the existing Kirari FFmpeg pipeline.
 *
 * Only R2-backed records entering processing are handled here. Legacy
 * Firebase Storage records continue through their object-finalize trigger.
 */
function createKirariR2ProcessingTrigger({ bucket, processVideo, db }) {
  if (!bucket || typeof bucket.file !== "function" ||
      typeof processVideo !== "function" || !db) {
    throw new TypeError("R2 bucket, Firestore, and Kirari processor are required.");
  }

  return async (event) => {
    const before = event.data?.before?.data?.();
    const after = event.data?.after?.data?.();
    if (!before || !after || !["uploading", "failed"].includes(before.status) ||
        after.status !== "processing" || after.mediaBackend !== "r2") {
      return null;
    }

    const storagePath = after.originalStoragePath || after.storagePath;
    if (typeof storagePath !== "string" ||
        !/^kirari\/[A-Za-z0-9_-]{1,128}\/[A-Za-z0-9_-]{1,128}\/source\.mp4$/.test(storagePath)) {
      return null;
    }

    let metadata;
    try {
      [metadata] = await bucket.file(storagePath).getMetadata();
    } catch (error) {
      const reelId = event.params?.reelId;
      if (!reelId) throw error;
      await db.collection("kirari").doc(reelId).update({
        status: "failed",
        failureReason: "r2-source-unavailable",
        processingErrorCode: "R2_SOURCE_UNAVAILABLE",
        failedAt: new Date(),
        processingLeaseId: null,
        processingLeaseUntil: new Date(0),
      });
      return null;
    }
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
