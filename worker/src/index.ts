export interface Env {
  MEDIA_BUCKET: R2Bucket;
  FIREBASE_PROJECT_ID: string;
  MEDIA_SIGNING_SECRET: string;
}

const CORS: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, HEAD, POST, PUT, DELETE, OPTIONS",
  "access-control-allow-headers": "Authorization, Content-Type, Range",
  "access-control-expose-headers": "Content-Length, Content-Type, ETag, Accept-Ranges, Content-Range",
};

const LIMITS = {
  image: {
    max: 10 * 1024 * 1024,
    types: { jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp", gif: "image/gif" },
  },
  reels: {
    max: 100 * 1024 * 1024,
    types: { mp4: "video/mp4", webm: "video/webm", mov: "video/quicktime" },
  },
  audio: {
    max: 50 * 1024 * 1024,
    types: { mp3: "audio/mpeg", aac: "audio/aac", ogg: "audio/ogg", m4a: "audio/mp4" },
  },
} as const;

function json(data: unknown, status = 200, extra: HeadersInit = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", ...CORS, ...extra },
  });
}

function decodeBase64Url(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(normalized + "=".repeat((4 - normalized.length % 4) % 4));
  return Uint8Array.from(raw, (character) => character.charCodeAt(0));
}

async function authenticate(request: Request, projectId: string): Promise<string | null> {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return null;

  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;

    const header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0]))) as {
      alg?: string;
      kid?: string;
    };
    const claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1]))) as {
      aud?: string;
      iss?: string;
      sub?: string;
      exp?: number;
      iat?: number;
    };
    const now = Math.floor(Date.now() / 1000);

    if (
      header.alg !== "RS256" ||
      !header.kid ||
      claims.aud !== projectId ||
      claims.iss !== `https://securetoken.google.com/${projectId}` ||
      typeof claims.sub !== "string" ||
      !claims.sub ||
      typeof claims.exp !== "number" ||
      claims.exp <= now ||
      typeof claims.iat !== "number" ||
      claims.iat > now + 60
    ) {
      return null;
    }

    const jwksResponse = await fetch(
      "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
    );
    if (!jwksResponse.ok) return null;
    const jwks = (await jwksResponse.json()) as { keys: JsonWebKey[] };
    const jwk = jwks.keys.find(
      (key) => (key as JsonWebKey & { kid?: string }).kid === header.kid,
    );
    if (!jwk) return null;

    const publicKey = await crypto.subtle.importKey(
      "jwk",
      jwk,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
    const valid = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      publicKey,
      decodeBase64Url(parts[2]),
      new TextEncoder().encode(parts[0] + "." + parts[1]),
    );
    return valid ? claims.sub : null;
  } catch {
    return null;
  }
}

async function hmac(env: Env, message: string): Promise<string> {
  const bytes = Uint8Array.from(
    env.MEDIA_SIGNING_SECRET.match(/.{2}/g) ?? [],
    (value) => Number.parseInt(value, 16),
  );
  if (bytes.length !== 32) throw new Error("MEDIA_SIGNING_SECRET must be 32-byte hex.");

  const key = await crypto.subtle.importKey(
    "raw",
    bytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)),
  );
  return Array.from(digest, (value) => value.toString(16).padStart(2, "0")).join("");
}

function validUpload(
  kind: keyof typeof LIMITS,
  contentType: string,
  extension: string,
  size: number,
): boolean {
  const rule = LIMITS[kind];
  return Number.isSafeInteger(size) &&
    size > 0 &&
    size <= rule.max &&
    rule.types[extension as keyof typeof rule.types] === contentType;
}

function asciiAt(bytes: Uint8Array, offset: number, length: number): string {
  return String.fromCharCode(...bytes.slice(offset, offset + length));
}

function startsWithBytes(bytes: Uint8Array, signature: number[]): boolean {
  return signature.every((value, index) => bytes[index] === value);
}

