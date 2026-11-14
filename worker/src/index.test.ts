import { describe, expect, it } from "vitest";
import { validFileSignature } from "./index";

describe("R2 upload content signatures", () => {
  it("accepts JPEG only when its magic bytes match image/jpeg", () => {
    expect(
      validFileSignature(
        "image",
        "image/jpeg",
        Uint8Array.from([0xff, 0xd8, 0xff, 0xe0, 0, 0x10, 0x4a, 0x46, 0x49, 0x46, 0, 1]),
      ),
    ).toBe(true);
    expect(
      validFileSignature(
        "image",
        "image/jpeg",
        Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]),
      ),
    ).toBe(false);
  });

  it("accepts PNG, GIF and WebP signatures", () => {
    expect(validFileSignature("image", "image/png", Uint8Array.from([
      0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0,
    ]))).toBe(true);
    expect(validFileSignature("image", "image/gif", new TextEncoder().encode("GIF89a000000"))).toBe(true);
    expect(validFileSignature("image", "image/webp", new TextEncoder().encode("RIFF0000WEBP"))).toBe(true);
  });

  it("distinguishes MP4, QuickTime and WebM containers", () => {
    expect(validFileSignature("reels", "video/mp4", new TextEncoder().encode("\u0000\u0000\u0000\u0018ftypisom0000"))).toBe(true);
    expect(validFileSignature("reels", "video/quicktime", new TextEncoder().encode("\u0000\u0000\u0000\u0018ftypqt 0000"))).toBe(true);
    expect(validFileSignature("reels", "video/webm", Uint8Array.from([
      0x1a, 0x45, 0xdf, 0xa3, 0x93, 0x42, 0x82, 0x88, 0x77, 0x65, 0x62, 0x6d,
    ]))).toBe(true);
    expect(validFileSignature("reels", "video/mp4", new TextEncoder().encode("not a real video"))).toBe(false);
  });

  it("checks common audio container signatures", () => {
    expect(validFileSignature("audio", "audio/mpeg", new TextEncoder().encode("ID3\u0004\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000"))).toBe(true);
    expect(validFileSignature("audio", "audio/aac", Uint8Array.from([
      0xff, 0xf1, 0x50, 0x80, 0, 0, 0, 0, 0, 0, 0, 0,
    ]))).toBe(true);
    expect(validFileSignature("audio", "audio/ogg", new TextEncoder().encode("OggS00000000"))).toBe(true);
    expect(validFileSignature("audio", "audio/mp4", new TextEncoder().encode("\u0000\u0000\u0000\u0018ftypM4A 0000"))).toBe(true);
  });

  it("rejects truncated files and cross-kind MIME declarations", () => {
    expect(validFileSignature("image", "image/png", Uint8Array.from([0x89, 0x50, 0x4e]))).toBe(false);
    expect(validFileSignature("reels", "image/png", new TextEncoder().encode("\u0000\u0000\u0000\u0018ftypisom0000"))).toBe(false);
  });
});


describe("R2 object key validation", () => {
  it("accepts owner-scoped and conversation-scoped media keys", async () => {
    const { isSafeMediaKey } = await import("./index");
    expect(isSafeMediaKey("images/alice/123e4567-e89b-42d3-a456-426614174000.jpg")).toBe(true);
    expect(isSafeMediaKey("reels/alice/123e4567-e89b-42d3-a456-426614174000.mp4")).toBe(true);
    expect(isSafeMediaKey("audio/alice/123e4567-e89b-42d3-a456-426614174000.m4a")).toBe(true);
    expect(isSafeMediaKey("groups/group_1/alice/123e4567-e89b-42d3-a456-426614174000.png")).toBe(true);
    expect(isSafeMediaKey("privateChats/chat:alice:bob/alice/123e4567-e89b-42d3-a456-426614174000.ogg")).toBe(true);
  });

  it("rejects traversal, unknown prefixes and malformed keys", async () => {
    const { isSafeMediaKey } = await import("./index");
    expect(isSafeMediaKey("../alice/file.jpg")).toBe(false);
    expect(isSafeMediaKey("images/../file.jpg")).toBe(false);
    expect(isSafeMediaKey("unknown/alice/file.jpg")).toBe(false);
    expect(isSafeMediaKey("groups/group/alice/../../file.jpg")).toBe(false);
    expect(isSafeMediaKey("images/alice/not-an-image.exe")).toBe(false);
    expect(isSafeMediaKey("reels/alice/file.jpg")).toBe(false);
    expect(isSafeMediaKey("audio/alice/file.mp4")).toBe(false);
  });
});
