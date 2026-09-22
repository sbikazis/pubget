"use strict";

const USERNAME_MIN = 3;
const USERNAME_MAX = 20;

// Spec §3.2 username: letters first (Arabic or Latin), then letters, digits,
// middle dots, underscores and hyphens; 3–20 characters.
const USERNAME_RE = /^[\p{L}][\p{L}\p{N}._-]{2,19}$/u;
const FIRST_LETTER_RE = /^[\p{L}]$/u;

function normalizeUsername(username) {
  return String(username || "").trim().toLowerCase();
}

function validateUsername(username, normalize = false) {
  const value = normalize ? normalizeUsername(username) : username;
  if (value.length === 0) return { valid: false, reason: "empty" };
  if (value.length < USERNAME_MIN) return { valid: false, reason: "too-short" };
  if (value.length > USERNAME_MAX) return { valid: false, reason: "too-long" };
  if (!USERNAME_RE.test(value)) {
    if (!FIRST_LETTER_RE.test(value.slice(0, 1))) {
      return { valid: false, reason: "invalid-start" };
    }
    return { valid: false, reason: "invalid-characters" };
  }
  return { valid: true, reason: null };
}

function createUserNameRegistry({ db }) {
  async function status(username) {
    const normalized = normalizeUsername(username);
    const validation = validateUsername(normalized);
    if (!validation.valid) {
      return { valid: false, reason: validation.reason, normalized };
    }
    const snapshot = await db.collection("usernames").doc(normalized).get();
    return { valid: true, reason: snapshot.exists ? "taken" : null, normalized };
  }

  // Race-safe claim. Idempotent when the same uid already owns the name.
  async function reserve(uid, username, HttpsError) {
    const normalized = normalizeUsername(username);
    const validation = validateUsername(normalized);
    if (!validation.valid) {
      throw new HttpsError("invalid-argument", "Username is invalid.");
    }
    const ref = db.collection("usernames").doc(normalized);
    let outcome = "claimed";
    try {
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        if (snapshot.exists) {
          const data = snapshot.data() || {};
          if (data.uid === uid) {
            outcome = "already-claimed";
            return;
          }
          transaction.update(ref, { conflictingUid: uid });
          throw new HttpsError("already-exists", "Username is already taken.");
        }
        transaction.set(ref, {
          uid,
          normalized,
          claimedAt: new Date().toISOString(),
        });
      });
    } catch (error) {
      throw error;
    }
    return outcome;
  }

  // Releases only a reservation owned by this uid. Swallows errors: the
  // safety-net trigger reconciles any stale reservation eventually.
  async function release(uid, username) {
    const normalized = normalizeUsername(username);
    if (!normalized) return;
    const ref = db.collection("usernames").doc(normalized);
    try {
      await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(ref);
        if (!snapshot.exists) return;
        const data = snapshot.data() || {};
        if (data.uid !== uid) return;
        transaction.delete(ref);
      });
    } catch (error) {
      // Non-fatal by design.
    }
  }

  return { status, reserve, release };
}

function createUserNameCallables({ db, HttpsError }) {
  const registry = createUserNameRegistry({ db });

  async function checkUsernameAvailable(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const username = (request.data && request.data.username) || "";
    const result = await registry.status(username);
    return {
      available: result.reason === null,
      normalized: result.normalized,
      reason: result.reason,
    };
  }

  async function reserveUsername(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const username = (request.data && request.data.username) || "";
    const normalized = normalizeUsername(username);
    const validation = validateUsername(normalized);
    if (!validation.valid) {
      throw new HttpsError("invalid-argument", "Username is invalid.");
    }
    const outcome = await registry.reserve(request.auth.uid, username, HttpsError);
    return { normalized, alreadyClaimed: outcome === "already-claimed" };
  }

  return { checkUsernameAvailable, reserveUsername, registry };
}

// Safety net: the profile document is also written directly by the app
// (create-once). This trigger keeps /usernames in sync with any users/{uid}
// username change, releasing renamed/dropped names and claiming new ones when
// free. It never steals a name reserved by another uid.
function createUsernameReconciliationTrigger({ db }) {
  const registry = createUserNameRegistry({ db });

  return async function syncUsernameReservation(event) {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return;
    const before = event.data.before && event.data.before.exists
      ? event.data.before.data() || {}
      : {};
    const data = after.data() || {};
    const uid = event.params.uid;
    const next = normalizeUsername(data.username);
    const prev = normalizeUsername(before.username);
    if (next === prev) return;

    if (prev && prev !== next) {
      await registry.release(uid, prev);
    }
    if (next) {
      const ref = db.collection("usernames").doc(next);
      const snapshot = await ref.get();
      const claim = snapshot.exists ? snapshot.data() || {} : null;
      if (!claim || claim.uid === uid) {
        await ref.set(
          { uid, normalized: next, claimedAt: new Date().toISOString() },
          { merge: true },
        );
      }
    }
    return null;
  };
}

module.exports = {
  USERNAME_MIN,
  USERNAME_MAX,
  validateUsername,
  normalizeUsername,
  createUserNameRegistry,
  createUserNameCallables,
  createUsernameReconciliationTrigger,
};