"use strict";

const { spawn } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

// Shared by group chat (PROMPT 07) and private chats. Captures collection,
// owner id (groupId or chatId), mediaId, and the original file extension.
const ORIGINAL_PATTERN =
  /^(groups|privateChats)\/([^/]+)\/media\/([^/]+)_original\.([a-zA-Z0-9]+)$/;

// Derivative sizes. The chat bubble is at most ~75% of the viewport width and
// the pipeline runs on phones with DPR 3, so a 250-logical-px bubble needs up
// to ~750 physical px to stay sharp. 320px thumbnails were visibly upscaled and
// therefore blurry; 640 covers DPR 3 with headroom, and 1600 covers the
// full-screen viewer without making the bubble payload heavy.
const THUMBNAIL_MAX_EDGE = 640;
const MEDIUM_MAX_EDGE = 1600;

function runFfmpeg(binary, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, args, { stdio: "ignore" });
    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited with code ${code}`));
    });
  });
}

/// Display-oriented pixel dimensions of an already-rotated raster.
async function readDimensions(file) {
  const sharp = require("sharp");
  const metadata = await sharp(file).metadata();
  const width = Number(metadata.width) || 0;
  const height = Number(metadata.height) || 0;
  if (width <= 0 || height <= 0) return null;
  return { width, height };
}

function createGroupMediaPipeline({ db, bucket, randomUUID }) {
  return async function processGroupMedia(event) {
    const object = event.data || {};
    const match = ORIGINAL_PATTERN.exec(object.name || "");
    if (!match) return null;
    const [, collection, ownerId, mediaId] = match;
    const contentType = object.contentType || "";
    const isImage = contentType.startsWith("image/");
    const isVideo = contentType.startsWith("video/");
    const isAudio = contentType.startsWith("audio/");
    if (!isImage && !isVideo && !isAudio) return null;

    const sourcePath = object.name;
    const workDir = await fs.mkdtemp(path.join(os.tmpdir(), "pubget-chat-"));
    const sourceFile = path.join(workDir, `source.${match[4]}`);
    const thumbnailFile = path.join(workDir, "thumbnail.jpg");
    const mediumFile = path.join(workDir, "medium.jpg");
    const thumbPath = `${collection}/${ownerId}/media/${mediaId}_thumb.jpg`;
    const mediumPath = `${collection}/${ownerId}/media/${mediaId}_medium.jpg`;
    const mediaRef = db.collection(collection).doc(ownerId)
      .collection("media").doc(mediaId);

    await mediaRef.set({
      mediaId,
      uploaderId: object.metadata && object.metadata.uploadedBy || null,
      mediaType: isImage ? "image" : isVideo ? "video" : "audio",
      originalPath: sourcePath,
      status: "processing",
      createdAt: new Date(),
    }, { merge: true });

    // Voice notes: 60s / 10MB client contract. Storage allows 25MB; reject
    // oversized originals here so sendGroupMessage never sees them as ready.
    if (isAudio) {
      const size = Number(object.size) || 0;
      if (size > 10 * 1024 * 1024) {
        await mediaRef.set({
          status: "failed",
          errorCode: "audio-too-large",
          failedAt: new Date(),
        }, { merge: true });
        return null;
      }
      await mediaRef.set({
        status: "ready",
        thumbnailPath: null,
        mediumPath: null,
        processedAt: new Date(),
        maxDurationSeconds: 60,
      }, { merge: true });
      return null;
    }

    try {
      await bucket.file(sourcePath).download({ destination: sourceFile });
      if (isImage) {
        const sharp = require("sharp");
        // fit: "inside" never crops, so the derivative keeps the source ratio
        // and the client can render the bubble at the real aspect ratio.
        await sharp(sourceFile).rotate().resize({
          width: THUMBNAIL_MAX_EDGE,
          height: THUMBNAIL_MAX_EDGE,
          fit: "inside",
          withoutEnlargement: true,
        }).jpeg({ quality: 74, mozjpeg: true }).toFile(thumbnailFile);
        await sharp(sourceFile).rotate().resize({
          width: MEDIUM_MAX_EDGE,
          height: MEDIUM_MAX_EDGE,
          fit: "inside",
          withoutEnlargement: true,
        }).jpeg({ quality: 84, mozjpeg: true }).toFile(mediumFile);
      } else {
        const ffmpeg = require("ffmpeg-static");
        await runFfmpeg(ffmpeg, [
          "-ss", "00:00:00.500", "-i", sourceFile,
          "-frames:v", "1", "-vf",
          `scale='min(${THUMBNAIL_MAX_EDGE},iw)':-2:force_original_aspect_ratio=decrease`,
          "-q:v", "4", "-y", thumbnailFile,
        ]);
      }

      // Display-oriented dimensions of the source. Without these the client has
      // to guess an aspect ratio and every photo gets cropped or letterboxed in
      // the bubble, and the image has to be probed (a full decode) at render
      // time. Read them once here, server-side, and ship them on the document.
      const dimensions = await readDimensions(
        isImage ? mediumFile : thumbnailFile,
      );
      const width = dimensions ? dimensions.width : null;
      const height = dimensions ? dimensions.height : null;

      const uploadOptions = {
        resumable: false,
        metadata: {
          contentType: "image/jpeg",
          metadata: {
            generatedBy: "pubget-chat-v1",
          },
        },
      };
      await bucket.upload(thumbnailFile, {
        ...uploadOptions,
        destination: thumbPath,
      });
      if (isImage) {
        await bucket.upload(mediumFile, {
          ...uploadOptions,
          destination: mediumPath,
        });
      }
      await mediaRef.set({
        status: "ready",
        thumbnailPath: thumbPath,
        mediumPath: isImage ? mediumPath : null,
        ...(width && height ? { width, height } : {}),
        processedAt: new Date(),
      }, { merge: true });

      const messages = await db.collection(collection).doc(ownerId)
        .collection("messages").where("mediaId", "==", mediaId).limit(10).get();
      const batch = db.batch();
      messages.docs.forEach((doc) => batch.update(doc.ref, {
        thumbnailUrl: thumbPath,
        ...(isImage ? { mediaUrl: mediumPath } : {}),
        ...(width && height ? { mediaWidth: width, mediaHeight: height } : {}),
      }));
      if (!messages.empty) await batch.commit();
    } catch (error) {
      await mediaRef.set({
        status: "failed",
        errorCode: "processing-failed",
        failedAt: new Date(),
      }, { merge: true });
      console.error("Chat media processing failed", {
        collection,
        ownerId,
        mediaId,
        error: error && error.message,
      });
      throw error;
    } finally {
      await fs.rm(workDir, { recursive: true, force: true });
    }
    return null;
  };
}

module.exports = {
  ORIGINAL_PATTERN,
  createGroupMediaPipeline,
};