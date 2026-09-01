"use strict";

const { spawn } = require("node:child_process");
const fs = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");

// Shared by group chat (PROMPT 07) and private chats. Captures collection,
// owner id (groupId or chatId), mediaId, and the original file extension.
const ORIGINAL_PATTERN =
  /^(groups|privateChats)\/([^/]+)\/media\/([^/]+)_original\.([a-zA-Z0-9]+)$/;

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

function createGroupMediaPipeline({ db, bucket, randomUUID }) {
  return async function processGroupMedia(event) {
    const object = event.data || {};
    const match = ORIGINAL_PATTERN.exec(object.name || "");
    if (!match) return null;
    const [, collection, ownerId, mediaId] = match;
    const contentType = object.contentType || "";
    const isImage = contentType.startsWith("image/");
    const isVideo = contentType.startsWith("video/");
    if (!isImage && !isVideo) return null;

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
      mediaType: isImage ? "image" : "video",
      originalPath: sourcePath,
      status: "processing",
      createdAt: new Date(),
    }, { merge: true });

    try {
      await bucket.file(sourcePath).download({ destination: sourceFile });
      if (isImage) {
        const sharp = require("sharp");
        await sharp(sourceFile).rotate().resize({
          width: 320,
          height: 320,
          fit: "inside",
          withoutEnlargement: true,
        }).jpeg({ quality: 72, mozjpeg: true }).toFile(thumbnailFile);
        await sharp(sourceFile).rotate().resize({
          width: 1440,
          height: 1440,
          fit: "inside",
          withoutEnlargement: true,
        }).jpeg({ quality: 82, mozjpeg: true }).toFile(mediumFile);
      } else {
        const ffmpeg = require("ffmpeg-static");
        await runFfmpeg(ffmpeg, [
          "-ss", "00:00:00.500", "-i", sourceFile,
          "-frames:v", "1", "-vf",
          "scale='min(640,iw)':-2:force_original_aspect_ratio=decrease",
          "-q:v", "4", "-y", thumbnailFile,
        ]);
      }

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
        processedAt: new Date(),
      }, { merge: true });

      const messages = await db.collection(collection).doc(ownerId)
        .collection("messages").where("mediaId", "==", mediaId).limit(10).get();
      const batch = db.batch();
      messages.docs.forEach((doc) => batch.update(doc.ref, {
        thumbnailUrl: thumbPath,
        ...(isImage ? { mediaUrl: mediumPath } : {}),
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