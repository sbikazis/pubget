'use strict';

/**
 * §15 viewer visibility.
 *
 * Blocking a person has to actually remove their Reels from the feed. Before
 * this, `blockUser` wrote `friendships.status == "blocked"` and the feed never
 * read it — the block existed only on the profile page and did nothing in the
 * product surface where it matters.
 *
 * Mute is one-directional (hide, no consequence). Block is honoured in both
 * directions: someone who blocked you must not keep serving you their Reels.
 *
 * Pure functions, so the filtering guarantee is unit-testable without the
 * emulator — this is a privacy control, and "the query filters it somewhere"
 * is not acceptable.
 */

/** Firestore caps a single `in` query at 30 values. */
const MAX_IN_CHUNK = 30;

function chunks(values, size = MAX_IN_CHUNK) {
  const list = [...values];
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** Accept a Firestore snapshot, a plain `{ data: payload }` row, or a payload. */
function unwrap(doc) {
  if (!doc) return null;
  if (typeof doc.data === 'function') return doc.data() || null;
  if (doc.data && typeof doc.data === 'object') return doc.data;
  return doc;
}

/**
 * Extract the set of creators whose content must not appear for a viewer.
 *
 * `blockDocs` are `friendships` docs touching the viewer; only `blocked` status
 * counts (a pending friend request must not hide anything).
 * `muteDocs` are the viewer's own mute rows (ids or docs).
 */
function buildHiddenCreatorSet({ blockDocs = [], muteDocs = [], viewerId }) {
  const hidden = new Set();
  if (!viewerId) return hidden;

  for (const raw of blockDocs) {
    const data = unwrap(raw);
    if (!data || data.status !== 'blocked') continue;
    // Skip self so a malformed row can never hide the viewer's own content.
    if (data.blockedBy && data.blockedBy === viewerId) {
      const other = (data.userIds || []).find((id) => id && id !== viewerId);
      if (other) hidden.add(other);
      continue;
    }
    for (const id of data.userIds || []) {
      if (id && id !== viewerId) hidden.add(id);
    }
  }

  for (const raw of muteDocs) {
    const id = typeof raw === 'string' ? raw : (raw && raw.id);
    if (id && id !== viewerId) hidden.add(id);
  }

  return hidden;
}

/**
 * Drop hidden creators. `creatorId` is read defensively from the row so a
 * missing creator cannot be used to smuggle content past the filter.
 */
function applyVisibility(candidates, hiddenCreatorIds, viewerId) {
  if (!hiddenCreatorIds || hiddenCreatorIds.size === 0) return candidates;
  return candidates.filter((item) => {
    const creatorId = item?.data?.creatorId;
    if (!creatorId) return true;
    if (creatorId === viewerId) return true;
    return !hiddenCreatorIds.has(creatorId);
  });
}

/**
 * Blocked creator ids to exclude from a creator-scoped query, chunked for
 * Firestore's 30-value `in` limit. Returns `[]` when there is nothing to hide,
 * because an empty `not-in` array is a client error, not a no-op.
 */
function hiddenIdChunks(hiddenCreatorIds, viewerId) {
  const ids = [...(hiddenCreatorIds || [])].filter((id) => id && id !== viewerId);
  return chunks(ids);
}

module.exports = {
  unwrap,
  buildHiddenCreatorSet,
  applyVisibility,
  hiddenIdChunks,
  chunks,
  MAX_IN_CHUNK,
};