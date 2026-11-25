import { describe, expect, test } from "vitest";
import {
  RestTimestamp,
  createFirestoreGateway,
  decodeFirestoreFields,
  decodeFirestoreValue,
  documentPathFromName,
  encodeFirestoreValue,
} from "./firestoreGateway";

const env = {
  FIREBASE_PROJECT_ID: "pubget-test",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "",
};

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

describe("Firestore REST gateway values", () => {
  test("decodes timestamps into Admin-SDK-shaped values that serialize as JSON", () => {
    const decoded = decodeFirestoreValue({
      timestampValue: "2026-11-25T10:00:00.000Z",
    }) as RestTimestamp;

    expect(decoded.toMillis()).toBe(Date.parse("2026-11-25T10:00:00.000Z"));
    expect(decoded.toDate().toISOString()).toBe("2026-11-25T10:00:00.000Z");
    expect(JSON.stringify({ value: decoded })).toContain("2026-11-25T10:00:00.000Z");
  });

  test("decodes nested maps and arrays", () => {
    expect(decodeFirestoreFields({
      items: {
        arrayValue: {
          values: [{ integerValue: "1" }, { booleanValue: true }],
        },
      },
      nested: {
        mapValue: { fields: { title: { stringValue: "hello" } } },
      },
    })).toEqual({ items: [1, true], nested: { title: "hello" } });
  });

  test("encodes query values with Firestore types", () => {
    expect(encodeFirestoreValue(7)).toEqual({ integerValue: "7" });
    expect(encodeFirestoreValue(["active", "scheduled"])).toEqual({
      arrayValue: {
        values: [
          { stringValue: "active" },
          { stringValue: "scheduled" },
        ],
      },
    });
  });

  test("extracts relative document paths from REST names", () => {
    expect(documentPathFromName(
      "projects/pubget-test/databases/(default)/documents/groups/g1/members/u1",
    )).toBe("groups/g1/members/u1");
  });
});

describe("Firestore REST gateway queries", () => {
  test("runs nested collection queries against the parent document", async () => {
    const calls: Array<{ url: string; body: any }> = [];
    const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push({
        url: String(input),
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      return response([]);
    };
    const db = await createFirestoreGateway(env, { token: "test-token", fetcher: fetcher as any });

    await db.collection("users/u1/inventory").limit(50).get();

    expect(calls[0].url).toContain(
      "/documents/users/u1:runQuery",
    );
    expect(calls[0].body.structuredQuery.from).toEqual([{ collectionId: "inventory" }]);
    expect(calls[0].body.structuredQuery.limit).toBe(50);
  });

  test("runs root collection queries from the documents root", async () => {
    const calls: Array<{ url: string; body: any }> = [];
    const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push({
        url: String(input),
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      return response([]);
    };
    const db = await createFirestoreGateway(env, { token: "test-token", fetcher: fetcher as any });

    await db.collection("groups").where("isSearchable", "==", true).get();

    expect(calls[0].url).toContain("/documents:runQuery");
    expect(calls[0].body.structuredQuery.from).toEqual([{ collectionId: "groups" }]);
  });

  test("supports collection-group queries and composite filters", async () => {
    const calls: Array<{ url: string; body: any }> = [];
    const fetcher = async (input: RequestInfo | URL, init?: RequestInit) => {
      calls.push({
        url: String(input),
        body: JSON.parse(String(init?.body ?? "{}")),
      });
      return response([]);
    };
    const db = await createFirestoreGateway(env, { token: "test-token", fetcher: fetcher as any });

    await db
      .collectionGroup("members")
      .where("userId", "==", "u1")
      .where("role", "in", ["samurai", "daimyo"])
      .limit(80)
      .get();

    expect(calls[0].url).toContain("/documents:runQuery");
    expect(calls[0].body.structuredQuery.from).toEqual([
      { collectionId: "members", allDescendants: true },
    ]);
    expect(calls[0].body.structuredQuery.where.compositeFilter.op).toBe("AND");
    expect(calls[0].body.structuredQuery.where.compositeFilter.filters).toHaveLength(2);
  });

  test("missing documents are reported as non-existent snapshots", async () => {
    const fetcher = async () => response({}, 404);
    const db = await createFirestoreGateway(env, { token: "test-token", fetcher: fetcher as any });
    const snapshot = await db.collection("users").doc("missing").get();

    expect(snapshot.exists).toBe(false);
    expect(snapshot.data()).toBeUndefined();
  });
});
