"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createEconomyDomain } = require("../src/economyDomain");
const { STORE_CATALOG, REWARD_AMOUNTS } = require("../src/economyConfig");

class TestHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const FieldValue = {
  serverTimestamp: () => ({ _serverTimestamp: true }),
  increment: (value) => ({ _increment: value }),
};

function clone(value) {
  if (value === null || typeof value !== "object") return value;
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  const next = {};
  for (const [key, item] of Object.entries(value)) next[key] = clone(item);
  return next;
}

function applyUpdate(current, data) {
  const next = clone(current) || {};
  for (const [key, value] of Object.entries(data)) {
    if (value && value._increment != null) {
      next[key] = (next[key] || 0) + value._increment;
      continue;
    }
    next[key] = clone(value);
  }
  return next;
}

function createFakeDb(seed = {}) {
  const store = new Map(Object.entries(clone(seed)));
  let txQueue = Promise.resolve();
  let autoInc = 0;

  function docsIn(base) {
    const prefix = `${base}/`;
    const docs = [];
    for (const [path, data] of store.entries()) {
      if (!path.startsWith(prefix)) continue;
      const rest = path.slice(prefix.length);
      if (!rest || rest.includes("/")) continue;
      docs.push({ id: rest, path, data });
    }
    return docs;
  }

  const makeCollection = (base) => ({
    doc(id) {
      const resolvedId = id || `auto-${++autoInc}`;
      const resolvedPath = `${base}/${resolvedId}`;
      const ref = {
        path: resolvedPath,
        id: resolvedId,
        collection(name) {
          return makeCollection(`${resolvedPath}/${name}`);
        },
        async get() {
          const data = store.get(resolvedPath);
          return {
            exists: data !== undefined,
            id: resolvedId,
            ref,
            data: () => (data === undefined ? undefined : clone(data)),
          };
        },
        async set(data, options) {
          if (options && options.merge) {
            store.set(resolvedPath, applyUpdate(store.get(resolvedPath) || {}, data));
          } else {
            store.set(resolvedPath, clone(data));
          }
        },
        async update(data) {
          if (!store.has(resolvedPath)) throw new Error("not-found");
          store.set(resolvedPath, applyUpdate(store.get(resolvedPath), data));
        },
        async create(data) {
          if (store.has(resolvedPath)) {
            const error = new Error("already-exists");
            error.code = "already-exists";
            throw error;
          }
          store.set(resolvedPath, clone(data));
        },
      };
      return ref;
    },
    async get() {
      return {
        docs: docsIn(base).map((item) => ({
          id: item.id,
          data: () => clone(item.data),
        })),
      };
    },
    orderBy(field, direction = "asc") {
      return {
        limit(n) {
          return {
            async get() {
              const docs = docsIn(base).sort((a, b) => {
                const av = a.data[field] && a.data[field]._serverTimestamp ? 1 : 0;
                const bv = b.data[field] && b.data[field]._serverTimestamp ? 1 : 0;
                return direction === "desc" ? bv - av : av - bv;
              }).slice(0, n);
              return {
                docs: docs.map((item) => ({
                  id: item.id,
                  data: () => clone(item.data),
                })),
              };
            },
          };
        },
      };
    },
  });

  return {
    store,
    collection(name) {
      return makeCollection(name);
    },
    async runTransaction(callback) {
      const run = txQueue.then(async () => {
        const transaction = {
          async get(ref) {
            const data = store.get(ref.path);
            return {
              exists: data !== undefined,
              ref,
              data: () => (data === undefined ? undefined : clone(data)),
            };
          },
          create(ref, data) {
            if (store.has(ref.path)) {
              const error = new Error("already-exists");
              error.code = "already-exists";
              throw error;
            }
            store.set(ref.path, clone(data));
          },
          set(ref, data, options) {
            if (options && options.merge) {
              store.set(ref.path, applyUpdate(store.get(ref.path) || {}, data));
            } else {
              store.set(ref.path, clone(data));
            }
          },
          update(ref, data) {
            if (!store.has(ref.path)) throw new Error("not-found");
            store.set(ref.path, applyUpdate(store.get(ref.path), data));
          },
          delete(ref) {
            store.delete(ref.path);
          },
        };
        return callback(transaction);
      });
      txQueue = run.catch(() => {});
      return run;
    },
  };
}

function domain(db, clock = new Date("2026-09-02T12:00:00.000Z")) {
  return createEconomyDomain({
    db,
    FieldValue,
    HttpsError: TestHttpsError,
    now: () => clock,
  });
}

function authed(uid, data = {}) {
  return { auth: { uid }, data };
}

function seedUser(extra = {}) {
  return {
    coinsBalance: 0,
    economyVersion: 0,
    subscriptionType: "free",
    hasClaimedReferral: false,
    ...extra,
  };
}

