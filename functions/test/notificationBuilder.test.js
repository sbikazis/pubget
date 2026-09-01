"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const { createNotificationBuilder } = require("../src/notificationBuilder");

function fakeDb() {
  const documents = new Map();
  const writes = [];
  const reference = (path) => ({
    path,
    collection(name) {
      return reference(`${path}/${name}`);
    },
    doc(id) {
      return reference(`${path}/${id}`);
    },
  });
  const db = {
    collection(name) {
      return reference(name);
    },
    async getAll() {
      return [];
    },
    collectionGroup() {
      return {
        where() {
          return { get: async () => ({ docs: [] }) };
        },
      };
    },
    async runTransaction(callback) {
      return callback({
        get: async (ref) => ({
          exists: documents.has(ref.path),
          data: () => documents.get(ref.path),
        }),
        create(ref, data) {
          documents.set(ref.path, data);
          writes.push(ref.path);
        },
        set() {},
      });
    },
  };
  return { db, writes };
}

test("deterministic notification IDs make builder retries idempotent", async () => {
  const { db, writes } = fakeDb();
  const builder = createNotificationBuilder({
    db,
    messaging: { sendEachForMulticast: async () => ({ responses: [] }) },
    FieldValue: {
      serverTimestamp: () => "timestamp",
      increment: (value) => value,
    },
  });
  const input = {
    id: "group_message_group_message",
    recipientIds: ["recipient"],
    type: "group_message",
    actorId: "actor",
    targetId: "group",
    action: "message_created",
    destination: "/group-chat?groupId=group",
    title: "Group",
    body: "Message",
  };
  assert.deepEqual(await builder.build(input), { created: 1 });
  assert.deepEqual(await builder.build(input), { created: 0 });
  assert.equal(writes.length, 1);
});