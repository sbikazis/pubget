"use strict";

/**
 * §15.18 — a takedown has to revoke the media, not only the document.
 *
 * `deleteEdit` used to flip `status: "deleted"` and stop. Because the Storage
 * rules for `edits/{uid}/{file}` and `edits-processed/{uid}/{file}` only asked
 * for a signed-in caller, both the raw upload and every transcoded rendition
 * stayed readable to any account forever, and saved-Reel snapshots kept
 * playing them. The Firestore path carries the Reel id, but the Storage path
 * carries a *filename*, and rules expose no substring operation, so the id
 * cannot be recovered from the filename inside the ruleset.
 *
 * The server therefore keeps one receipt document per stored object:
 *
 *   edits/{creatorId}/media/{fileName}  ->  { visible, editId, updatedAt }
 *
 * The Storage rules read exactly that receipt (via `firestore.get()`, which
 * runs with admin credentials and bypasses Firestore rules), so the receipt is
 * the single source of truth for "may this object be served?". Publication
 * flips it on, a takedown flips it off, and no client can forge it.
 *
 * Best-effort by design: a failed Storage delete must never make a takedown
 * fail, because the receipt already revoked read access. Deleting the bytes is
 * hygiene (cost), not the enforcement point.
 */

const { EDIT_RENDITIONS } = require("./editsConfig");

/**
 * Every file name the pipeline can produce for one Reel.
 *
 * The ladder is selected from the source height, so a short source never gets
 * the tall rungs. Enumerating the full ladder keeps the flip idempotent and
 * independent of which rung happened to be built.
 */
function candidateFileNames(editId, ladder = EDIT_RENDITIONS) {
  const names = [`${editId}.mp4`, `t_${editId}.jpg`];
  for (const rendition of ladder) {
    // The primary rung is stored unsuffixed; the rest are additive siblings.
    if (rendition.key === ladder[0].key) continue;
    names.push(`${editId}_${rendition.key}.mp4`);
  }
  return names;
}

/** The processed primary rung shares its name with the source name. */
function receiptDocPath(creatorId, fileName, collectionName = "edits") {
  return `${collectionName}/${creatorId}/media/${fileName}`;
}

function objectNames({ creatorId, editId, storagePrefix, processedPrefix }) {
  return candidateFileNames(editId).map((fileName) => ({
    fileName,
    receiptPath: receiptDocPath(creatorId, fileName),
    objectPath: `${processedPrefix}/${creatorId}/${fileName}`,
  }));
}

/**
 * Flip the read receipts for every object belonging to a Reel.
 *
 * Returns the per-object outcome so a caller (or a test) can assert that
 * revocation actually reached every rung rather than silently stopping at the
 * first Storage error.
 */
async function setMediaVisible({
  db,
  bucket,
  creatorId,
  editId,
  visible,
  storagePrefix = "edits",
  processedPrefix = "edits-processed",
  collectionName = "edits",
  FieldValue,
  now = FieldValue ? FieldValue.serverTimestamp() : null,
}) {
  const targets = objectNames({
    creatorId,
    editId,
    storagePrefix,
    processedPrefix,
  });
  // The source upload and its generated cover live under the raw prefix; the
  // transcoded rungs live under the processed prefix. Both sets need a receipt.
  targets.push(
    ...candidateFileNames(editId).map((fileName) => ({
      fileName,
      receiptPath: receiptDocPath(creatorId, fileName, collectionName),
      objectPath: `${storagePrefix}/${creatorId}/${fileName}`,
    })),
  );

  const batch = db.batch();
  for (const target of targets) {
    batch.set(
      db.doc(target.receiptPath),
      { visible, editId, updatedAt: now },
      { merge: true },
    );
  }
  await batch.commit();

  if (visible || !bucket) return { receiptCount: targets.length, deleted: 0 };
  let deleted = 0;
  for (const target of targets) {
    try {
      await bucket.file(target.objectPath).delete({ ignoreNotFound: true });
      deleted += 1;
    } catch (error) {
      // Access is already revoked by the receipt; leaving bytes behind costs
      // storage but grants nobody access, so it must not fail the takedown.
      console.warn("reelMediaAccess: object delete failed", {
        objectPath: target.objectPath,
        message: error && error.message,
      });
    }
  }
  return { receiptCount: targets.length, deleted };
}

module.exports = {
  candidateFileNames,
  receiptDocPath,
  objectNames,
  setMediaVisible,
};
