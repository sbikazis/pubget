"use strict";

const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");
const { moderateEditCopy } = require("./contentFilter");
const { EDITS_CONFIG, EDIT_RENDITIONS } = require("./editsConfig");
const { setMediaVisible } = require("./reelMediaAccess");

/** Target vertical canvas — same as TikTok / IG Reels / YouTube Shorts. */
const TARGET_W = 1080;
const TARGET_H = 1920;
const TARGET_RATIO = TARGET_W / TARGET_H; // 0.5625 (9:16)
/** Accept near-9:16 without re-framing (± ~8%). */
const RATIO_TOLERANCE = 0.08;

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
      const durationSeconds =
        Number(match[1]) * 3600 + Number(match[2]) * 60 + Number(match[3]);
      const sizeMatch = /(\d{2,5})x(\d{2,5})/.exec(stderr);
      const width = sizeMatch ? Number(sizeMatch[1]) : 0;
      const height = sizeMatch ? Number(sizeMatch[2]) : 0;
      resolve({ durationSeconds, width, height, stderr });
    });
  });
}

function ffmpegBinary() {
  try {
    const packed = require("ffmpeg-static");
    if (packed && fs.existsSync(packed)) return packed;
  } catch (_) {
    // ffmpeg-static is optional when a system ffmpeg is available.
  }
  return "ffmpeg";
}

/**
 * Build the ffmpeg argument list for one rung of the rendition ladder.
 *
 * Pure so the whole ladder is unit-testable without spawning ffmpeg. The
 * `-t` cap and the aspect treatment are shared by every rung, so the ladder
 * cannot silently drift away from the master's duration/aspect behaviour.
 */
function buildRenditionEncodeArgs({
  source,
  destination,
  treatment,
  rendition,
  config = EDITS_CONFIG,
}) {
  const height = Math.max(1, Math.round(Number(rendition.height) || TARGET_H));
  const width = Math.round((height * TARGET_W) / TARGET_H);
  const args = ["-i", source, "-t", String(config.maxDurationSeconds)];
  const wantsBlurPad = treatment.mode === "blur_pad" && rendition.blurPad !== false;

  if (wantsBlurPad) {
    args.push(
      "-filter_complex",
      [
        `[0:v]scale=${width}:${height}:force_original_aspect_ratio=increase,`,
        `crop=${width}:${height},boxblur=20:1[bg];`,
        `[0:v]scale=${width}:${height}:force_original_aspect_ratio=decrease[fg];`,
        `[bg][fg]overlay=(W-w)/2:(H-h)/2`,
      ].join(""),
    );
  } else if (treatment.mode === "center_crop") {
    args.push(
      "-vf",
      `scale=${width}:${height}:force_original_aspect_ratio=increase,` +
      `crop=${width}:${height}`,
    );
  } else {
    // Never upscale: cap the long edge at the rung height and keep AR.
    args.push(
      "-vf",
      `scale='min(${width},iw)':-2:force_original_aspect_ratio=decrease`,
    );
  }

  args.push(
    "-c:v", "libx264",
    "-preset", rendition.preset || "veryfast",
    "-crf", String(rendition.crf),
    "-c:a", "aac",
    "-b:a", `${rendition.audioKbps || 128}k`,
    "-movflags", "+faststart",
    "-y", destination,
  );
  return args;
}

/**
 * §15.2 cover frame.
 *
 * `coverFrameMs` was already validated (0–60000) and persisted by startUpload,
 * but the pipeline seeked to a hardcoded 00:00:00.500 — so the cover the user
 * picked was silently ignored. Resolve it against the real duration and keep the
 * seek safely inside the last frame.
 */
function resolveCoverSeekSeconds(coverFrameMs, durationSeconds) {
  const duration = Number(durationSeconds);
  const requested = Number(coverFrameMs);
  if (!Number.isFinite(duration) || duration <= 0) return 0;
  // Clamp below the final frame so a cover at the very end is still decodable.
  const ceiling = Math.max(0, duration - 0.1);
  if (!Number.isFinite(requested) || requested < 0) return 0;
  return Math.min(ceiling, requested / 1000);
}

/**
 * Drop ladder rungs that would upscale the source.
 *
 * A 480p clip only needs the master; shipping a 1080p "rendition" of it wastes
 * encode time and bytes and makes the ladder lie about the source.
 */
