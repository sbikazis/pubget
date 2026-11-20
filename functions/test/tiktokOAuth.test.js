const test = require("node:test");
const assert = require("node:assert/strict");
const { createTikTokOAuth, CALLBACK_URI } = require("../src/tiktokOAuth");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function makeDb() {
  const documents = new Map();
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          const key = name + "/" + id;
          return {
            async create(value) {
              if (documents.has(key)) throw new Error("already exists");
              documents.set(key, value);
            },
            async get() {
              const value = documents.get(key);
              return { exists: Boolean(value), data: () => value };
            },
            async delete() { documents.delete(key); },
            async set(value) { documents.set(key, value); },
          };
        },
      };
    },
    async runTransaction(callback) {
      const transaction = {
        async get(ref) { return ref.get(); },
        delete(ref) { transaction.deleted = ref; },
      };
      const result = await callback(transaction);
      if (transaction.deleted) await transaction.deleted.delete();
      return result;
    },
  };
}

function makeDomain(db = makeDb()) {
  const param = (value) => ({ value: () => value });
  const domain = createTikTokOAuth({
    db,
    HttpsError: TestHttpsError,
    clientKey: param("test-client-key"),
    clientSecret: param("test-client-secret"),
    encryptionKey: param(Buffer.alloc(32, 7).toString("base64")),
  });
  return { db, domain };
}

test("OAuth start requires an authenticated Pubget user", async () => {
  const { domain } = makeDomain();
  await assert.rejects(
    domain.beginTikTokOAuth({ auth: null }),
    (error) => error instanceof TestHttpsError && error.code === "unauthenticated",
  );
});

test("OAuth start creates a short-lived one-time state and official authorize URL", async () => {
  const { db, domain } = makeDomain();
  const result = await domain.beginTikTokOAuth({ auth: { uid: "user-123" } });
  const url = new URL(result.authorizationUrl);
  assert.equal(url.origin + url.pathname, "https://www.tiktok.com/v2/auth/authorize/");
  assert.equal(url.searchParams.get("client_key"), "test-client-key");
  assert.equal(url.searchParams.get("response_type"), "code");
  assert.equal(url.searchParams.get("scope"), "user.info.basic");
  assert.equal(url.searchParams.get("redirect_uri"), CALLBACK_URI);
  assert.equal(url.searchParams.get("state").length, 43);
  assert.ok(result.expiresAt > Date.now());
  assert.equal(db.documents.size, 1);
  const [stored] = [...db.documents.values()];
  assert.equal(stored.uid, "user-123");
  assert.ok(stored.expiresAt <= Date.now() + 10 * 60 * 1000);
});

test("connection status does not reveal private account data", async () => {
  const { domain } = makeDomain();
  const result = await domain.getTikTokConnectionStatus({ auth: { uid: "no-account" } });
  assert.deepEqual(result, { connected: false });
});
