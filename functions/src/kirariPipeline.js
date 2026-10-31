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
    const streams = parsed.streams || [];
    const video = streams.find((stream) => stream.codec_type === "video");
    const audio = streams.some((stream) => stream.codec_type === "audio");
    return {
      durationSeconds: Number(parsed.format?.duration || 0),
      width: Number(video?.width || 0),
      height: Number(video?.height || 0),
      hasAudio: audio,
    };
  }
  const stderr = await new Promise((resolve, reject) => {
    const child = spawn(binary, ["-i", file], { stdio: ["ignore", "ignore", "pipe"] });
    let output = "";
    child.stderr.on("data", (chunk) => { output += chunk.toString(); });
    child.once("error", reject);
    // ffmpeg -i without an output target exits non-zero after printing metadata.
    child.once("exit", () => resolve(output));
  });
  const match = /Duration:\\s*(\\d+):(\\d+):(\\d+(?:\\.\\d+)?)/.exec(stderr);
  const dimensions = /(\\d{2,5})x(\\d{2,5})/.exec(stderr);
  if (!match) throw new Error("Unable to read video duration.");
  return {
    durationSeconds: Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]),
    width: dimensions ? Number(dimensions[1]) : 0,
    height: dimensions ? Number(dimensions[2]) : 0,
    hasAudio: /Audio:/.test(stderr),
  };
}

function renditionArgs(source, output, height, bitrate) {
  const width = Math.floor((height * 9 / 16) / 2) * 2;
  return [
    "-i", source, "-map", "0:v:0", "-map", "0:a?",
    "-vf", "scale=" + width + ":" + height + ":force_original_aspect_ratio=increase",crop=" + width + ":" + height,
    "-c:v", "libx264", "-preset", "veryfast", "-b:v", bitrate,
    "-maxrate", bitrate, "-bufsize", bitrate,
    "-c:a", "aac", "-b:a", "96k",
    "-movflags", "+faststart", "-y", output,
  ];
}

