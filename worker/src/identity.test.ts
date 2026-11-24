import { describe, expect, it } from "vitest";
import {
  documentName,
  normalizeUsername,
  validUsername,
  validateProfile,
  handleIdentityRequest,
} from "./identity";

describe("Firestore write resource names", () => {
  it("strips the REST origin from document URLs before committing writes", () => {
    const url = "https://firestore.googleapis.com/v1/projects/pubget-aaf27/databases/(default)/documents/users/alice";
    expect(documentName(url)).toBe(
      "projects/pubget-aaf27/databases/(default)/documents/users/alice",
    );
    expect(documentName("projects/pubget-aaf27/databases/(default)/documents/users/alice")).toBe(
      "projects/pubget-aaf27/databases/(default)/documents/users/alice",
    );
  });
});

describe("identity username validation", () => {
  it("normalizes case and surrounding whitespace", () => {
    expect(normalizeUsername("  Pubget_Fan ")).toBe("pubget_fan");
    expect(normalizeUsername("أحمد")).toBe("أحمد");
  });

  it("accepts supported Latin and Arabic usernames", () => {
    expect(validUsername("pubget_fan")).toBe(true);
    expect(validUsername("أحمد")).toBe(true);
  });

  it("rejects invalid starts, characters and lengths", () => {
    for (const name of ["", "ab", "1fan", "_fan", "fan name", "fan@pubget", "a".repeat(21)]) {
      expect(validUsername(name)).toBe(false);
    }
  });
});

describe("profile patch validation", () => {
  it("accepts valid profile and privacy patches", () => {
    expect(validateProfile({
      username: "pubget_fan",
      bio: "Anime fan",
      favoriteAnimeIds: ["one", "two"],
      profileVisibility: "private",
      sectionPrivacy: { favorites: false, activity: true },
      socialLinks: [{ url: "https://example.com", label: "site" }],
      age: 16,
    })).toBeNull();
  });

  it("rejects unknown and malformed fields", () => {
    expect(validateProfile({ isAdmin: true })).toBe("invalid-profile");
    expect(validateProfile({ age: 12 })).toBe("invalid-profile");
    expect(validateProfile({ profileVisibility: "hidden" })).toBe("invalid-profile");
    expect(validateProfile({ username: "1bad" })).toBe("invalid-username");
    expect(validateProfile({ socialLinks: [{ url: "" }] })).toBe("invalid-profile");
  });

  it("preserves the nullable avatar and cover contracts", () => {
    expect(validateProfile({ avatarUrl: null })).toBeNull();
    expect(validateProfile({ coverUrl: null })).toBeNull();
    expect(validateProfile({ avatarUrl: "javascript:alert(1)" })).toBe("invalid-profile");
    expect(validateProfile({ avatarUrl: "images/alice/avatar.jpg" }, "alice")).toBeNull();
    expect(validateProfile({ avatarUrl: "images/bob/avatar.jpg" }, "alice")).toBe("invalid-profile");
    expect(validateProfile({ avatarUrl: "a".repeat(2049) }, "alice")).toBe("invalid-profile");
    expect(validateProfile({ avatarUrl: "https://cdn.example.test/legacy.jpg" })).toBeNull();
    expect(validateProfile({ coverUrl: "javascript:alert(1)" })).toBe("invalid-profile");
    expect(validateProfile({ coverUrl: "images/alice/cover_123.jpg" }, "alice")).toBeNull();
    expect(validateProfile({ coverUrl: "images/bob/cover_123.jpg" }, "alice")).toBe("invalid-profile");
  });
});

describe("identity API authentication boundary", () => {
  it("rejects requests without a Firebase ID token before attempting service access", async () => {
    const result = await handleIdentityRequest(
      new Request("https://pubget-media.pubget.workers.dev/identity/username/check", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ username: "pubget" }),
      }),
      {
        FIREBASE_PROJECT_ID: "pubget-aaf27",
        FIRESTORE_SERVICE_ACCOUNT_EMAIL: "",
        FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "",
      },
    );
    expect(result?.status).toBe(401);
  });
});
