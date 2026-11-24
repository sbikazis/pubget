import { afterEach, describe, expect, it, vi } from "vitest";
import {
  GroupInputError,
  entitledMaxMembers,
  handleGroupsRequest,
  resolveMaxMembers,
  validateGroupInput,
  type GroupsEnv,
} from "./groups";

const authState = vi.hoisted(() => ({ uid: "founder-1" as string | null }));

vi.mock("./firebaseAuth", () => ({
  verifyFirebaseIdToken: async () =>
    authState.uid ? { uid: authState.uid } : null,
  getGoogleAccessToken: async () => "service-token",
}));

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const BASE =
  "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents";

const env: GroupsEnv = {
  FIREBASE_PROJECT_ID: "pubget-aaf27",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "runner@developer.gserviceaccount.com",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "unused",
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json" },
  });
}

type StoredDoc = { name: string; fields: Record<string, unknown> };
type Write = {
  update?: { name: string; fields: Record<string, unknown> };
  delete?: string;
};

function harness(seed: Record<string, StoredDoc> = {}) {
  const docs = new Map<string, StoredDoc>(Object.entries(seed));
  const commits: Write[][] = [];
  let begins = 0;
  let conflictNext = false;
  const fetchImpl = async (input: RequestInfo | URL, init?: RequestInit) => {
    const url = String(input);
    if (url.endsWith(":beginTransaction")) {
      begins += 1;
      return jsonResponse({ transaction: "tx-1" });
    }
    if (url.endsWith(":commit")) {
      if (conflictNext) {
        conflictNext = false;
        return new Response("ABORTED: too much contention", { status: 409 });
      }
      const body = JSON.parse(String(init?.body ?? "{}")) as { writes?: Write[] };
      const writes = body.writes ?? [];
      commits.push(writes);
      const absolute = (name: string) =>
        name.startsWith(BASE) ? name : `${BASE}/${name}`;
      for (const write of writes) {
        if (write.update) {
          const key = absolute(write.update.name);
          docs.set(key, { name: key, fields: write.update.fields });
        } else if (write.delete) {
          docs.delete(absolute(write.delete));
        }
      }
      return jsonResponse({});
    }
    if (url.startsWith(BASE)) {
      const name = decodeURIComponent(url.slice(BASE.length + 1).split("?")[0]);
      const doc = docs.get(`${BASE}/${name}`);
      return doc ? jsonResponse(doc) : new Response("{}", { status: 404 });
    }
    throw new Error(`Unexpected network call in groups test: ${url}`);
  };
  return {
    docs,
    commits,
    get begins() { return begins; },
    fetchImpl,
    conflictOnce() {
      conflictNext = true;
    },
  };
}

