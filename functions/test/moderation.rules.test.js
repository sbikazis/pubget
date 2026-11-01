/*
 * Phase 10 (spec axis 23) — security-rule tests for the moderation surface.
 *
 * Runs against the emulator alongside the main rules suite:
 *   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node --test test/moderation.rules.test.js
 *
 * These assert the two properties that matter: staff reach the queue through
 * claims, and nobody else reaches it at all — in either direction.
 */
const fs = require("fs");
const path = require("path");
const test = require("node:test");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");

let env;
const rules = fs.readFileSync(
  path.join(__dirname, "..", "..", "firestore.rules"),
  "utf8",
);

const db = (uid, claims) => env.authenticatedContext(uid, claims).firestore();

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-pubget-security",
    firestore: { host: "127.0.0.1", port: 8080, rules },
  });
});

test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await admin.doc("users/alice").set({ username: "Alice" });
    await admin.doc("users/mod").set({ username: "Mod" });
    await admin.doc("moderation_cases/edit_e1_alice").set({
      type: "edit",
      targetId: "e1",
      reporterId: "alice",
      status: "open",
      reason: "spam",
    });
    await admin.doc("moderation_audit/a1").set({
      actorId: "mod",
      action: "content_removed",
      targetId: "e1",
    });
    await admin.doc("groups/g1").set({ founderId: "alice", name: "G" });
    await admin.doc("groups/g1/members/bob").set({ role: "member", userId: "bob" });
    await admin.doc("groups/g1/messageReports/m1_bob").set({
      reporterId: "bob",
      messageId: "m1",
      reason: "spam",
      status: "open",
    });
  });
});

test.after(async () => {
  await env.cleanup();
});

test("only staff read the moderation queue", async () => {
  await assertSucceeds(db("mod", { moderator: true }).doc("moderation_cases/edit_e1_alice").get());
  await assertSucceeds(db("admin1", { admin: true }).doc("moderation_cases/edit_e1_alice").get());
  await assertFails(db("alice", {}).doc("moderation_cases/edit_e1_alice").get());
});

test("the reporter does not get to read the queue entry about themselves", async () => {
  // The old per-content rules let a reporter read their own report. The queue
  // is a staff surface: it aggregates reports across every content type, so
  // read access is staff-only, not reporter-scoped.
  await assertFails(db("alice", {}).doc("moderation_cases/edit_e1_alice").get());
});

test("nobody can write a moderation case from a client", async () => {
  await assertFails(db("alice", {}).doc("moderation_cases/edit_e1_alice").set({ status: "resolved" }));
  await assertFails(
    db("mod", { moderator: true }).doc("moderation_cases/edit_e1_alice").set({ status: "resolved" }),
  );
  await assertFails(
    db("mod", { moderator: true }).doc("moderation_cases/forged").set({ type: "edit", status: "open" }),
  );
});

test("the audit trail is staff-readable and immutable", async () => {
  await assertSucceeds(db("mod", { moderator: true }).doc("moderation_audit/a1").get());
  await assertFails(db("alice", {}).doc("moderation_audit/a1").get());
  await assertFails(
    db("mod", { moderator: true }).doc("moderation_audit/a1").delete(),
  );
});

test("staff can read a message report they did not file; members still cannot", async () => {
  await assertSucceeds(db("mod", { moderator: true }).doc("groups/g1/messageReports/m1_bob").get());
  await assertSucceeds(db("bob", {}).doc("groups/g1/messageReports/m1_bob").get());
  await assertFails(db("alice", {}).doc("groups/g1/messageReports/m1_bob").get());
});

test("a forged moderator claim cannot be minted by writing a document", async () => {
  // Authority lives in the token. Writing `moderator: true` onto your own user
  // document must not open the queue.
  await env.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("users/mallory").set({
      username: "Mallory",
      moderator: true,
      role: "moderator",
    });
  });
  await assertFails(db("mallory", {}).doc("moderation_cases/edit_e1_alice").get());
});