test("unauthenticated economy callables are rejected", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const api = domain(db);
  await assert.rejects(api.getEconomy({ data: {} }), (error) => error.code === "unauthenticated");
  await assert.rejects(api.purchaseStoreItem({ data: { itemId: "frame_sakura" } }), (error) => error.code === "unauthenticated");
});

test("initial balance is server owned and integer", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 0 }) });
  const snapshot = await domain(db).getEconomy(authed("alice"));
  assert.equal(snapshot.balance.balance, 0);
  assert.equal(Number.isInteger(snapshot.balance.balance), true);
  assert.equal(snapshot.premium.adFree, false);
  assert.equal(snapshot.ads.rewardedCoinsEnabled, false);
  assert.ok(snapshot.catalog.length >= 6);
});

test("event rewards credit the ledger once", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const api = domain(db);
  const first = await api.applyReward({
    userId: "alice", type: "earn_event", referenceId: "event-1", source: "event",
  });
  const second = await api.applyReward({
    userId: "alice", type: "earn_event", referenceId: "event-1", source: "event",
  });
  assert.equal(first.applied, true);
  assert.equal(first.amount, REWARD_AMOUNTS.earn_event);
  assert.equal(second.reason, "duplicate");
  const user = db.store.get("users/alice");
  assert.equal(user.coinsBalance, 10);
  const ledger = [...db.store.keys()].filter((key) => key.startsWith("economyTransactions/"));
  assert.equal(ledger.length, 1);
});

test("daily event cap blocks farming", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const api = domain(db);
  for (let index = 1; index <= 3; index += 1) {
    const result = await api.applyReward({
      userId: "alice", type: "earn_event", referenceId: `e${index}`, source: "mafia",
    });
    assert.equal(result.applied, true);
  }
  const blocked = await api.applyReward({
    userId: "alice", type: "earn_event", referenceId: "e4", source: "mafia",
  });
  assert.equal(blocked.reason, "daily_cap");
  assert.equal(db.store.get("users/alice").coinsBalance, 30);
});

test("game and event rewards share the daily activity bucket", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const api = domain(db);
  await api.applyReward({ userId: "alice", type: "earn_event", referenceId: "e1", source: "event" });
  await api.applyReward({ userId: "alice", type: "earn_game", referenceId: "g1", source: "game" });
  await api.applyReward({ userId: "alice", type: "earn_event", referenceId: "e2", source: "mafia" });
  const blocked = await api.applyReward({
    userId: "alice", type: "earn_game", referenceId: "g2", source: "game",
  });
  assert.equal(blocked.reason, "daily_cap");
});

test("negative and forged amounts cannot be granted", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const api = domain(db);
  const invalid = await api.applyReward({
    userId: "alice", type: "not_a_type", referenceId: "x", source: "client",
  });
  assert.equal(invalid.applied, false);
  assert.equal(db.store.get("users/alice").coinsBalance, 0);
});

test("purchase is atomic and ignores client price", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 200 }) });
  const api = domain(db);
  const result = await api.purchaseStoreItem(authed("alice", {
    itemId: "frame_sakura",
    price: 1,
    amount: 1,
    userId: "alice",
  }));
  assert.equal(result.ok, true);
  assert.equal(db.store.get("users/alice").coinsBalance, 120);
  assert.ok(db.store.get("users/alice/inventory/frame_sakura"));
  const ledger = Object.values(Object.fromEntries(
    [...db.store.entries()].filter(([key]) => key.startsWith("economyTransactions/")),
  ))[0];
  assert.equal(ledger.amount, -80);
  assert.equal(ledger.balanceAfter, 120);
});

test("insufficient funds and already owned fail without mutation", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 10 }) });
  const api = domain(db);
  await assert.rejects(
    api.purchaseStoreItem(authed("alice", { itemId: "frame_sakura" })),
    (error) => error.details && error.details.code === "insufficient_funds",
  );
  assert.equal(db.store.get("users/alice").coinsBalance, 10);
  db.store.set("users/alice", seedUser({ coinsBalance: 200 }));
  await api.purchaseStoreItem(authed("alice", { itemId: "frame_sakura" }));
  await assert.rejects(
    api.purchaseStoreItem(authed("alice", { itemId: "frame_sakura" })),
    (error) => error.details && error.details.code === "already_owned",
  );
  assert.equal(db.store.get("users/alice").coinsBalance, 120);
});

test("inactive catalog items cannot be purchased", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 500 }) });
  await assert.rejects(
    domain(db).purchaseStoreItem(authed("alice", { itemId: "badge_retired" })),
    (error) => error.details && error.details.code === "item_unavailable",
  );
});