/// Verify the first bytes independently of the client-provided MIME type and
/// extension. This is a server-side gate: the Flutter preflight is not trusted.
export function validFileSignature(
  kind: keyof typeof LIMITS,
  contentType: string,
  bytes: Uint8Array,
): boolean {
  if (kind === "image") {
    if (contentType === "image/jpeg") {
      return bytes.length >= 3 && startsWithBytes(bytes, [0xff, 0xd8, 0xff]);
    }
    if (contentType === "image/png") {
      return bytes.length >= 8 &&
        startsWithBytes(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    }
    if (contentType === "image/gif") {
      if (bytes.length < 6) return false;
      const header = asciiAt(bytes, 0, 6);
      return header === "GIF87a" || header === "GIF89a";
    }
    if (contentType === "image/webp") {
      return bytes.length >= 12 &&
        asciiAt(bytes, 0, 4) === "RIFF" &&
        asciiAt(bytes, 8, 4) === "WEBP";
    }
    return false;
  }

  if (kind === "reels") {
    if (contentType === "video/webm") {
      return bytes.length >= 4 && startsWithBytes(bytes, [0x1a, 0x45, 0xdf, 0xa3]);
    }
    if (bytes.length < 12 || asciiAt(bytes, 4, 4) !== "ftyp") return false;
    if (contentType === "video/quicktime") return asciiAt(bytes, 8, 2) === "qt";
    return contentType === "video/mp4";
  }

  if (contentType === "audio/mpeg") {
    const hasId3Header = bytes.length >= 10 && asciiAt(bytes, 0, 3) === "ID3";
    const hasMpegFrameSync =
      bytes.length >= 2 && bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0;
    return hasId3Header || hasMpegFrameSync;
  }
  if (contentType === "audio/aac") {
    return bytes.length >= 2 && bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0;
  }
  if (contentType === "audio/ogg") {
    return bytes.length >= 4 && asciiAt(bytes, 0, 4) === "OggS";
  }
  if (contentType === "audio/mp4") {
    return bytes.length >= 12 && asciiAt(bytes, 4, 4) === "ftyp";
  }
  return false;
}

/// Reads only the first 16 bytes and reconstructs the original stream, so
/// large video uploads are not buffered into Worker memory for inspection.
async function inspectAndRestoreBody(body: ReadableStream<Uint8Array>): Promise<{
  prefix: Uint8Array;
  stream: ReadableStream<Uint8Array>;
}> {
  const reader = body.getReader();
  const buffered: Uint8Array[] = [];
  let bufferedLength = 0;
  while (bufferedLength < 16) {
    const next = await reader.read();
    if (next.done) break;
    buffered.push(next.value);
    bufferedLength += next.value.length;
  }
  const prefix = new Uint8Array(Math.min(16, bufferedLength));
  let copied = 0;
  for (const chunk of buffered) {
    const count = Math.min(chunk.length, prefix.length - copied);
    if (count <= 0) break;
    prefix.set(chunk.subarray(0, count), copied);
    copied += count;
  }
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const chunk of buffered) controller.enqueue(chunk);
    },
    async pull(controller) {
      const next = await reader.read();
      if (next.done) controller.close();
      else controller.enqueue(next.value);
    },
    cancel(reason) {
      return reader.cancel(reason);
    },
  });
  return { prefix, stream };
}

function safeKey(key: string): boolean {
  const parts = key.split("/");
  if (parts.length === 3) {
    return ["images", "reels", "audio"].includes(parts[0]) &&
      /^[A-Za-z0-9_-]{1,128}$/.test(parts[1]) &&
      /^[A-Za-z0-9_-]{1,80}\.[a-z0-9]{2,5}$/.test(parts[2]);
  }
  return parts.length === 4 &&
    ["groups", "privateChats"].includes(parts[0]) &&
    /^[A-Za-z0-9_:-]{1,320}$/.test(parts[1]) &&
    /^[A-Za-z0-9_-]{1,128}$/.test(parts[2]) &&
    /^[A-Za-z0-9_-]{1,80}\.[a-z0-9]{2,5}$/.test(parts[3]);
}

function createKey(
  kind: keyof typeof LIMITS,
  uid: string,
  extension: string,
  scopeType?: string,
  scopeId?: string,
): string {
  const filename = `${crypto.randomUUID()}.${extension}`;
  if (scopeType && scopeId) return `${scopeType}/${scopeId}/${uid}/${filename}`;
  const folder = kind === "image" ? "images" : kind;
  return `${folder}/${uid}/${filename}`;
}

