"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

function run(binary, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("exit", (code) => code === 0 ? resolve(stderr) :
      reject(new Error(`ffmpeg failed: ${code} ${stderr.slice(-500)}`)));
  });
}

function probe(binary, source) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, ["-i", source], { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("exit", () => {
      const match = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(stderr);
      if (!match) return reject(new Error("Video duration unavailable"));
      resolve(Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]));
    });
  });
}

function createEditPipeline({ db, bucket, economy, achievements }) {
  return async function processEdit(event) {
    const object = event.data || {};
    const match = /^edits\/([^/]+)\/([^/]+)\.mp4$/.exec(object.name || "");
    if (!match) return null;
    const [, creatorId, editId] = match;
    const ref = db.collection("edits").doc(editId);
    const edit = await ref.get();
    if (!edit.exists || edit.data()?.creatorId !== creatorId ||
        !["processing", "uploading"].includes(edit.data()?.status)) return null;
    await ref.update({ status: "processing", processingStartedAt: new Date() });
    if (object.contentType !== "video/mp4" || Number(object.size || 0) > 250 * 1024 * 1024) {
      await ref.update({ status: "failed", failureReason: "invalid-video" });
      return null;
    }
    const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "pubget-edit-"));
    const source = path.join(dir, "source.mp4");
    const thumbnail = path.join(dir, "thumbnail.jpg");
    const processed = path.join(dir, "processed.mp4");
    try {
      await bucket.file(object.name).download({ destination: source });
      const ffmpeg = require("ffmpeg-static");
      const durationSeconds = await probe(ffmpeg, source);
      if (durationSeconds <= 0 || durationSeconds > 180) {
        throw new Error("Video duration is outside the 180 second limit");
      }
      await run(ffmpeg, [
        "-i", source, "-t", "180", "-vf",
        "scale='min(1080,iw)':-2:force_original_aspect_ratio=decrease",
        "-c:v", "libx264", "-preset", "veryfast", "-crf", "25",
        "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart",
        "-y", processed,
      ]);
      await run(ffmpeg, [
        "-ss", "00:00:00.500", "-i", source, "-frames:v", "1",
        "-vf", "scale='min(720,iw)':-2:force_original_aspect_ratio=decrease",
        "-q:v", "4", "-y", thumbnail,
      ]);
      const thumbnailPath = `edits/${creatorId}/t_${editId}.jpg`;
      const processedPath = `edits-processed/${creatorId}/${editId}.mp4`;
      await bucket.upload(thumbnail, {
        destination: thumbnailPath, resumable: false,
        metadata: { contentType: "image/jpeg", metadata: { generatedBy: "pubget-edit-v1" } },
      });
      await bucket.upload(processed, {
        destination: processedPath, resumable: false,
        metadata: { contentType: "video/mp4", metadata: { generatedBy: "pubget-edit-v1" } },
      });
      const creator = await db.collection("users").doc(creatorId).get();
      const creatorQuality = Math.min(10, Math.max(
        0,
        Number(creator.data()?.totalRespect || 0) * 0.5,
      ));
      const published = await db.collection("edits")
        .where("creatorId", "==", creatorId)
        .where("status", "==", "published")
        .limit(6)
        .get()
        .catch(() => ({ size: 0, docs: [] }));
      await ref.update({
        videoUrl: processedPath, thumbnailUrl: thumbnailPath, durationSeconds,
        status: "published", score: 20 + creatorQuality, processedAt: new Date(),
        creatorQuality,
      });
      if (economy && typeof economy.applyReward === "function") {
        await economy.applyReward({
          userId: creatorId,
          type: "earn_publish",
          referenceId: editId,
          source: "edit",
        });
      }
      if (achievements && typeof achievements.evaluate === "function") {
        await achievements.evaluate({
          type: "edit_published",
          userId: creatorId,
          source: "edit",
          metadata: { editId, publishedCount: (published.size || 0) + 1 },
        });
      }
    } catch (error) {
      await ref.update({ status: "failed", failureReason: "processing-failed" });
      console.error("Edit processing failed", { editId, error: error.message });
    } finally {
      await fsp.rm(dir, { recursive: true, force: true });
    }
    return null;
  };
}

module.exports = { createEditPipeline };