test("premium-only items require a live entitlement", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 500 }) });
  const api = domain(db);
  await assert.rejects(
    api.purchaseStoreItem(authed("alice", { itemId: "frame_gold" })),
    (error) => error.details && error.details.code === "premium_required",
  );
  const expires = new Date("2026-10-01T00:00:00.000Z");
  db.store.set("users/alice", seedUser({
    coinsBalance: 500,
    subscriptionType: "premium",
    premiumExpiresAt: expires,
  }));
  const bought = await api.purchaseStoreItem(authed("alice", { itemId: "frame_gold" }));
  assert.equal(bought.ok, true);
});

test("expired premium is not entitled", async () => {
  const db = createFakeDb({
    "users/alice": seedUser({
      subscriptionType: "premium",
      premiumExpiresAt: new Date("2026-01-01T00:00:00.000Z"),
    }),
  });
  const entitlement = await domain(db).getPremiumEntitlement(authed("alice"));
  assert.equal(entitlement.status, "expired");
  assert.equal(entitlement.adFree, false);
});

test("restore purchase is deferred without a payment provider", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  const result = await domain(db).restorePremiumPurchases(authed("alice"));
  assert.equal(result.deferred, true);
  assert.equal(result.restored, false);
  assert.equal(db.store.get("users/alice").subscriptionType, "free");
});

test("client cannot claim game rewards directly", async () => {
  const db = createFakeDb({ "users/alice": seedUser() });
  await assert.rejects(
    domain(db).claimEconomyReward(authed("alice", { source: "earn_game", amount: 1000 })),
    (error) => error.code === "permission-denied",
  );
});

test("referral claim is idempotent and credits both users", async () => {
  const db = createFakeDb({
    "users/alice": seedUser({ invitedBy: "bob" }),
    "users/bob": seedUser({ coinsBalance: 5 }),
  });
  const api = domain(db);
  await api.claimEconomyReward(authed("alice", { source: "referral" }));
  await api.claimEconomyReward(authed("alice", { source: "referral" }));
  assert.equal(db.store.get("users/alice").coinsBalance, 30);
  assert.equal(db.store.get("users/bob").coinsBalance, 75);
  assert.equal(db.store.get("users/alice").hasClaimedReferral, true);
});

test("self-referral is rejected", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ invitedBy: "alice" }) });
  await assert.rejects(
    domain(db).claimEconomyReward(authed("alice", { source: "referral" })),
    (error) => error.details && error.details.code === "not_eligible",
  );
});

test("equip requires ownership and unequip keeps inventory", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 200 }) });
  const api = domain(db);
  await assert.rejects(
    api.equipCosmetic(authed("alice", { itemId: "frame_sakura" })),
    (error) => error.details && error.details.code === "not_eligible",
  );
  await api.purchaseStoreItem(authed("alice", { itemId: "frame_sakura" }));
  await api.equipCosmetic(authed("alice", { itemId: "frame_sakura" }));
  assert.equal(db.store.get("users/alice").equippedFrameId, "frame_sakura");
  await api.unequipCosmetic(authed("alice", { slot: "frame" }));
  assert.equal(db.store.get("users/alice").equippedFrameId, "");
  assert.ok(db.store.get("users/alice/inventory/frame_sakura"));
});

test("spoofed purchaser uid is ignored", async () => {
  const db = createFakeDb({
    "users/alice": seedUser({ coinsBalance: 10 }),
    "users/bob": seedUser({ coinsBalance: 500 }),
  });
  await assert.rejects(
    domain(db).purchaseStoreItem({
      auth: { uid: "alice" },
      data: { itemId: "frame_sakura", userId: "bob" },
    }),
    (error) => error.code === "permission-denied",
  );
  assert.equal(db.store.get("users/bob").coinsBalance, 500);
});

test("concurrent duplicate purchases resolve to a single grant", async () => {
  const db = createFakeDb({ "users/alice": seedUser({ coinsBalance: 300 }) });
  const api = domain(db);
  const attempts = await Promise.allSettled([
    api.purchaseStoreItem(authed("alice", { itemId: "badge_pioneer" })),
    api.purchaseStoreItem(authed("alice", { itemId: "badge_pioneer" })),
  ]);
  const ok = attempts.filter((item) => item.status === "fulfilled").length;
  const failed = attempts.filter((item) => item.status === "rejected").length;
  assert.equal(ok, 1);
  assert.equal(failed, 1);
  assert.equal(db.store.get("users/alice").coinsBalance, 250);
});

test("catalog prices are server authored", () => {
  for (const item of STORE_CATALOG) {
    assert.equal(Number.isInteger(item.price), true);
    assert.ok(item.price > 0);
    assert.equal(item.currency, "coins");
  }
});