/// Uses the caller's Firebase ID token against Firestore's REST API, so the
/// exact same Firestore Security Rules that protect chat metadata also gate
/// access to the corresponding R2 objects. No Admin credential is stored here.
async function authorizePublishedOwnerAsset(
  request: Request,
  projectId: string,
  ownerUid: string,
  key: string,
): Promise<boolean> {
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return false;
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  try {
    const profile = await fetch(`${base}/public_profiles/${encodeURIComponent(ownerUid)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (profile.ok) {
      const document = await profile.json() as { fields?: Record<string, { stringValue?: string }> };
      if (Object.values(document.fields ?? {}).some((value) => value.stringValue === key)) return true;
    }

    // Event options are nested in configuration arrays, so the callable
    // maintains a compact mediaKeys index. Only published/non-deleted events
    // make these owner-scoped option images visible to other participants.
    const eventRefs = await fetch(`${base}:runQuery`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "events" }],
          where: {
            compositeFilter: {
              op: "AND",
              filters: [
                {
                  fieldFilter: {
                    field: { fieldPath: "mediaKeys" },
                    op: "ARRAY_CONTAINS",
                    value: { stringValue: key },
                  },
                },
                {
                  fieldFilter: {
                    field: { fieldPath: "scope" },
                    op: "EQUAL",
                    value: { stringValue: "global" },
                  },
                },
                {
                  fieldFilter: {
                    field: { fieldPath: "status" },
                    op: "IN",
                    value: {
                      arrayValue: {
                        values: ["ACTIVE", "active", "ENDED", "ended"]
                          .map((value) => ({ stringValue: value })),
                      },
                    },
                  },
                },
              ],
            },
          },
          limit: 5,
        },
      }),
    });
    if (eventRefs.ok) {
      const rows = await eventRefs.json() as Array<{
        document?: { fields?: Record<string, { stringValue?: string }> };
      }>;
      if (rows.some((row) => {
        const status = row.document?.fields?.status?.stringValue?.toLowerCase();
        return status != null && !["draft", "deleted", "archived"].includes(status);
      })) return true;
    }

    // Group and event documents expose only their published image references.
    // Firestore rules still decide whether the caller may query each collection.
    for (const [collection, fields] of [
      ["groups", ["imageUrl", "coverUrl", "chatBackgroundUrl"]],
      ["events", ["imageUrl", "coverUrl", "bannerUrl", "thumbnailUrl"]],
    ] as const) {
      for (const field of fields) {
        const response = await fetch(`${base}:runQuery`, {
          method: "POST",
          headers: {
            Authorization: `Bearer ${token}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            structuredQuery: {
              from: [{ collectionId: collection }],
              where: {
                fieldFilter: {
                  field: { fieldPath: field },
                  op: "EQUAL",
                  value: { stringValue: key },
                },
              },
              limit: 1,
            },
          }),
        });
        if (!response.ok) continue;
        const rows = await response.json() as Array<{ document?: unknown }>;
        if (rows.some((row) => row.document != null)) return true;
      }
    }
  } catch {
    return false;
  }
  return false;
}