function escapeDrawtext(value) {
  return String(value).replace(/\\/g, "\\\\")
    .replace(/:/g, "\\:").replace(/'/g, "\\'")
    .replace(/%/g, "\\%");
}

function editorVideoFilter(width, height, settings) {
  const filters = [
    "scale=" + width + ":" + height + ":force_original_aspect_ratio=increase",
    "crop=" + width + ":" + height,
  ];
  switch (settings.filter) {
    case "warm": filters.push("eq=saturation=1.15:contrast=1.05", "colorbalance=rs=.08:gs=.02"); break;
    case "cool": filters.push("eq=saturation=1.1", "colorbalance=bs=.10"); break;
    case "mono": filters.push("hue=s=0"); break;
    case "vivid": filters.push("eq=saturation=1.35:contrast=1.1"); break;
    default: break;
  }
  if (settings.overlayText) filters.push("drawtext=text='" + escapeDrawtext(settings.overlayText) +
    "':fontcolor=white:fontsize=42:borderw=3:bordercolor=black@0.7:x=(w-text_w)/2:y=h*0.78");
  filters.push("setpts=PTS/" + settings.speed);
  return filters.join(",");
}
function createKirariPipeline({ db, bucket }) {
  return async (event) => {
    const object = event.data || event;
    const objectName = object.name || "";
    const match = /^kirari\/([^/]+)\/([^/]+)\/source\.mp4$/.exec(objectName);
    if (!match || !object.bucket || object.bucket !== bucket.name) return null;
    const [, uid, reelId] = match;
    const ref = db.collection("kirari").doc(reelId);
    const snap = await ref.get();
    if (!snap.exists) return null;
    const reel = snap.data();
    if (reel.creatorId !== uid || reel.originalStoragePath !== objectName) return null;
    if (["published", "rejected", "deleted"].includes(reel.status)) return null;
    const sourceSize = Number(object.size || 0);
    const sourceType = String(object.contentType || "");
    if (sourceSize <= 0 || sourceSize > KIRARI.maxBytes || !sourceType.startsWith("video/")) {
      await ref.update({
        status: "failed",
        failureReason: "invalid-source",
        failedAt: new Date(),
      });
      await db.collection("kirariUploadLocks").doc(uid).delete().catch(() => {});
      return null;
    }
    if (!["uploading", "processing"].includes(reel.status)) return null;

    const leaseId = String(object.generation || object.metageneration || Date.now());
    const leaseAcquired = await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      if (!current.exists || !["uploading", "processing"].includes(current.data()?.status)) return false;
      const leaseUntil = current.data()?.processingLeaseUntil?.toMillis?.() || 0;
      if (leaseUntil > Date.now()) return false;
      tx.update(ref, {
        status: "processing",
        processingLeaseId: leaseId,
        processingLeaseUntil: new Date(Date.now() + 10 * 60 * 1000),
      });
      return true;
    });
    if (!leaseAcquired) return null;

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
          processingLeaseId: null,
          processingLeaseUntil: new Date(0),
        });
        await lockRef.delete().catch(() => {});
        return null;
      }
      const decision = moderateEditCopy({
        caption: reel.caption,
        animeTag: (reel.hashtags || []).join(" "),
      });
      if (decision.flagged) {
        await ref.update({
          moderationStatus: "review_pending",
          moderationReason: decision.reason || "Content did not pass moderation.",
        });
        await db.collection("kirariModerationQueue").doc("reel_" + reelId).set({
          contentType: "reel", reelId, status: "pending",
          reason: decision.reason || "Automated text moderation flagged this upload.",
          queuedAt: new Date(),
        }, { merge: true });
      }
      await ref.update({
        status: "preparing",
        durationSeconds: Math.round(metadata.durationSeconds * 1000) / 1000,
        sourceWidth: metadata.width,
        sourceHeight: metadata.height,
        preparingAt: new Date(),
      });
      const settings = reel.editSettings || {};
      const trimStart = Math.max(0, Math.min(Number(settings.trimStartSeconds) || 0, Math.max(0, metadata.durationSeconds - 3)));
      const requestedEnd = Number(settings.trimEndSeconds);
      const trimEnd = Math.min(metadata.durationSeconds, Math.max(trimStart + 3, requestedEnd > trimStart ? requestedEnd : metadata.durationSeconds));
      const clipDuration = trimEnd - trimStart;
      const speed = Math.max(0.5, Math.min(2, Number(settings.speed) || 1));
      const audioTrack = reel.audioId ? await db.collection("kirariAudio").doc(reel.audioId).get() : null;
      const audioData = audioTrack && audioTrack.exists ? audioTrack.data() : null;
      const audioSource = audioData && audioData.status === "approved" && audioData.allowReuse === true && audioData.audioPath
        ? path.join(dir, "selected-audio") : null;
      if (audioSource) await bucket.file(audioData.audioPath).download({ destination: audioSource });
      const variants = {};
      for (const [height, bitrate] of [[360, "650k"], [540, "1200k"], [720, "2500k"]]) {
        const output = path.join(dir, String(height) + ".mp4");
        const width = Math.floor((height * 9 / 16) / 2) * 2;
        const args = ["-ss", String(trimStart), "-i", source];
        if (audioSource) args.push("-stream_loop", "-1", "-i", audioSource);
        args.push("-t", String(clipDuration), "-map", "0:v:0");
        if (audioSource && metadata.hasAudio) {
          args.push("-filter_complex",
            "[0:a]volume=0.25,atempo=" + speed + "[sourceaudio];" +
            "[1:a]volume=0.85,atempo=" + speed + "[trackaudio];" +
            "[sourceaudio][trackaudio]amix=inputs=2:duration=first:dropout_transition=2[aout]",
            "-map", "[aout]");
        } else if (audioSource) {
          args.push("-map", "1:a:0", "-af", "atempo=" + speed);
        } else if (metadata.hasAudio) {
          args.push("-map", "0:a:0", "-af", "atempo=" + speed);
        }
        args.push("-vf", editorVideoFilter(width, height, { ...settings, speed }));
        args.push("-c:v", "libx264", "-preset", "veryfast", "-b:v", bitrate,
          "-maxrate", bitrate, "-bufsize", bitrate, "-c:a", "aac", "-b:a", "128k",
          "-movflags", "+faststart", "-shortest", "-y", output);
        await run(ffmpeg, args);
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
      const coverTime = Math.max(trimStart, Math.min(Number(settings.coverTimeSeconds) || trimStart, trimEnd - 0.1));
      await run(ffmpeg, [
        "-ss", String(coverTime), "-i", source, "-frames:v", "1",
        "-vf", "scale=404:720:force_original_aspect_ratio=increase,crop=404:720",
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
        moderationStatus: decision.flagged ? "review_pending" : "approved",
        rankingScore: 20,
        velocityScore: 0,
        renditions: variants,
        coverPath,
        editSettings: { ...settings, trimStartSeconds: trimStart, trimEndSeconds: trimEnd, speed, coverTimeSeconds: coverTime },
        audioAttribution: audioData ? { audioId: reel.audioId, title: audioData.title || "Original audio", artist: audioData.artist || "", license: audioData.license || "unknown", sourceCreatorId: audioData.creatorId || null } : null,
        publishedAt: new Date(),
        processedAt: new Date(),
        failureReason: null,
        processingLeaseId: null,
        processingLeaseUntil: new Date(0),
      });
      await lockRef.delete().catch(() => {});
      return null;
    } catch (error) {
      await ref.update({
        status: "failed",
        failureReason: "processing-failed",
        processingErrorCode: "KIRARI_PROCESSING_FAILED",
        failedAt: new Date(),
        processingLeaseId: null,
        processingLeaseUntil: new Date(0),
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

module.exports = { createKirariPipeline, probeVideo, renditionArgs, editorVideoFilter };
