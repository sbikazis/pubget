"use strict";

const {
  SCHEMA_VERSION,
  MAX_BALANCE,
  MAX_GRANT,
  MAX_ID,
  MAX_METADATA_KEYS,
  MAX_METADATA_STRING,
  HISTORY_LIMIT,
  REWARD_AMOUNTS,
  DAILY_CAPS,
  DAILY_BUCKET,
  RATE_LIMITS,
  COSMETIC_TYPES,
  EQUIP_SLOT_FIELDS,
  STORE_CATALOG,
  catalogById,
} = require("./economyConfig");

function validId(value) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= MAX_ID;
}

function requireAuth(request, HttpsError) {
  if (!request || !request.auth || !validId(request.auth.uid)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function safeInt(value) {
  if (typeof value !== "number" || !Number.isInteger(value) || !Number.isFinite(value)) {
    return null;
  }
  return value;
}

function toMillis(value, fallback = 0) {
  if (value == null) return fallback;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (value instanceof Date) return value.getTime();
  if (typeof value.toMillis === "function") return value.toMillis();
  if (typeof value.toDate === "function") return value.toDate().getTime();
  if (typeof value._seconds === "number") {
    return value._seconds * 1000 + Math.floor((value._nanoseconds || 0) / 1e6);
  }
  if (typeof value.seconds === "number") {
    return value.seconds * 1000;
  }
  return fallback;
}

function utcDate(clock) {
  return clock.toISOString().slice(0, 10);
}

function isPremiumUser(user, clock) {
  if (!user || user.subscriptionType !== "premium") return false;
  return toMillis(user.premiumExpiresAt, 0) > clock.getTime();
}

function transactionId(type, userId, referenceId) {
  return `${type}_${userId}_${referenceId}`
    .replace(/[^a-zA-Z0-9_-]/g, "_")
    .slice(0, 700);
}

function sanitizeMetadata(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return {};
  const out = {};
  for (const [key, value] of Object.entries(raw)) {
    if (Object.keys(out).length >= MAX_METADATA_KEYS) break;
    if (typeof key !== "string" || key.length === 0 || key.length > 40) continue;
    if (typeof value === "string" && value.length <= MAX_METADATA_STRING) {
      out[key] = value;
    } else if (typeof value === "number" && Number.isFinite(value) && Number.isInteger(value)) {
      out[key] = value;
    } else if (typeof value === "boolean") {
      out[key] = value;
    }
  }
  return out;
}

function publicCatalog() {
  return STORE_CATALOG.map((item) => ({ ...item }));
}

function equippedFromUser(user) {
  return {
    frameId: typeof user.equippedFrameId === "string" ? user.equippedFrameId : "",
    badgeId: typeof user.equippedBadgeId === "string" ? user.equippedBadgeId : "",
    nameplateId: typeof user.equippedNameplateId === "string" ? user.equippedNameplateId : "",
    themeId: typeof user.equippedThemeId === "string" ? user.equippedThemeId : "",
  };
}

function premiumFromUser(user, userId, clock) {
  const active = isPremiumUser(user, clock);
  const expiresAt = user.premiumExpiresAt || null;
  let status = "inactive";
  if (user.subscriptionType === "premium" && active) status = "active";
  else if (user.subscriptionType === "premium" && !active) status = "expired";
  return {
    userId,
    status,
    tier: active ? "premium" : "free",
    startedAt: user.premiumSince || null,
    expiresAt,
    providerReference: user.premiumProviderReference || null,
    adFree: active,
    paymentConfigured: false,
  };
}

function createEconomyDomain({
  db,
  FieldValue,
  HttpsError,
  notificationBuilder = null,
  now = () => new Date(),
}) {
  function fail(code, message, detailsCode) {
    throw new HttpsError(code, message, detailsCode ? { code: detailsCode } : undefined);
  }

  async function notifySafe(payload) {
    if (!notificationBuilder || typeof notificationBuilder.build !== "function") return;
    try {
      await notificationBuilder.build(payload);
    } catch (_) {
      // Notifications must never roll back a committed ledger write.
    }
  }

  async function readRateLimit(transaction, uid, action) {
    const spec = RATE_LIMITS[action];
    if (!spec) return null;
    const ref = db.collection("users").doc(uid).collection("economyRate").doc(action);
    const snap = await transaction.get(ref);
    return { ref, spec, data: snap.exists ? snap.data() || {} : {} };
  }

  function writeRateLimit(transaction, limit, clock) {
    if (!limit) return;
    const windowStart = safeInt(limit.data.windowStartMs) || 0;
    const count = safeInt(limit.data.count) || 0;
    const ts = clock.getTime();
    if (windowStart > 0 && ts - windowStart < limit.spec.windowMs && count >= limit.spec.max) {
      fail(
        "resource-exhausted",
        "Too many requests. Please wait a moment.",
        "rate_limited",
      );
    }
    const nextStart = windowStart > 0 && ts - windowStart < limit.spec.windowMs
      ? windowStart
      : ts;
    const nextCount = nextStart === windowStart ? count + 1 : 1;
    transaction.set(limit.ref, {
      windowStartMs: nextStart,
      count: nextCount,
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  async function applyReward({
    userId,
    type,
    referenceId,
    source,
    metadata = {},
  }) {
    const amount = REWARD_AMOUNTS[type];
    if (!validId(userId) || !validId(referenceId) || !Number.isInteger(amount)) {
      return { applied: false, reason: "invalid" };
    }
    if (amount <= 0 || amount > MAX_GRANT) {
      return { applied: false, reason: "invalid_amount" };
    }
    const txId = transactionId(type, userId, referenceId);
    const clock = now();
    const today = utcDate(clock);
    const userRef = db.collection("users").doc(userId);
    const ledgerRef = db.collection("economyTransactions").doc(txId);
    const userTxRef = userRef.collection("transactions").doc(txId);
    const legacyTxRef = userRef.collection("transactions").doc(referenceId);
    const bucket = DAILY_BUCKET[type];
    const cap = DAILY_CAPS[type];
    const dailyRef = bucket
      ? userRef.collection("daily_rewards").doc(`${bucket}_${today}`)
      : null;

    const result = await db.runTransaction(async (transaction) => {
      const reads = [
        transaction.get(ledgerRef),
        transaction.get(userTxRef),
        transaction.get(legacyTxRef),
        transaction.get(userRef),
      ];
      if (dailyRef) reads.push(transaction.get(dailyRef));
      const [ledgerSnap, userTxSnap, legacySnap, userSnap, dailySnap] =
        await Promise.all(reads);

      if (ledgerSnap.exists || userTxSnap.exists || legacySnap.exists) {
        const balance = safeInt(userSnap.data()?.coinsBalance) || 0;
        return { applied: false, reason: "duplicate", transactionId: txId, balance };
      }
      if (!userSnap.exists) {
        return { applied: false, reason: "user_missing" };
      }
      if (cap && dailyRef) {
        const count = dailySnap && dailySnap.exists
          ? (safeInt(dailySnap.data().count) || 0)
          : 0;
        if (count >= cap) {
          return { applied: false, reason: "daily_cap" };
        }
      }
      const user = userSnap.data() || {};
      const balanceBefore = safeInt(user.coinsBalance);
      if (balanceBefore == null || balanceBefore < 0) {
        return { applied: false, reason: "corrupt_balance" };
      }
      const balanceAfter = balanceBefore + amount;
      if (balanceAfter > MAX_BALANCE) {
        return { applied: false, reason: "overflow" };
      }
      const version = (safeInt(user.economyVersion) || 0) + 1;
      const record = {
        transactionId: txId,
        userId,
        type,
        amount,
        balanceBefore,
        balanceAfter,
        source: typeof source === "string" && source.length <= 40 ? source : type,
        referenceId,
        createdAt: FieldValue.serverTimestamp(),
        idempotencyKey: txId,
        metadata: sanitizeMetadata(metadata),
        schemaVersion: SCHEMA_VERSION,
      };
      transaction.update(userRef, {
        coinsBalance: balanceAfter,
        economyVersion: version,
        economyUpdatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(ledgerRef, record);
      transaction.create(userTxRef, record);
      if (cap && dailyRef) {
        const count = dailySnap && dailySnap.exists
          ? (safeInt(dailySnap.data().count) || 0)
          : 0;
        transaction.set(dailyRef, {
          count: count + 1,
          date: today,
          lastUpdate: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      return { applied: true, amount, balanceAfter, transactionId: txId, version };
    });

    if (result.applied) {
      await notifySafe({
        id: `economy-reward-${txId}`.slice(0, 128),
        recipientIds: [userId],
        type: "economy_reward",
        actorId: null,
        targetId: referenceId,
        action: "reward_received",
        destination: "/store",
        metadata: { type, amount: result.amount },
        title: "Coins received",
        body: `You earned ${result.amount} coins.`,
        pushWorthy: false,
      });
    }
    return result;
  }

  async function grantDomainRewards(userIds, spec) {
    const results = [];
    const unique = [...new Set((userIds || []).filter((id) => validId(id)))];
    for (const userId of unique) {
      results.push(await applyReward({
        userId,
        type: spec.type,
        referenceId: spec.referenceId,
        source: spec.source,
        metadata: spec.metadata,
      }));
    }
    return results;
  }

  async function getEconomy(request) {
    const uid = requireAuth(request, HttpsError);
    const clock = now();
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
    const user = userSnap.data() || {};
    const inventorySnap = await db.collection("users").doc(uid)
      .collection("inventory").get();
    const inventory = inventorySnap.docs
      ? inventorySnap.docs.map((doc) => ({ itemId: doc.id, ...(doc.data() || {}) }))
      : [];
    const balance = safeInt(user.coinsBalance) || 0;
    return {
      balance: {
        userId: uid,
        balance,
        updatedAt: user.economyUpdatedAt || null,
        version: safeInt(user.economyVersion) || 0,
      },
      premium: premiumFromUser(user, uid, clock),
      catalog: publicCatalog(),
      inventory,
      equipped: equippedFromUser(user),
      ads: {
        premiumExcluded: isPremiumUser(user, clock),
        rewardedCoinsEnabled: false,
      },
    };
  }

  async function getInventory(request) {
    const snapshot = await getEconomy(request);
    return { items: snapshot.inventory, equipped: snapshot.equipped };
  }

  async function getEconomyTransactions(request) {
    const uid = requireAuth(request, HttpsError);
    const snap = await db.collection("users").doc(uid)
      .collection("transactions")
      .orderBy("createdAt", "desc")
      .limit(HISTORY_LIMIT)
      .get();
    const items = snap.docs
      ? snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() || {}) }))
      : [];
    return { items };
  }

  async function getPremiumEntitlement(request) {
    const uid = requireAuth(request, HttpsError);
    const clock = now();
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
    return premiumFromUser(userSnap.data() || {}, uid, clock);
  }

  async function restorePremiumPurchases(request) {
    const uid = requireAuth(request, HttpsError);
    const clock = now();
    await db.runTransaction(async (transaction) => {
      const limit = await readRateLimit(transaction, uid, "restore");
      writeRateLimit(transaction, limit, clock);
    });
    const entitlement = await getPremiumEntitlement(request);
    return {
      ...entitlement,
      restored: false,
      deferred: true,
      reason: "payment_provider_not_configured",
    };
  }

  async function claimEconomyReward(request) {
    const uid = requireAuth(request, HttpsError);
    const source = request.data && request.data.source;
    if (source !== "referral") {
      fail(
        "permission-denied",
        "That reward cannot be claimed by the client.",
        "unauthorized",
      );
    }
    const clock = now();
    const userRef = db.collection("users").doc(uid);
    let invitedApplied = false;
    let inviterId = "";

    await db.runTransaction(async (transaction) => {
      const limit = await readRateLimit(transaction, uid, "claim");
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
      const user = userSnap.data() || {};
      const invitedBy = typeof user.invitedBy === "string" ? user.invitedBy.trim() : "";
      if (!validId(invitedBy) || invitedBy === uid) {
        fail("failed-precondition", "You are not eligible for this reward.", "not_eligible");
      }
      const inviterRef = db.collection("users").doc(invitedBy);
      const invitedTxId = transactionId("earn_referral_invited", uid, invitedBy);
      const inviterTxId = transactionId("earn_referral_inviter", invitedBy, uid);
      const [
        inviterSnap,
        invitedLedger,
        invitedUserTx,
        inviterLedger,
      ] = await Promise.all([
        transaction.get(inviterRef),
        transaction.get(db.collection("economyTransactions").doc(invitedTxId)),
        transaction.get(userRef.collection("transactions").doc(invitedTxId)),
        transaction.get(db.collection("economyTransactions").doc(inviterTxId)),
      ]);
      if (!inviterSnap.exists) {
        fail("failed-precondition", "You are not eligible for this reward.", "not_eligible");
      }
      writeRateLimit(transaction, limit, clock);
      inviterId = invitedBy;
      if (user.hasClaimedReferral === true && invitedLedger.exists) {
        invitedApplied = false;
        return;
      }
      if (invitedLedger.exists || invitedUserTx.exists) {
        transaction.update(userRef, { hasClaimedReferral: true });
        return;
      }
      const amount = REWARD_AMOUNTS.earn_referral_invited;
      const balanceBefore = safeInt(user.coinsBalance) || 0;
      if (balanceBefore < 0) {
        fail("failed-precondition", "Balance is invalid.", "unknown");
      }
      const balanceAfter = balanceBefore + amount;
      if (balanceAfter > MAX_BALANCE) {
        fail("failed-precondition", "Balance limit reached.", "unknown");
      }
      const record = {
        transactionId: invitedTxId,
        userId: uid,
        type: "earn_referral_invited",
        amount,
        balanceBefore,
        balanceAfter,
        source: "referral",
        referenceId: invitedBy,
        createdAt: FieldValue.serverTimestamp(),
        idempotencyKey: invitedTxId,
        metadata: {},
        schemaVersion: SCHEMA_VERSION,
      };
      transaction.update(userRef, {
        coinsBalance: balanceAfter,
        economyVersion: (safeInt(user.economyVersion) || 0) + 1,
        economyUpdatedAt: FieldValue.serverTimestamp(),
        hasClaimedReferral: true,
      });
      transaction.create(db.collection("economyTransactions").doc(invitedTxId), record);
      transaction.create(userRef.collection("transactions").doc(invitedTxId), record);
      invitedApplied = true;
      if (!inviterLedger.exists) {
        const inviter = inviterSnap.data() || {};
        const inviterBefore = safeInt(inviter.coinsBalance) || 0;
        const inviterAmount = REWARD_AMOUNTS.earn_referral_inviter;
        const inviterAfter = inviterBefore + inviterAmount;
        if (inviterBefore >= 0 && inviterAfter <= MAX_BALANCE) {
          const inviterRecord = {
            transactionId: inviterTxId,
            userId: invitedBy,
            type: "earn_referral_inviter",
            amount: inviterAmount,
            balanceBefore: inviterBefore,
            balanceAfter: inviterAfter,
            source: "referral",
            referenceId: uid,
            createdAt: FieldValue.serverTimestamp(),
            idempotencyKey: inviterTxId,
            metadata: {},
            schemaVersion: SCHEMA_VERSION,
          };
          transaction.update(inviterRef, {
            coinsBalance: inviterAfter,
            economyVersion: (safeInt(inviter.economyVersion) || 0) + 1,
            economyUpdatedAt: FieldValue.serverTimestamp(),
          });
          transaction.create(
            db.collection("economyTransactions").doc(inviterTxId),
            inviterRecord,
          );
          transaction.create(
            inviterRef.collection("transactions").doc(inviterTxId),
            inviterRecord,
          );
        }
      }
    });

    return { ok: true, applied: invitedApplied, inviterId };
  }

  async function purchaseStoreItem(request) {
    const uid = requireAuth(request, HttpsError);
    const itemId = request.data && request.data.itemId;
    if (!validId(itemId)) fail("invalid-argument", "itemId is required.", "unknown");
    const clientPrice = request.data && request.data.price;
    const clientAmount = request.data && request.data.amount;
    if (clientPrice != null || clientAmount != null) {
      // Ignore tampered prices; never trust them. Continue with catalog.
    }
    if (request.data && request.data.userId && request.data.userId !== uid) {
      fail("permission-denied", "You cannot purchase for another user.", "unauthorized");
    }
    const item = catalogById(itemId.trim());
    if (!item || item.availability !== "active") {
      fail("failed-precondition", "This item is not available.", "item_unavailable");
    }
    if (!Number.isInteger(item.price) || item.price <= 0 || item.currency !== "coins") {
      fail("failed-precondition", "This item is not available.", "item_unavailable");
    }
    const clock = now();
    const txId = transactionId("purchase_cosmetic", uid, item.id);
    const userRef = db.collection("users").doc(uid);
    const inventoryRef = userRef.collection("inventory").doc(item.id);
    const ledgerRef = db.collection("economyTransactions").doc(txId);
    const userTxRef = userRef.collection("transactions").doc(txId);

    const result = await db.runTransaction(async (transaction) => {
      const limit = await readRateLimit(transaction, uid, "purchase");
      const [userSnap, ownedSnap, ledgerSnap] = await Promise.all([
        transaction.get(userRef),
        transaction.get(inventoryRef),
        transaction.get(ledgerRef),
      ]);
      if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
      if (ownedSnap.exists || ledgerSnap.exists) {
        fail("already-exists", "You already own this item.", "already_owned");
      }
      const user = userSnap.data() || {};
      if (item.premiumOnly && !isPremiumUser(user, clock)) {
        fail("failed-precondition", "Premium is required for this item.", "premium_required");
      }
      const balanceBefore = safeInt(user.coinsBalance);
      if (balanceBefore == null || balanceBefore < 0) {
        fail("failed-precondition", "Balance is invalid.", "unknown");
      }
      if (balanceBefore < item.price) {
        fail("failed-precondition", "You do not have enough coins.", "insufficient_funds");
      }
      const balanceAfter = balanceBefore - item.price;
      if (balanceAfter < 0) {
        fail("failed-precondition", "You do not have enough coins.", "insufficient_funds");
      }
      writeRateLimit(transaction, limit, clock);
      const version = (safeInt(user.economyVersion) || 0) + 1;
      const record = {
        transactionId: txId,
        userId: uid,
        type: "purchase_cosmetic",
        amount: -item.price,
        balanceBefore,
        balanceAfter,
        source: "store",
        referenceId: item.id,
        createdAt: FieldValue.serverTimestamp(),
        idempotencyKey: txId,
        metadata: { itemType: item.type, title: item.title },
        schemaVersion: SCHEMA_VERSION,
      };
      transaction.update(userRef, {
        coinsBalance: balanceAfter,
        economyVersion: version,
        economyUpdatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(inventoryRef, {
        itemId: item.id,
        type: item.type,
        acquiredAt: FieldValue.serverTimestamp(),
        source: "purchase",
        schemaVersion: SCHEMA_VERSION,
      });
      transaction.create(ledgerRef, record);
      transaction.create(userTxRef, record);
      return { balanceAfter, version, itemId: item.id };
    });

    await notifySafe({
      id: `economy-purchase-${txId}`.slice(0, 128),
      recipientIds: [uid],
      type: "economy_purchase",
      actorId: uid,
      targetId: item.id,
      action: "purchase_completed",
      destination: "/store",
      metadata: { itemId: item.id },
      title: "Purchase complete",
      body: `You bought ${item.title}.`,
      pushWorthy: false,
    });
    return { ok: true, ...result };
  }

  async function equipCosmetic(request) {
    const uid = requireAuth(request, HttpsError);
    const itemId = request.data && request.data.itemId;
    if (!validId(itemId)) fail("invalid-argument", "itemId is required.", "unknown");
    const item = catalogById(itemId.trim());
    if (!item || !COSMETIC_TYPES.includes(item.type)) {
      fail("not-found", "Item not found.", "unknown");
    }
    const field = EQUIP_SLOT_FIELDS[item.type];
    const clock = now();
    const userRef = db.collection("users").doc(uid);
    const inventoryRef = userRef.collection("inventory").doc(item.id);
    await db.runTransaction(async (transaction) => {
      const limit = await readRateLimit(transaction, uid, "equip");
      const [userSnap, ownedSnap] = await Promise.all([
        transaction.get(userRef),
        transaction.get(inventoryRef),
      ]);
      if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
      if (!ownedSnap.exists) {
        fail("failed-precondition", "You do not own this item.", "not_eligible");
      }
      writeRateLimit(transaction, limit, clock);
      transaction.update(userRef, {
        [field]: item.id,
        economyUpdatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, equipped: { slot: item.type, itemId: item.id } };
  }

  async function unequipCosmetic(request) {
    const uid = requireAuth(request, HttpsError);
    const slot = request.data && request.data.slot;
    const field = EQUIP_SLOT_FIELDS[slot];
    if (!field) fail("invalid-argument", "A valid cosmetic slot is required.", "unknown");
    const clock = now();
    const userRef = db.collection("users").doc(uid);
    await db.runTransaction(async (transaction) => {
      const limit = await readRateLimit(transaction, uid, "equip");
      const userSnap = await transaction.get(userRef);
      if (!userSnap.exists) fail("not-found", "User not found.", "unknown");
      writeRateLimit(transaction, limit, clock);
      transaction.update(userRef, {
        [field]: "",
        economyUpdatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, equipped: { slot, itemId: "" } };
  }

  return {
    getEconomy,
    getInventory,
    getEconomyTransactions,
    getPremiumEntitlement,
    restorePremiumPurchases,
    claimEconomyReward,
    purchaseStoreItem,
    equipCosmetic,
    unequipCosmetic,
    applyReward,
    grantDomainRewards,
    isPremiumUser,
    publicCatalog,
  };
}

module.exports = {
  createEconomyDomain,
  isPremiumUser,
  publicCatalog: () => STORE_CATALOG.map((item) => ({ ...item })),
  transactionId,
};