function selectRenditions({ sourceHeight, ladder = EDIT_RENDITIONS }) {
  const ordered = ladder.slice().sort((a, b) => b.height - a.height);
  const height = Number(sourceHeight) || 0;
  if (height <= 0) return ordered;
  const fitting = ordered.filter((rendition) => height >= Number(rendition.height));
  // Always keep the smallest rung so a low-res source still gets a real output.
  return fitting.length ? fitting : ordered.slice(-1);
}

/** Format seconds as an ffmpeg `-ss` argument (HH:MM:SS.mmm). */
function toTimestampArg(seconds) {
  const total = Math.max(0, Number(seconds) || 0);
  const hours = Math.floor(total / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  const secs = total % 60;
  return `${String(hours).padStart(2, '0')}:` +
    `${String(minutes).padStart(2, '0')}:` +
    `${secs.toFixed(3).padStart(6, '0')}`;
}

function renditionStoragePath(prefix, creatorId, editId, rendition, isPrimary) {
  return isPrimary
    ? `${prefix}/${creatorId}/${editId}.mp4`
    : `${prefix}/${creatorId}/${editId}_${rendition.key}.mp4`;
}

/**
 * §15.2 duration verdict: 3–60s.
 *
 * Extracted as a pure predicate so the bound is unit-testable. The inline check
 * it replaced sat behind a real ffmpeg probe, so it was effectively untested —
 * which is how the 3s floor came to be missing while both the config and the
 * copy claimed it existed.
 */
function classifyDuration(durationSeconds, config = EDITS_CONFIG) {
  const seconds = Number(durationSeconds);
  if (!Number.isFinite(seconds) || seconds <= 0) return "invalid";
  if (seconds < config.minDurationSeconds) return "tooShort";
  if (seconds > config.maxDurationSeconds) return "tooLong";
  return "ok";
}

function durationFailureReason(verdict, config = EDITS_CONFIG) {
  if (verdict === "tooShort") {
    return `Videos must be at least ${config.minDurationSeconds} seconds long.`;
  }
  if (verdict === "tooLong") {
    return `Videos can be up to ${config.maxDurationSeconds} seconds long.`;
  }
  return "This video could not be read.";
}

/**
 * Decide how to fit any source into a 9:16 vertical frame.
 * Never rejects on aspect ratio — landscape gets blur-fill, extreme tall gets center-crop.
 */
function decideAspectTreatment(width, height) {
  if (!width || !height || width <= 0 || height <= 0) {
    return { mode: "passthrough", reason: "unknown-dimensions" };
  }
  const ratio = width / height;
  const delta = ratio - TARGET_RATIO;
  if (Math.abs(delta) <= RATIO_TOLERANCE) {
    return { mode: "passthrough", reason: "near-9x16", ratio };
  }
  if (ratio > TARGET_RATIO + RATIO_TOLERANCE) {
    return { mode: "blur_pad", reason: "landscape-or-wide", ratio };
  }
  return { mode: "center_crop", reason: "tall-or-narrow", ratio };
}

/**
 * Lightweight watermark hook — corner edge-density heuristic + caption keywords.
 * Not a full CV model; a real, callable scan that can flag needs_review.
 */
async function detectPlatformWatermark(ffmpeg, source, dir, editData) {
  const reasons = [];
  const caption = `${editData?.caption || ""} ${editData?.animeTag || ""}`.toLowerCase();
  const keywordHits = [
    "tiktok",
    "douyin",
    "instagram",
    "insta reel",
    "youtube short",
    "yt shorts",
    "#shorts",
    "@tiktok",
  ].filter((token) => caption.includes(token));
  if (keywordHits.length) {
    reasons.push(`caption_keyword:${keywordHits[0]}`);
  }

  let brScore = 0;
  let blScore = 0;
  try {
    const frame = path.join(dir, "wm_frame.jpg");
    await run(ffmpeg, [
      "-ss", "00:00:01.000", "-i", source, "-frames:v", "1",
      "-vf", "scale=720:-2", "-q:v", "4", "-y", frame,
    ]);
    const br = path.join(dir, "wm_br.jpg");
    const bl = path.join(dir, "wm_bl.jpg");
    await run(ffmpeg, [
      "-i", frame, "-vf", "crop=iw*0.30:ih*0.14:iw*0.68:ih*0.82", "-y", br,
    ]);
    await run(ffmpeg, [
      "-i", frame, "-vf", "crop=iw*0.30:ih*0.14:0:ih*0.82", "-y", bl,
    ]);

    async function edgeAvg(img) {
      const out = path.join(dir, `edge_${path.basename(img)}`);
      const stderr = await run(ffmpeg, [
        "-i", img,
        "-vf", "edgedetect=low=0.1:high=0.4,signalstats,metadata=print:key=lavfi.signalstats.YAVG",
        "-f", "null", "-",
      ]);
      const match = /YAVG[=:]\s*([\d.]+)/i.exec(stderr) ||
        /lavfi\.signalstats\.YAVG[=:]\s*([\d.]+)/i.exec(stderr);
      if (match) return Number(match[1]);
      // Fallback: file size of edge frame as crude density proxy.
      try {
        await run(ffmpeg, [
          "-i", img, "-vf", "edgedetect=low=0.1:high=0.4", "-frames:v", "1", "-y", out,
        ]);
        const stat = await fsp.stat(out);
        return Math.min(100, stat.size / 400);
      } catch (_) {
        return 0;
      }
    }

    brScore = await edgeAvg(br);
    blScore = await edgeAvg(bl);
    // Persistent corner text (TikTok BR / IG BL) tends to raise edge density.
    if (brScore >= 22) reasons.push("corner_edge_bottom_right");
    if (blScore >= 22) reasons.push("corner_edge_bottom_left");
  } catch (error) {
    return {
      scanned: true,
      engine: "corner-edge-v1",
      suspected: reasons.length > 0,
      reasons,
      error: String(error.message || error),
      brScore,
      blScore,
    };
  }

  return {
    scanned: true,
    engine: "corner-edge-v1",
    suspected: reasons.length > 0,
    reasons,
    brScore,
    blScore,
  };
}

function editSearchName(editData) {
  const parts = [editData && editData.caption, editData && editData.animeTag, editData && editData.animeId];
  return parts.filter(Boolean).join(" ").trim().toLowerCase();
}

function decideEditPublication(editData, processingFields, watermarkScan) {
  const decision = moderateEditCopy({
    caption: editData && editData.caption,
    animeTag: editData && editData.animeTag,
  });
  if (decision.flagged) {
    return {
      update: {
        ...processingFields,
        status: "rejected",
        moderationStatus: "flagged",
        moderationReason: decision.reason,
        watermarkScan: watermarkScan || null,
        processedAt: new Date(),
      },
      publish: false,
      reason: decision.reason,
    };
  }
  if (watermarkScan && watermarkScan.suspected) {
    return {
      update: {
        ...processingFields,
        status: "needs_review",
        moderationStatus: "needs_review",
        moderationReason:
          "Possible third-party platform watermark detected. Held for review.",
        watermarkScan,
        processedAt: new Date(),
      },
      publish: false,
      reason: "watermark",
    };
  }
  return {
    update: {
      ...processingFields,
      status: "published",
      moderationStatus: "approved",
      moderationReason: null,
      watermarkScan: watermarkScan || null,
      searchName: editSearchName(editData) || " ",
    },
    publish: true,
    reason: null,
  };
}

function createEditPipeline({
  db,
  bucket,
  economy,
  achievements,
  notifications,
  FieldValue,
  collectionName = "edits",
  storagePrefix = "edits",
  processedPrefix = "edits-processed",
  config = EDITS_CONFIG,
  deepLinkPrefix = "/edits",
}) {
  async function notifyCreator({ creatorId, editId, kind, reason }) {
    if (!notifications || typeof notifications.build !== "function") return;
        const destination = `${deepLinkPrefix}?highlight=${encodeURIComponent(editId)}`;
    try {
      if (kind === "published") {
        await notifications.build({
          id: `edit_published_${editId}`,
          recipientIds: [creatorId],
          type: "edit_published",
          actorId: creatorId,
          targetId: editId,
          action: "published",
          destination,
          title: "Edit published",
          body: "Your Edit is live. Tap to watch it.",
          pushWorthy: true,
          metadata: { editId },
        });
        return;
      }
      if (kind === "needs_review") {
        await notifications.build({
          id: `edit_review_${editId}`,
          recipientIds: [creatorId],
          type: "edit_needs_review",
          actorId: creatorId,
          targetId: editId,
          action: "needs_review",
          destination,
          title: "Edit held for review",
          body: reason || "Your Edit is waiting for moderation review.",
          pushWorthy: true,
          metadata: { editId, reason: reason || null },
        });
        return;
      }
      await notifications.build({
        id: `edit_failed_${editId}`,
        recipientIds: [creatorId],
        type: "edit_failed",
        actorId: creatorId,
        targetId: editId,
        action: "failed",
        destination,
        title: "Edit processing failed",
        body: reason || "We could not finish processing your Edit. Open the app to retry.",
        pushWorthy: true,
        metadata: { editId, reason: reason || null },
      });
    } catch (error) {
      console.error("Edit outcome notification failed", {
        editId,
        kind,
        error: error && error.message ? error.message : String(error),
      });
    }
  }

  return async function processEdit(event) {
    const object = event.data || {};
    const match = new RegExp(`^${storagePrefix}/([^/]+)/([^/]+)\\.mp4$`)
      .exec(object.name || "");
    if (!match) return null;
    const [, creatorId, editId] = match;
    const ref = db.collection(collectionName).doc(editId);
    const edit = await ref.get();
    if (!edit.exists || edit.data()?.creatorId !== creatorId ||
        !["processing", "uploading"].includes(edit.data()?.status)) return null;
    await ref.update({ status: "processing", processingStartedAt: new Date() });
    if (!(String(object.contentType || "").startsWith("video/mp4")) ||
        Number(object.size || 0) > config.maxBytes) {
      await ref.update({ status: "failed", failureReason: "invalid-video" });
      await notifyCreator({
        creatorId,
        editId,
        kind: "failed",
        reason: "This video is not a supported MP4, or it is too large.",
      });
      return null;
    }
    const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "pubget-edit-"));
    const source = path.join(dir, "source.mp4");
    const thumbnail = path.join(dir, "thumbnail.jpg");
    const processed = path.join(dir, "processed.mp4");
    try {
      await bucket.file(object.name).download({ destination: source });
      const ffmpeg = ffmpegBinary();
      const probed = await probe(ffmpeg, source);
      const durationSeconds = probed.durationSeconds;
      const verdict = classifyDuration(durationSeconds, config);
      if (verdict !== "ok") {
        await ref.update({ status: "failed", failureReason: "duration" });
        await notifyCreator({
          creatorId,
          editId,
          kind: "failed",
          reason: durationFailureReason(verdict, config),
        });
        return null;
      }

      const treatment = decideAspectTreatment(probed.width, probed.height);
      const ladder = selectRenditions({ sourceHeight: probed.height });
      // The primary rung keeps the historical path so stored videoUrl resolves.
      const processedPath = renditionStoragePath(
        processedPrefix,
        creatorId,
        editId,
        ladder[0],
        true,
      );
      const renditions = {};

      for (const [index, rendition] of ladder.entries()) {
        const isPrimary = index === 0;
        const destination = isPrimary
          ? processed
          : path.join(dir, `processed_${rendition.key}.mp4`);
        const encodeArgs = buildRenditionEncodeArgs({
          source,
          destination,
          treatment,
          rendition,
          config,
        });
        try {
          await run(ffmpeg, encodeArgs);
        } catch (encodeError) {
          console.error("Aspect treatment failed; falling back to scale", {
            editId,
            rendition: rendition.key,
            treatment,
            error: encodeError.message,
          });
          // Last-resort: never reject solely for aspect — plain scale.
          await run(ffmpeg, [
            "-i", source, "-t", String(config.maxDurationSeconds),
            "-vf", `scale='min(${Math.round((rendition.height * TARGET_W) / TARGET_H)},iw)':-2:force_original_aspect_ratio=decrease`,
            "-c:v", "libx264", "-preset", rendition.preset, "-crf", String(rendition.crf),
            "-c:a", "aac", "-b:a", `${rendition.audioKbps}k`,
            "-movflags", "+faststart", "-y", destination,
          ]);
        }
        const destinationPath = renditionStoragePath(
          processedPrefix,
          creatorId,
          editId,
          rendition,
          isPrimary,
        );
        await bucket.upload(destination, {
          destination: destinationPath, resumable: false,
          metadata: {
            contentType: "video/mp4",
            metadata: { generatedBy: "pubget-edit-v3", rendition: rendition.key },
          },
        });
        renditions[rendition.key] = {
          path: destinationPath,
          label: rendition.label,
          height: rendition.height,
        };
      }

      const watermarkScan = await detectPlatformWatermark(
        ffmpeg,
        source,
        dir,
        edit.data() || {},
      );

      // §15.2: seek to the cover frame the creator picked, not a fixed 500ms.
      const coverSeek = resolveCoverSeekSeconds(
        (edit.data() || {}).coverFrameMs,
        durationSeconds,
      );
      await run(ffmpeg, [
        "-ss", toTimestampArg(coverSeek), "-i", processed, "-frames:v", "1",
        "-vf", `scale='min(720,iw)':-2:force_original_aspect_ratio=decrease`,
        "-q:v", "4", "-y", thumbnail,
      ]);
      const thumbnailPath = `${storagePrefix}/${creatorId}/t_${editId}.jpg`;
      await bucket.upload(thumbnail, {
        destination: thumbnailPath, resumable: false,
        metadata: {
          contentType: "image/jpeg",
          metadata: {
            generatedBy: "pubget-edit-v3",
            coverFrameMs: Math.round(coverSeek * 1000),
          },
        },
      });
      const creator = await db.collection("users").doc(creatorId).get();
      const creatorQuality = Math.min(10, Math.max(
        0,
        Number(creator.data()?.totalRespect || 0) * 0.5,
      ));
      // Count, do not fetch: this is a lifetime count used for achievements, and the
// old `limit(6).get()` reported 6+1 for any creator past six posts.
      const publishedCount = await db.collection(collectionName)
        .where("creatorId", "==", creatorId)
        .where("status", "==", "published")
        .count()
        .get()
        .then((snap) => Number(snap.data()?.count) || 0)
        .catch(() => 0);
      const decision = decideEditPublication(edit.data() || {}, {
        videoUrl: processedPath,
        thumbnailUrl: thumbnailPath,
        originalStoragePath: object.name,
        processedStoragePath: processedPath,
        thumbnailStoragePath: thumbnailPath,
        renditions,
        renditionsAvailable: Object.keys(renditions).length > 1,
        durationSeconds,
        sourceWidth: probed.width || null,
        sourceHeight: probed.height || null,
        aspectTreatment: treatment,
        score: 20 + creatorQuality,
        processedAt: new Date(),
        creatorQuality,
        schemaVersion: config.schemaVersion,
      }, watermarkScan);
      if (decision.publish) {
        decision.update.publishedAt = new Date();
      }
      await ref.update(decision.update);
      // §15.18 — publish the bytes. Until this receipt exists the Storage
      // rules refuse to serve the transcoded renditions, because nothing has
      // authorised them. Without it a correctly published Reel would render a
      // black frame, so the flip has to happen exactly here and not earlier.
      if (decision.publish) {
        await setMediaVisible({
          db,
          bucket,
          creatorId,
          editId,
          visible: true,
          storagePrefix,
          processedPrefix,
          collectionName,
          FieldValue,
        }).catch((error) => {
          console.error("Edit media publication failed", {
            editId,
            error: error.message,
          });
          throw error;
        });
      }
      if (!decision.publish) {
        const status = decision.update.status;
        if (status === "needs_review") {
          await notifyCreator({
            creatorId,
            editId,
            kind: "needs_review",
            reason: decision.update.moderationReason || decision.reason,
          });
        } else if (status === "rejected" || status === "failed") {
          await notifyCreator({
            creatorId,
            editId,
            kind: "failed",
            reason: decision.update.moderationReason || decision.reason,
          });
        }
        return null;
      }
      if (economy && typeof economy.applyReward === "function") {
        await economy.applyReward({
          userId: creatorId,
          type: "earn_publish",
          referenceId: editId,
          source: "edit",
        });
      }
      if (achievements && typeof achievements.evaluate === "function") {
        // publishedWorks is an absolute count so re-evaluation is idempotent.
        await achievements.evaluate({
          type: "edit_published",
          userId: creatorId,
          source: "edit",
          metadata: {
            editId,
            publishedWorks: publishedCount + 1,
            publishedCount: publishedCount + 1,
          },
        });
      }
      await notifyCreator({ creatorId, editId, kind: "published" });
    } catch (error) {
      await ref.update({ status: "failed", failureReason: "processing-failed" });
      console.error("Edit processing failed", { editId, error: error.message });
      await notifyCreator({
        creatorId,
        editId,
        kind: "failed",
        reason: "We could not finish processing your Edit. Open the app to retry.",
      });
    } finally {
      await fsp.rm(dir, { recursive: true, force: true });
    }
    return null;
  };
}

module.exports = {
  createEditPipeline,
  decideEditPublication,
  classifyDuration,
  durationFailureReason,
  decideAspectTreatment,
  buildRenditionEncodeArgs,
  resolveCoverSeekSeconds,
  selectRenditions,
  renditionStoragePath,
  toTimestampArg,
  detectPlatformWatermark,
  TARGET_W,
  TARGET_H,
  TARGET_RATIO,
  RATIO_TOLERANCE,
};