function request(path: string, body?: unknown, token = "id-token"): Request {
  return new Request(`${ORIGIN}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

const publicDraft = {
  name: "  Anime Club  ",
  description: "  A friendly group  ",
  type: "public",
  animeId: null,
  joinPolicy: "open",
  isSearchable: true,
  rules: "  Be kind  ",
  maxMembers: 40,
  imageUrl: "https://example.com/a.jpg",
  idempotencyKey: "wizard-1",
};

afterEach(() => {
  authState.uid = "founder-1";
  vi.unstubAllGlobals();
});

describe("group input contract", () => {
  it("normalizes the same fields as the Firebase callable", () => {
    const input = validateGroupInput(publicDraft);
    expect(input.name).toBe("Anime Club");
    expect(input.character).toBeNull();
    expect(input.description).toBe("A friendly group");
    expect(input.rules).toBe("Be kind");
    expect(input.imageUrl).toBe("https://example.com/a.jpg");
    expect(input.idempotencyKey).toBe("wizard-1");
  });

  it("accepts R2 group images owned by the creator", () => {
    const input = validateGroupInput({
      ...publicDraft,
      imageUrl: "images/founder-1/group-a1.jpg",
      coverUrl: "images/founder-1/group-b2.webp",
    }, "founder-1");
    expect(input.imageUrl).toBe("images/founder-1/group-a1.jpg");
    expect(input.coverUrl).toBe("images/founder-1/group-b2.webp");
  });

  it("rejects another user's R2 image key", () => {
    expect(() => validateGroupInput({
      ...publicDraft,
      imageUrl: "images/someone-else/group-a1.jpg",
    }, "founder-1")).toThrow(GroupInputError);
    expect(() => validateGroupInput({
      ...publicDraft,
      coverUrl: "javascript:alert(1)",
    }, "founder-1")).toThrow(GroupInputError);
  });

  it("requires an animeId for anime roleplay and a character for roleplay", () => {
    expect(() => validateGroupInput({
      ...publicDraft,
      type: "animeRoleplay",
    })).toThrow(GroupInputError);
    expect(() => validateGroupInput({
      ...publicDraft,
      type: "openRoleplay",
    })).toThrow(/founder character/);
  });

  it("rejects a reserved character on public groups", () => {
    expect(() => validateGroupInput({
      ...publicDraft,
      characterKey: "hero",
      character: { key: "hero", name: "Hero", avatarUrl: "" },
    })).toThrow(/Public groups cannot reserve a character/);
  });

  it("keeps the entitled member ceiling", () => {
    expect(entitledMaxMembers({})).toBe(100);
    expect(entitledMaxMembers({ customMaxMembersLimit: 900 })).toBe(500);
    expect(resolveMaxMembers({ customMaxMembersLimit: 12 }, 40)).toBe(12);
    expect(resolveMaxMembers({}, "nonsense")).toBe(100);
  });
});

describe("groups/create worker route", () => {
  it("rejects unauthenticated callers before touching Firestore", async () => {
    const fake = harness();
    vi.stubGlobal("fetch", fake.fetchImpl);
    authState.uid = null;
    const result = await handleGroupsRequest(request("/groups/create", publicDraft), env);
    expect(result?.status).toBe(401);
    expect(fake.commits.length).toBe(0);
  });

  it("writes the full callable contract and returns the created group", async () => {
    const fake = harness();
    vi.stubGlobal("fetch", fake.fetchImpl);
    const result = await handleGroupsRequest(request("/groups/create", publicDraft), env);
    expect(result?.status).toBe(200);
    const payload = await result!.json();
    expect(payload.ok).toBe(true);
    expect(payload.group).toMatchObject({
      name: "Anime Club",
      searchName: "anime club",
      founderId: "founder-1",
      membersCount: 1,
      maxMembers: 40,
      migrationVersion: 2,
      joinPolicy: "open",
    });

    const writes = fake.commits[0];
    const paths = writes.map((write) => write.update?.name ?? write.delete ?? "");
    // Firestore rejects absolute URLs in Write.name with INVALID_ARGUMENT.
    expect(paths.every((path) => path.startsWith("projects/"))).toBe(true);
    expect(paths.some((path) => path.startsWith("https://"))).toBe(false);
    expect(paths.some((path) => /\/groups\/[^/]+$/.test(path))).toBe(true);
    expect(paths.some((path) => path.endsWith("/members/founder-1"))).toBe(true);
    expect(paths.filter((path) => path.includes("/roles/")).length).toBe(7);
    expect(paths.some((path) => path.includes("/groupCreateKeys/wizard-1"))).toBe(true);
    expect(paths.some((path) => path.includes("/achievementEvents/"))).toBe(true);
    const member = writes.find((write) => write.update?.name.endsWith("/members/founder-1"));
    const fields = member?.update?.fields as Record<string, { stringValue?: string; booleanValue?: boolean }>;
    expect(fields.role.stringValue).toBe("mikado");
    expect(fields.rankV2.stringValue).toBe("mikado");
    expect(fields.isManualRole.booleanValue).toBe(true);
    expect(fields.seatSource.stringValue).toBe("manual");
  });

  it("reuses the group behind an idempotency key without extra writes", async () => {
    const groupName = `${BASE}/groups/existing-group`;
    const fake = harness({
      [BASE + "/users/founder-1/groupCreateKeys/wizard-1"]: {
        name: "lock",
        fields: { groupId: { stringValue: "existing-group" } },
      },
      [groupName]: {
        name: "group",
        fields: { name: { stringValue: "Existing" } },
      },
    });
    vi.stubGlobal("fetch", fake.fetchImpl);
    const result = await handleGroupsRequest(request("/groups/create", publicDraft), env);
    expect(result?.status).toBe(200);
    expect((await result!.json()).groupId).toBe("existing-group");
    expect(fake.commits[0].length).toBe(0);
  });

  it("retries a Firestore conflict and still creates one group", async () => {
    const fake = harness();
    fake.conflictOnce();
    vi.stubGlobal("fetch", fake.fetchImpl);
    const result = await handleGroupsRequest(request("/groups/create", publicDraft), env);
    expect(result?.status).toBe(200);
    expect(fake.begins).toBe(2);
    expect(fake.commits.length).toBe(1);
    expect(fake.commits[0].length).toBeGreaterThan(10);
  });

  it("returns a validation error instead of a false network failure", async () => {
    const fake = harness();
    vi.stubGlobal("fetch", fake.fetchImpl);
    const result = await handleGroupsRequest(
      request("/groups/create", { ...publicDraft, joinPolicy: "anything" }),
      env,
    );
    expect(result?.status).toBe(400);
    expect((await result!.json()).error).toMatch(/Group details are invalid/);
    expect(fake.commits.length).toBe(0);
  });

  it("serves createGroupEntitlements from the Worker too", async () => {
    const fake = harness({
      [`${BASE}/users/founder-1`]: {
        name: "user",
        fields: { customMaxMembersLimit: { integerValue: "250" } },
      },
    });
    vi.stubGlobal("fetch", fake.fetchImpl);
    const result = await handleGroupsRequest(request("/groups/entitlements", {}), env);
    expect(result?.status).toBe(200);
    expect(await result!.json()).toEqual({ maxMembers: 250, canCreateGroups: true });
  });
});
