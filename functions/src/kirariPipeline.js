"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { KIRARI } = require("./kirariDomain");
const { moderateEditCopy } = require("./contentFilter");

function run(binary, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("exit", (code) => code === 0
      ? resolve(stderr)
      : reject(new Error(`Kirari FFmpeg failed (${code}): ${stderr.slice(-1200)}`)));
  });
}

function ffmpegBinary() {
  try {
    const binary = require("ffmpeg-static");
    if (binary && fs.existsSync(binary)) return binary;
  } catch (_) {
    // The deployed runtime may provide ffmpeg on PATH.
  }
  return "ffmpeg";
}

function ffprobeBinary() {
  try {
    const binary = require("ffprobe-static").path;
    if (binary && fs.existsSync(binary)) return binary;
  } catch (_) {
    // Fall back to parsing FFmpeg's input metadata.
  }
  return null;
}

async function probeVideo(binary, file) {
  const ffprobe = ffprobeBinary();
  if (ffprobe) {
    const output = await new Promise((resolve, reject) => {
      const child = spawn(ffprobe, [
        "-v", "error", "-show_entries",
        "format=duration:stream=codec_type,width,height",
        "-of", "json", file,
      ], { stdio: ["ignore", "pipe", "pipe"] });
      let stdout = "";
      let stderr = "";
      child.stdout.on("data", (chunk) => { stdout += chunk.toString(); });
      child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
      child.once("error", reject);
      child.once("exit", (code) => code === 0 ? resolve(stdout) : reject(new Error(stderr)));
    });
    const parsed = JSON.parse(output);
    const video = (parsed.streams || []).find((stream) => stream.codec_type === "video");
    return {
      durationSeconds: Number(parsed.format?.duration || 0),
      width: Number(video?.width || 0),
      height: Number(video?.height || 0),
    };
  }
  const stderr = await run(binary, ["-i", file]);
  const match = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(stderr);
  const dimensions = /(\d{2,5})x(\d{2,5})/.exec(stderr);
  if (!match) throw new Error("Unable to read video duration.");
  return {
    durationSeconds: Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]),
    width: dimensions ? Number(dimensions[1]) : 0,
    height: dimensions ? Number(dimensions[2]) : 0,
  };
}

function renditionArgs(source, output, height, bitrate) {
  return [
    "-i", source, "-map", "0:v:0", "-map", "0:a?",
    "-vf", `scale=-2:${height}:force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2`,
    "-c:v", "libx264", "-preset", "veryfast", "-b:v", bitrate,
    "-maxrate", bitrate, "-bufsize", bitrate,
    "-c:a", "aac", "-b:a", "96k",
    "-movflags", "+faststart", "-y", output,
  ];
}

function createKirariPipeline({ db, bucket }) {
  return async (event) => {
    const object = event.data || event;
    const objectName = object.name || "";
    const match = /^kirari\/([^/]+)\/([^/]+)\/source\.mp4$/.exec(objectName);
    if (!match || !object.bucket) return null;
    const [, uid, reelId] = match;
    const ref = db.collection("kirari").doc(reelId);
    const snap = await ref.get();
    if (!snap.exists) return null;
    const reel = snap.data();
    if (reel.creatorId !== uid || reel.originalStoragePath !== objectName) return null;
    if (["published", "rejected", "deleted"].includes(reel.status)) return null;
    if (!["uploading", "processing"].includes(reel.status)) return null;

    const lockRef = db.collection("kirariUploadLocks").doc(uid);
    const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "kirari-"));
    const source = path.join(dir, "source.mp4");
    const ffmpeg = ffmpegBinary();
    try {
      await ref.update({
        status: "processing",
        processingStartedAt: db.constructor.FieldValue?.serverTimestamp?.() || new Date(),
      }).catch(() => {});
      await bucket.file(objectName).download({ destination: source });
      const metadata = await probeVideo(ffmpeg, source);
      if (metadata.durationSeconds < KIRARI.minDurationSeconds ||
          metadata.durationSeconds > KIRARI.maxDurationSeconds) {
        await ref.update({
          status: "rejected", moderationStatus: "rejected",
          failureReason: "duration",
          moderationReason: "Kirari videos must be between 3 and 60 seconds.",
          rejectedAt: new Date(),
        });
        return null;
      }
      const decision = moderateEditCopy({
        caption: reel.caption,
        animeTag: (reel.hashtags || []).join(" "),
      });
      if (decision.flagged) {
        await ref.update({
          status: "rejected", moderationStatus: "rejected",
          moderationReason: decision.reason || "Content did not pass moderation.",
          rejectedAt: new Date(),
        });
        return null;
      }
      await ref.update({
        status: "preparing",
        durationSeconds: Math.round(metadata.durationSeconds * 1000) / 1000,
        sourceWidth: metadata.width,
        sourceHeight: metadata.height,
        preparingAt: new Date(),
      });
      const variants = {};
      for (const [height, bitrate] of [[360, "650k"], [540, "1200k"], [720, "2500k"]]) {
        const output = path.join(dir, `${height}.mp4`);
        await run(ffmpeg, renditionArgs(source, output, height, bitrate));
        const destination = `kirari-processed/${uid}/${reelId}/${height}.mp4`;
        await bucket.upload(output, {
          destination, resumable: false,
          metadata: {
            contentType: "video/mp4",
            metadata: { ownerUid: uid, reelId, renditionHeight: String(height) },
          },
        });
        const [meta] = await bucket.file(destination).getMetadata();
        variants[String(height)] = {
          path: destination,
          sizeBytes: Number(meta.size || 0),
          contentType: "video/mp4",
        };
      }
      const cover = path.join(dir, "cover.jpg");
      await run(ffmpeg, [
        "-ss", "0.5", "-i", source, "-frames:v", "1",
        "-vf", "scale='min(720,iw)':-2:force_original_aspect_ratio=decrease",
        "-q:v", "3", "-y", cover,
      ]);
      const coverPath = `kirari-processed/${uid}/${reelId}/cover.jpg`;
      await bucket.upload(cover, {
        destination: coverPath, resumable: false,
        metadata: {
          contentType: "image/jpeg",
          metadata: { ownerUid: uid, reelId, generatedBy: "kirari-pipeline-v1" },
        },
      });
      await ref.update({
        status: "published",
        moderationStatus: "approved",
        renditions: variants,
        coverPath,
        publishedAt: new Date(),
        processedAt: new Date(),
        failureReason: null,
      });
      await lockRef.delete().catch(() => {});
      return null;
    } catch (error) {
      await ref.update({
        status: "failed",
        failureReason: "processing-failed",
        processingErrorCode: "KIRARI_PROCESSING_FAILED",
        failedAt: new Date(),
      }).catch(() => {});
      await lockRef.delete().catch(() => {});
      console.error("Kirari processing failed", {
        reelId, error: error && error.message ? error.message : String(error),
      });
      throw error;
    } finally {
      await fsp.rm(dir, { recursive: true, force: true });
    }
  };
}

module.exports = { createKirariPipeline, probeVideo, renditionArgs };
