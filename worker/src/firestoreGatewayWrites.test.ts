import { describe, expect, test } from "vitest";
import {
  FieldValue,
  createFirestoreGateway,
  type GatewayOptions,
} from "./firestoreGateway";

const env = {
  FIREBASE_PROJECT_ID: "pubget-test",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "",
};

const BASE =
  "https://firestore.googleapis.com/v1/projects/pubget-test/databases/(default)/documents";

type CommitBody = {
  transaction?: string;
  writes: Array<{
    update?: {
      name: string;
      fields: Record<string, any>;
      updateMask?: { fieldPaths: string[] };
      fieldTransforms?: any[];
    };
    delete?: string;
    currentDocument?: { exists?: boolean };
  }>;
};

function harness() {
  const commits: CommitBody[] = [];
  let begins = 0;
  let conflictOnce = false;
  const fetcher: NonNullable<GatewayOptions["fetcher"]> = async (input, init) => {
    const url = String(input);
    if (url.endsWith(":beginTransaction")) {
      begins += 1;
      return new Response(JSON.stringify({ transaction: `tx-${begins}` }), { status: 200 });
    }
    if (url.endsWith(":commit")) {
      if (conflictOnce) {
        conflictOnce = false;
        return new Response("ABORTED", { status: 409 });
      }
      commits.push(JSON.parse(String(init?.body)) as CommitBody);
      return new Response("{}", { status: 200 });
    }
    if (url.endsWith(":rollback")) return new Response("{}", { status: 200 });
    if (url.startsWith(BASE)) return new Response("{}", { status: 404 });
    throw new Error(`Unexpected Firestore request: ${url}`);
  };
  return {
    commits,
    fetcher,
    get begins() { return begins; },
    conflictOnce() { conflictOnce = true; },
  };
}

describe("Firestore REST gateway writes", () => {
  test("queues Admin-shaped writes with relative names and server transforms", async () => {
    const h = harness();
    const db = await createFirestoreGateway(env, { token: "token", fetcher: h.fetcher });
    const user = db.collection("users").doc("u1");

    const result = await db.runTransaction(async (tx) => {
      await tx.get(user);
      tx.create(user, {
        name: "Alice",
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(user, {
        "hiddenFor.bob": FieldValue.delete(),
        respect: FieldValue.increment(2),
        "participants.carol.lastReadAt": FieldValue.serverTimestamp(),
      });
      tx.delete(db.collection("respects").doc("old"));
      return "done";
    });

    expect(result).toBe("done");
    expect(h.commits).toHaveLength(1);
    const { writes, transaction } = h.commits[0];
    expect(transaction).toBe("tx-1");
    expect(writes).toHaveLength(3);

    for (const write of writes) {
      const name = write.update?.name ?? write.delete ?? "";
      expect(name.startsWith("projects/pubget-test/databases/(default)/documents/")).toBe(true);
      expect(name.startsWith("https://")).toBe(false);
    }

    expect(writes[0].currentDocument).toEqual({ exists: false });
    expect(writes[0].update?.fieldTransforms).toEqual([
      { fieldPath: "createdAt", setToServerValue: "REQUEST_TIME" },
    ]);

    const update = writes[1].update!;
    expect(update.currentDocument).toBeUndefined();
    expect(update.updateMask?.fieldPaths).toEqual(
      expect.arrayContaining([
        "hiddenFor.bob",
        "respect",
        "participants.carol.lastReadAt",
      ]),
    );
    expect(update.fieldTransforms).toEqual([
      { fieldPath: "respect", increment: { operand: { integerValue: "2" } } },
      { fieldPath: "participants.carol.lastReadAt", setToServerValue: "REQUEST_TIME" },
    ]);
    expect(update.fields.hiddenFor?.mapValue?.fields?.bob).toBeUndefined();

    expect(writes[2].delete).toBe(
      "projects/pubget-test/databases/(default)/documents/respects/old",
    );
  });

  test("retries a transaction aborted by concurrent writers", async () => {
    const h = harness();
    h.conflictOnce();
    const db = await createFirestoreGateway(env, { token: "token", fetcher: h.fetcher });

    await db.runTransaction(async (tx) => {
      tx.set(db.collection("counters").doc("c1"), { value: 1 }, { merge: true });
    });

    expect(h.begins).toBe(2);
    expect(h.commits).toHaveLength(1);
    expect(h.commits[0].writes[0].update?.fields.value).toEqual({ integerValue: "1" });
  });

  test("batch commits auto-ID documents with relative write names", async () => {
    const h = harness();
    const db = await createFirestoreGateway(env, { token: "token", fetcher: h.fetcher });
    const ref = db.collection("users").doc("u1").collection("notifications").doc();

    expect(ref.id).toBeTruthy();
    expect(ref.path.endsWith(`/notifications/${ref.id}`)).toBe(true);

    const batch = db.batch();
    batch.set(ref, { type: "rank_promoted", readAt: false });
    batch.update(db.collection("groups").doc("g1"), { updatedAt: FieldValue.serverTimestamp() });
    await batch.commit();

    expect(h.commits).toHaveLength(1);
    expect(h.commits[0].writes).toHaveLength(2);
    expect(h.commits[0].writes[0].update?.name).toBe(
      `projects/pubget-test/databases/(default)/documents/users/u1/notifications/${ref.id}`,
    );
    expect(h.commits[0].writes[1].update?.fieldTransforms).toEqual([
      { fieldPath: "updatedAt", setToServerValue: "REQUEST_TIME" },
    ]);
  });

  test("queries inside a transaction carry the transaction id in the request body", async () => {
    const runQueries: Array<{ transaction?: string }> = [];
    const fetcher: NonNullable<GatewayOptions["fetcher"]> = async (input, init) => {
      const url = String(input);
      if (url.endsWith(":beginTransaction")) {
        return new Response(JSON.stringify({ transaction: "tx-7" }), { status: 200 });
      }
      if (url.endsWith(":runQuery")) {
        runQueries.push(JSON.parse(String(init?.body)));
        return new Response(JSON.stringify([
          { document: { name: `${BASE}/groups/g1/members/u1`, fields: {} } },
        ]), { status: 200 });
      }
      if (url.endsWith(":commit")) return new Response("{}", { status: 200 });
      if (url.endsWith(":rollback")) return new Response("{}", { status: 200 });
      throw new Error(`Unexpected Firestore request: ${url}`);
    };
    const db = await createFirestoreGateway(env, { token: "token", fetcher });

    await db.runTransaction(async (tx) => {
      const members = await tx.get(db.collection("groups").doc("g1").collection("members"));
      expect(members.docs.map((doc: { id: string }) => doc.id)).toEqual(["u1"]);
      tx.update(db.collection("groups").doc("g1"), { memberCount: 1 });
    });

    expect(runQueries).toHaveLength(1);
    expect(runQueries[0].transaction).toBe("tx-7");
  });
});