async function authorizeConversation(
  request: Request,
  projectId: string,
  scopeType: string,
  scopeId: string,
  uid: string,
): Promise<boolean> {
  if (!["groups", "privateChats"].includes(scopeType) ||
      !/^[A-Za-z0-9_:-]{1,320}$/.test(scopeId)) return false;
  const token = request.headers.get("authorization")?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return false;
  const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;
  try {
    if (scopeType === "groups") {
      const [group, member] = await Promise.all([
        fetch(`${base}/groups/${encodeURIComponent(scopeId)}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
        fetch(`${base}/groups/${encodeURIComponent(scopeId)}/members/${encodeURIComponent(uid)}`, {
          headers: { Authorization: `Bearer ${token}` },
        }),
      ]);
      if (!group.ok || !member.ok) return false;
      const data = await group.json() as { fields?: Record<string, { booleanValue?: boolean }> };
      return data.fields?.deletionPending?.booleanValue !== true;
    }
    const chat = await fetch(`${base}/privateChats/${encodeURIComponent(scopeId)}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!chat.ok) return false;
    const document = await chat.json() as {
      fields?: Record<string, { stringValue?: string; arrayValue?: { values?: Array<{ stringValue?: string }> } }>;
    };
    const fields = document.fields ?? {};
    const participants = fields.participantIds?.arrayValue?.values?.map((v) => v.stringValue) ?? [];
    return participants.includes(uid) ||
      fields.userA?.stringValue === uid ||
      fields.userB?.stringValue === uid;
  } catch {
    return false;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS });
    }

    const url = new URL(request.url);

    if (url.pathname === "/health" && request.method === "GET") {
      return json({ ok: true, service: "pubget-media", storage: "r2", bucket: "pubget-media" });
    }

    if (url.pathname === "/presign" && request.method === "GET") {
      const uid = await authenticate(request, env.FIREBASE_PROJECT_ID);
      if (!uid) return json({ error: "Authentication required." }, 401);

      const kind = url.searchParams.get("kind") as keyof typeof LIMITS | null;
      const contentType = url.searchParams.get("contentType") ?? "";
      const extension = (url.searchParams.get("ext") ?? "").toLowerCase();
      const size = Number(url.searchParams.get("sizeBytes"));
      if (!kind || !(kind in LIMITS) || !validUpload(kind, contentType, extension, size)) {
        return json({ error: "Unsupported media type or size." }, 400);
      }

      const scopeType = url.searchParams.get("scopeType") ?? "";
      const scopeId = url.searchParams.get("scopeId") ?? "";
      if ((scopeType || scopeId) &&
          (!scopeType || !scopeId ||
           !await authorizeConversation(request, env.FIREBASE_PROJECT_ID, scopeType, scopeId, uid))) {
        return json({ error: "You are not allowed to upload to this conversation." }, 403);
      }
      const key = createKey(kind, uid, extension, scopeType || undefined, scopeId || undefined);
      const expires = Math.floor(Date.now() / 1000) + 900;
      const signature = await hmac(env, [key, uid, contentType, size, expires].join("\n"));
      const uploadUrl = `${url.origin}/upload/${encodeURIComponent(key)}?uid=${encodeURIComponent(uid)}&contentType=${encodeURIComponent(contentType)}&sizeBytes=${size}&expires=${expires}&signature=${signature}`;
      return json({ uploadUrl, key, headers: { "Content-Type": contentType } });
    }

    if (url.pathname.startsWith("/upload/") && request.method === "PUT") {
      let key: string;
      try {
        key = decodeURIComponent(url.pathname.slice("/upload/".length));
      } catch {
        return json({ error: "Invalid object key." }, 400);
      }

      const uid = url.searchParams.get("uid") ?? "";
      const contentType = url.searchParams.get("contentType") ?? "";
      const size = Number(url.searchParams.get("sizeBytes"));
      const expires = Number(url.searchParams.get("expires"));
      const supplied = url.searchParams.get("signature") ?? "";
      const parts = key.split("/");
      const now = Math.floor(Date.now() / 1000);

      if (!safeKey(key) || (parts.length === 3 ? parts[1] !== uid : parts[2] !== uid)) return json({ error: "Invalid upload key." }, 403);
      const scoped = parts.length === 4;
      const scopeType = scoped ? parts[0] : "";
      const scopeId = scoped ? parts[1] : "";
      if (scoped && (!await authorizeConversation(request, env.FIREBASE_PROJECT_ID, scopeType, scopeId, uid))) {
        return json({ error: "Conversation access denied." }, 403);
      }
      const kind = (scoped ? (parts[3].endsWith(".mp4") || parts[3].endsWith(".webm") || parts[3].endsWith(".mov") ? "reels" :
        parts[3].endsWith(".mp3") || parts[3].endsWith(".m4a") || parts[3].endsWith(".aac") || parts[3].endsWith(".ogg") ? "audio" : "image")
        : parts[0] === "images" ? "image" : parts[0]) as keyof typeof LIMITS;
      const extension = (scoped ? parts[3] : parts[2]).split(".").pop() ?? "";
      if (!(kind in LIMITS) || !validUpload(kind, contentType, extension, size) ||
          !Number.isSafeInteger(expires) || expires < now || expires > now + 930) {
        return json({ error: "Invalid or expired upload authorization." }, 403);
      }

      const expected = await hmac(env, [key, uid, contentType, size, expires].join("\n"));
      if (supplied.length !== expected.length) return json({ error: "Invalid upload signature." }, 403);
      let difference = 0;
      for (let index = 0; index < supplied.length; index++) {
        difference |= supplied.charCodeAt(index) ^ expected.charCodeAt(index);
      }
      if (difference || !request.body ||
          Number(request.headers.get("content-length")) !== size ||
          request.headers.get("content-type") !== contentType) {
        return json({ error: "Upload signature or size mismatch." }, 403);
      }

      if (!request.body) return json({ error: "Upload body is required." }, 400);
      const inspected = await inspectAndRestoreBody(request.body);
      if (!validFileSignature(kind, contentType, inspected.prefix)) {
        return json({ error: "The file contents do not match the declared media type." }, 415);
      }
      await env.MEDIA_BUCKET.put(key, inspected.stream, {
        httpMetadata: { contentType, cacheControl: "private, max-age=0, no-store" },
        customMetadata: { uploadedBy: uid, mediaKind: kind, ...(scoped ? { scopeType, scopeId } : {}) },
      });
      return json({ key }, 201);
    }

    if (url.pathname === "/upload" && request.method === "POST") {
      const uid = await authenticate(request, env.FIREBASE_PROJECT_ID);
      if (!uid) return json({ error: "Authentication required." }, 401);

      let form: FormData;
      try {
        form = await request.formData();
      } catch {
        return json({ error: "Invalid multipart upload." }, 400);
      }

      const file = form.get("file");
      const kind = form.get("kind") as keyof typeof LIMITS | null;
      const contentType = String(form.get("contentType") ?? "");
      const extension = String(form.get("ext") ?? "").toLowerCase();
      if (!(file instanceof File) || !kind || !(kind in LIMITS) ||
          !validUpload(kind, contentType, extension, file.size)) {
        return json({ error: "Unsupported media type or size." }, 400);
      }

      const prefix = new Uint8Array(await file.slice(0, 16).arrayBuffer());
      if (!validFileSignature(kind, contentType, prefix)) {
        return json({ error: "The file contents do not match the declared media type." }, 415);
      }

      const scopeType = String(form.get("scopeType") ?? "");
      const scopeId = String(form.get("scopeId") ?? "");
      if ((scopeType || scopeId) &&
          (!scopeType || !scopeId ||
           !await authorizeConversation(request, env.FIREBASE_PROJECT_ID, scopeType, scopeId, uid))) {
        return json({ error: "You are not allowed to upload to this conversation." }, 403);
      }
      const key = createKey(kind, uid, extension, scopeType || undefined, scopeId || undefined);
      await env.MEDIA_BUCKET.put(key, file.stream(), {
        httpMetadata: { contentType, cacheControl: "private, max-age=0, no-store" },
        customMetadata: { uploadedBy: uid, mediaKind: kind, ...(scopeType ? { scopeType, scopeId } : {}) },
      });
      return json({ key }, 201);
    }

    if (url.pathname === "/resolve" && request.method === "GET") {
      const uid = await authenticate(request, env.FIREBASE_PROJECT_ID);
      if (!uid) return json({ error: "Authentication required." }, 401);
      const key = url.searchParams.get("key") ?? "";
      const parts = key.split("/");
      if (!safeKey(key)) return json({ error: "Invalid object key." }, 400);
      const scoped = parts.length === 4;
      const object = await env.MEDIA_BUCKET.head(key);
      if (!object) return json({ error: "Media not found." }, 404);
      if (scoped) {
        const scopeType = parts[0];
        const scopeId = parts[1];
        if (parts[2] !== object.customMetadata?.uploadedBy ||
            object.customMetadata?.scopeType !== scopeType ||
            object.customMetadata?.scopeId !== scopeId ||
            !await authorizeConversation(request, env.FIREBASE_PROJECT_ID, scopeType, scopeId, uid)) {
          return json({ error: "Forbidden." }, 403);
        }
      } else if (parts[1] !== uid &&
          (object.customMetadata?.uploadedBy !== parts[1] ||
           !await authorizePublishedOwnerAsset(request, env.FIREBASE_PROJECT_ID, parts[1], key))) {
        return json({ error: "Forbidden." }, 403);
      }

      const expires = Math.floor(Date.now() / 1000) + 600;
      const signature = await hmac(env, [key, expires].join("\n"));
      const mediaUrl = `${url.origin}/media/${encodeURIComponent(key)}?expires=${expires}&signature=${signature}`;
      return json({ url: mediaUrl, expiresAt: expires });
    }

    if (url.pathname.startsWith("/media/") &&
        (request.method === "GET" || request.method === "HEAD")) {
      let key: string;
      try {
        key = decodeURIComponent(url.pathname.slice("/media/".length));
      } catch {
        return json({ error: "Invalid object key." }, 400);
      }
      if (!safeKey(key)) return json({ error: "Not found." }, 404);

      const expires = Number(url.searchParams.get("expires"));
      const supplied = url.searchParams.get("signature") ?? "";
      const now = Math.floor(Date.now() / 1000);
      if (!Number.isSafeInteger(expires) || expires < now || expires > now + 630) {
        return json({ error: "Media URL expired." }, 403);
      }
      const expected = await hmac(env, [key, expires].join("\n"));
      if (supplied.length !== expected.length) return json({ error: "Invalid media signature." }, 403);
      let difference = 0;
      for (let index = 0; index < supplied.length; index++) {
        difference |= supplied.charCodeAt(index) ^ expected.charCodeAt(index);
      }
      if (difference) return json({ error: "Invalid media signature." }, 403);

      const rangeHeader = request.headers.get("range");
      if (rangeHeader) {
        const match = rangeHeader.match(/^bytes=(\d+)-(\d*)$/);
        if (!match) return json({ error: "Invalid byte range." }, 416);
        const offset = Number(match[1]);
        const requestedEnd = match[2] ? Number(match[2]) : undefined;
        const head = await env.MEDIA_BUCKET.head(key);
        if (!head || offset >= head.size ||
            (requestedEnd !== undefined && requestedEnd < offset)) {
          return json({ error: "Range not satisfiable." }, 416);
        }
        const end = requestedEnd === undefined ? head.size - 1 : Math.min(requestedEnd, head.size - 1);
        const object = await env.MEDIA_BUCKET.get(key, {
          range: { offset, length: end - offset + 1 },
        });
        if (!object) return json({ error: "Media not found." }, 404);
        const headers = new Headers(CORS);
        object.writeHttpMetadata(headers);
        headers.set("etag", object.httpEtag);
        headers.set("cache-control", "private, max-age=300");
        headers.set("accept-ranges", "bytes");
        headers.set("content-range", `bytes ${offset}-${offset + object.size - 1}/${head.size}`);
        headers.set("content-length", String(object.size));
        return new Response(request.method === "HEAD" ? null : object.body, { status: 206, headers });
      }

      const object = await env.MEDIA_BUCKET.get(key);
      if (!object) return json({ error: "Media not found." }, 404);
      const headers = new Headers(CORS);
      object.writeHttpMetadata(headers);
      headers.set("etag", object.httpEtag);
      headers.set("cache-control", "private, max-age=300");
      headers.set("accept-ranges", "bytes");
      headers.set("content-length", String(object.size));
      return new Response(request.method === "HEAD" ? null : object.body, { headers });
    }

    if (url.pathname.startsWith("/media/") && request.method === "DELETE") {
      const uid = await authenticate(request, env.FIREBASE_PROJECT_ID);
      if (!uid) return json({ error: "Authentication required." }, 401);
      let key: string;
      try {
        key = decodeURIComponent(url.pathname.slice("/media/".length));
      } catch {
        return json({ error: "Invalid object key." }, 400);
      }
      if (!safeKey(key)) return json({ error: "Not found." }, 404);
      const parts = key.split("/");
      const object = await env.MEDIA_BUCKET.head(key);
      if (!object) return new Response(null, { status: 204, headers: CORS });
      const scoped = parts.length === 4;
      const ownerUid = scoped ? parts[2] : parts[1];
      if (ownerUid !== uid || object.customMetadata?.uploadedBy !== uid) {
        return json({ error: "Forbidden." }, 403);
      }
      if (scoped && !await authorizeConversation(
        request, env.FIREBASE_PROJECT_ID, parts[0], parts[1], uid,
      )) {
        return json({ error: "Conversation access denied." }, 403);
      }
      await env.MEDIA_BUCKET.delete(key);
      return new Response(null, { status: 204, headers: CORS });
    }

    return json({ error: "Not found." }, 404);
  },
};
