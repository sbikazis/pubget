"use strict";

const { HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const os = require("node:os");
const path = require("node:path");
const fsp = require("node:fs/promises");
const { spawn } = require("node:child_process");

const AUDIO_COLLECTION = "reelAudios";
const AUDIO_USAGE_COLLECTION = "reelAudioUsage";

function uid(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication is required.");
  return request.auth.uid;
}

function string(value, max) {
  return typeof value === "string" && value.trim().length <= max
    ? value.trim()
    : null;
}

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

function ffmpegBinary() {
  try {
    const packed = require("ffmpeg-static");
    if (packed && require("node:fs").existsSync(packed)) return packed;
  } catch (_) {}
  return "ffmpeg";
}

async function extractAudioSegment(ffmpeg, source, output, startMs, durationMs) {
  const args = [
    "-i", source,
    "-ss", (startMs / 1000).toFixed(3),
    "-t", (durationMs / 1000).toFixed(3),
    "-vn",
    "-c:a", "aac",
    "-b:a", "128k",
    "-y", output,
  ];
  await run(ffmpeg, args);
}

/** §15.8 — the client sends a sort intent; unknown values fall back to trending. */
function normalizeAudioSort(raw) {
  const value = typeof raw === "string" ? raw.trim().toLowerCase() : "";
  if (value === "newest" || value === "popular") return value;
  return "trending";
}

function createAudioDomain({ db, bucket, FieldValue, HttpsError, reelCollection = "reels" }) {
  function audioRef(audioId) {
    return db.collection(AUDIO_COLLECTION).doc(audioId);
  }

  function audioUsageRef(audioId, reelId) {
    return db.collection(AUDIO_COLLECTION).doc(audioId).collection(AUDIO_USAGE_COLLECTION).doc(reelId);
  }

  function reelRef(reelId) {
    return db.collection(reelCollection).doc(reelId);
  }

  function reelCollectionQuery() {
    return db.collection(reelCollection);
  }

  /**
   * Resolves creator profiles for a page of results in one round trip.
   * Reading users one-by-one inside a loop made every audio page cost
   * 1 + N reads, which does not survive thousands of users.
   */
  async function creatorsById(creatorIds) {
    const unique = [...new Set((creatorIds || []).filter(Boolean))];
    const byId = new Map();
    if (unique.length === 0) return byId;
    if (typeof db.getAll === "function") {
      const refs = unique.map((id) => db.collection("users").doc(id));
      const snaps = await db.getAll(...refs);
      snaps.forEach((snap) => {
        if (snap.exists) byId.set(snap.id, snap.data() || {});
      });
      return byId;
    }
    // Test doubles may not implement getAll.
    for (const id of unique) {
      const snap = await db.collection("users").doc(id).get();
      if (snap.exists) byId.set(id, snap.data() || {});
    }
    return byId;
  }

  async function extractAudioFromReel(request) {
    const creatorId = uid(request);
    const reelId = string(request.data?.reelId, 128);
    const audioName = string(request.data?.audioName || "", 128);
    const startMs = request.data?.startMs == null ? 0 : Number(request.data.startMs);
    const durationMs = request.data?.durationMs == null ? 15000 : Number(request.data.durationMs);

    if (!reelId) throw new HttpsError("invalid-argument", "reelId is required.");

    const reel = await reelRef(reelId).get();
    if (!reel.exists) throw new HttpsError("not-found", "Reel not found.");
    const reelData = reel.data();
    if (reelData.creatorId !== creatorId) {
      throw new HttpsError("permission-denied", "Only the creator can extract audio from this Reel.");
    }
    if (reelData.status !== "published") {
      throw new HttpsError("failed-precondition", "Audio can only be extracted from published Reels.");
    }

    const videoPath = reelData.processedStoragePath || reelData.videoPath;
    if (!videoPath) {
      throw new HttpsError("failed-precondition", "Video file not available.");
    }

    const audioId = db.collection(AUDIO_COLLECTION).doc().id;
    const audioPath = `reelAudios/${creatorId}/${audioId}.m4a`;

    await db.runTransaction(async (tx) => {
      tx.create(audioRef(audioId), {
        audioId,
        creatorId,
        originalReelId: reelId,
        name: audioName || `Audio from ${reelData.caption?.slice(0, 30) || "Reel"}`,
        displayName: audioName || `Original Audio`,
        storagePath: audioPath,
        durationMs: Math.min(durationMs, 60000),
        startMs: Math.max(0, Math.min(startMs, (reelData.durationSeconds || 0) * 1000 - 1000)),
        usageCount: 0,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        status: "extracting",
        schemaVersion: 1,
      });

      await reelRef.update({
        audioId,
        audioExtractedAt: FieldValue.serverTimestamp(),
      });
    });

    const dir = await fsp.mkdtemp(path.join(os.tmpdir(), "pubget-audio-"));
    const source = path.join(dir, "source.mp4");
    const output = path.join(dir, "audio.m4a");

    try {
      await bucket.file(videoPath).download({ destination: source });
      const ffmpeg = ffmpegBinary();
      await extractAudioSegment(ffmpeg, source, output, startMs, Math.min(durationMs, 60000));
      await bucket.upload(output, {
        destination: audioPath,
        resumable: false,
        metadata: { contentType: "audio/mp4", metadata: { generatedBy: "pubget-audio-extractor" } },
      });
      await audioRef(audioId).update({
        status: "ready",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (error) {
      await audioRef(audioId).update({
        status: "failed",
        failureReason: error.message,
        updatedAt: FieldValue.serverTimestamp(),
      });
      console.error("Audio extraction failed", { audioId, error: error.message });
    } finally {
      await fsp.rm(dir, { recursive: true, force: true });
    }

    return { audioId, status: "ready" };
  }

  async function onAudioExtracted(request) {
    const audioId = string(request.data?.audioId, 128);
    const storagePath = string(request.data?.storagePath, 512);
    const durationMs = request.data?.durationMs == null ? null : Number(request.data.durationMs);

    if (!audioId || !storagePath) throw new HttpsError("invalid-argument", "audioId and storagePath required.");

    const ref = audioRef(audioId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError("not-found", "Audio record not found.");

    await ref.update({
      storagePath,
      durationMs: durationMs || snap.data().durationMs,
      status: "ready",
      updatedAt: FieldValue.serverTimestamp(),
    });

    return { ok: true, status: "ready" };
  }

  async function listAudios(request) {
    const viewerId = uid(request);
    const limit = Math.max(1, Math.min(50, Number(request.data?.limit) || 20));
    const afterId = string(request.data?.afterId || "", 128);
    const sort = normalizeAudioSort(request.data?.type);

    let query = db.collection(AUDIO_COLLECTION)
      .where("status", "==", "ready");
    if (sort === "newest") {
      query = query.orderBy("createdAt", "desc");
    } else if (sort === "popular") {
      query = query.orderBy("usageCount", "desc");
    } else {
      // trending: usage-weighted, newest first as the tie-break.
      query = query.orderBy("usageCount", "desc").orderBy("createdAt", "desc");
    }
    query = query.limit(limit + 1);

    if (afterId) {
      const afterDoc = await audioRef(afterId).get();
      if (afterDoc.exists) {
        query = query.startAfter(afterDoc);
      }
    }

    const snapshot = await query.get();
    const docs = snapshot.docs || [];
    const creators = await creatorsById(docs.map((doc) => doc.data()?.creatorId));
    const items = docs.map((doc) => {
      const data = doc.data() || {};
      const creator = creators.get(data.creatorId) || {};
      return {
        ...data,
        creatorName: creator.username || data.creatorId,
        creatorAvatar: creator.avatarUrl || "",
        isOwner: data.creatorId === viewerId,
      };
    });
    return { items: items.slice(0, limit), hasMore: items.length > limit };
  }

  async function getAudio(request) {
    // Auth first: without this an unauthenticated caller could read any audio
    // document, its creator, and the reels using it.
    const viewerId = uid(request);
    const audioId = string(request.data?.audioId, 128);
    if (!audioId) throw new HttpsError("invalid-argument", "audioId required.");

    const audioDoc = await audioRef(audioId).get();
    if (!audioDoc.exists) throw new HttpsError("not-found", "Audio not found.");
    const audio = audioDoc.data();

    const creator = await db.collection("users").doc(audio.creatorId).get();
    const reelsSnap = await reelCollectionQuery()
      .where("audioId", "==", audioId)
      .where("status", "==", "published")
      .orderBy("createdAt", "desc")
      .limit(20)
      .get();

    const reels = reelsSnap.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));

    return {
      ...audio,
      creatorName: creator.data()?.username || audio.creatorId,
      creatorAvatar: creator.data()?.avatarUrl || "",
      reels,
      usageCount: audio.usageCount || reels.length,
    };
  }

  async function useAudio(request) {
    const userId = uid(request);
    const audioId = string(request.data?.audioId, 128);
    const reelId = string(request.data?.reelId, 128);

    if (!audioId || !reelId) throw new HttpsError("invalid-argument", "audioId and reelId required.");

    const audioDoc = await audioRef(audioId).get();
    if (!audioDoc.exists || audioDoc.data().status !== "ready") {
      throw new HttpsError("not-found", "Audio not available.");
    }

    const reelDoc = await reelRef(reelId).get();
    if (!reelDoc.exists) throw new HttpsError("not-found", "Reel not found.");
    if (reelDoc.data().creatorId !== userId) {
      throw new HttpsError("permission-denied", "Only the reel creator can attach audio.");
    }

    // usageCount is derived state, so it must follow what the reel actually
    // has attached — read inside the transaction and only move the counter
    // on a real change. Attaching the same audio twice, or swapping A for B,
    // used to silently inflate or orphan counts.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(reelRef(reelId));
      const previousAudioId = snap.data()?.audioId || null;
      const alreadyAttached = previousAudioId === audioId;

      // Firestore requires every read before the first write.
      const newUsageSnap = alreadyAttached
        ? { exists: false }
        : await tx.get(audioUsageRef(audioId, reelId));
      const previousUsageSnap =
        previousAudioId && !alreadyAttached
          ? await tx.get(audioUsageRef(previousAudioId, reelId))
          : { exists: false };

      if (previousAudioId && !alreadyAttached) {
        if (previousUsageSnap.exists) {
          tx.update(audioRef(previousAudioId), {
            usageCount: FieldValue.increment(-1),
            updatedAt: FieldValue.serverTimestamp(),
          });
          tx.delete(audioUsageRef(previousAudioId, reelId));
        }
        tx.update(reelRef(reelId), {
          audioAttachedAt: FieldValue.delete(),
        });
      }

      if (!alreadyAttached && !newUsageSnap.exists) {
        tx.update(audioRef(audioId), {
          usageCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.set(audioUsageRef(audioId, reelId), {
          reelId,
          userId,
          attachedAt: FieldValue.serverTimestamp(),
        });
      }

      tx.update(reelRef(reelId), {
        audioId,
        audioAttachedAt: FieldValue.serverTimestamp(),
      });
    });

    return { ok: true };
  }

  async function removeAudio(request) {
    const userId = uid(request);
    const reelId = string(request.data?.reelId, 128);
    if (!reelId) throw new HttpsError("invalid-argument", "reelId required.");

    const reelDoc = await reelRef(reelId).get();
    if (!reelDoc.exists) throw new HttpsError("not-found", "Reel not found.");
    if (reelDoc.data().creatorId !== userId) {
      throw new HttpsError("permission-denied", "Only the reel creator can remove audio.");
    }

    // Idempotent: detaching something that is not attached is a no-op, not a
    // decrement.
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(reelRef(reelId));
      const previousAudioId = snap.data()?.audioId || null;
      if (!previousAudioId) return;
      const usageSnap = await tx.get(audioUsageRef(previousAudioId, reelId));
      if (usageSnap.exists) {
        tx.update(audioRef(previousAudioId), {
          usageCount: FieldValue.increment(-1),
          updatedAt: FieldValue.serverTimestamp(),
        });
        tx.delete(audioUsageRef(previousAudioId, reelId));
      }
      tx.update(reelRef(reelId), {
        audioId: FieldValue.delete(),
        audioAttachedAt: FieldValue.delete(),
      });
    });

    return { ok: true };
  }

  async function searchAudios(request) {
    // Auth first: this query reaches into reelAudios, which the rules keep
    // behind signedIn(). Leaving it open would bypass the rules via callable.
    uid(request);
    const query = string(request.data?.query || "", 64);
    const limit = Math.max(1, Math.min(30, Number(request.data?.limit) || 15));
    if (!query) return { items: [] };

    const snapshot = await db.collection(AUDIO_COLLECTION)
      .where("status", "==", "ready")
      .orderBy("usageCount", "desc")
      .limit(100)
      .get();

    const lowerQuery = query.toLowerCase();
    const matches = (snapshot.docs || []).filter((doc) => {
      const data = doc.data() || {};
      return data.name?.toLowerCase().includes(lowerQuery) ||
        data.displayName?.toLowerCase().includes(lowerQuery) ||
        data.creatorId?.toLowerCase().includes(lowerQuery);
    });
    const page = matches.slice(0, limit);
    const creators = await creatorsById(page.map((doc) => doc.data()?.creatorId));
    const items = page.map((doc) => {
      const data = doc.data() || {};
      const creator = creators.get(data.creatorId) || {};
      return {
        ...data,
        creatorName: creator.username || data.creatorId,
        creatorAvatar: creator.avatarUrl || "",
      };
    });

    return { items };
  }

  return {
    extractAudioFromReel,
    onAudioExtracted,
    listAudios,
    getAudio,
    useAudio,
    removeAudio,
    searchAudios,
  };
}

module.exports = { createAudioDomain };