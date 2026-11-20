const crypto = require("node:crypto");

const CALLBACK_URI = "https://pubget-aaf27.web.app/api/tiktok/oauth/callback";
const AUTHORIZE_URL = "https://www.tiktok.com/v2/auth/authorize/";
const TOKEN_URL = "https://open.tiktokapis.com/v2/oauth/token/";
const USER_INFO_URL = "https://open.tiktokapis.com/v2/user/info/";
const REVOKE_URL = "https://open.tiktokapis.com/v2/oauth/revoke/";
const STATE_TTL_MS = 10 * 60 * 1000;
const ACCESS_REFRESH_WINDOW_MS = 5 * 60 * 1000;

function encrypt(value, key) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);
  const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return {
    ciphertext: ciphertext.toString("base64"),
    iv: iv.toString("base64"),
    tag: cipher.getAuthTag().toString("base64"),
  };
}

function decrypt(payload, key) {
  const decipher = crypto.createDecipheriv(
    "aes-256-gcm",
    key,
    Buffer.from(payload.iv, "base64"),
  );
  decipher.setAuthTag(Buffer.from(payload.tag, "base64"));
  return Buffer.concat([
    decipher.update(Buffer.from(payload.ciphertext, "base64")),
    decipher.final(),
  ]).toString("utf8");
}

function createTikTokOAuth({ db, HttpsError, clientKey, clientSecret, encryptionKey }) {
  const secret = (param) => param.value();
  const keyBytes = () => {
    const key = Buffer.from(secret(encryptionKey), "base64");
    if (key.length !== 32) {
      throw new Error("TIKTOK_TOKEN_ENCRYPTION_KEY must be a base64-encoded 32-byte key.");
    }
    return key;
  };
  const stateCollection = () => db.collection("tiktok_oauth_states");
  const accountCollection = () => db.collection("tiktok_private_accounts");

  async function exchangeCode(code) {
    const body = new URLSearchParams({
      client_key: secret(clientKey),
      client_secret: secret(clientSecret),
      code,
      grant_type: "authorization_code",
      redirect_uri: CALLBACK_URI,
    });
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
    const payload = await response.json();
    if (!response.ok || payload.error || !payload.access_token || !payload.open_id) {
      throw new Error("TikTok token exchange failed.");
    }
    return payload;
  }

  async function fetchProfile(accessToken) {
    const response = await fetch(USER_INFO_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json; charset=UTF-8",
      },
      body: JSON.stringify({ fields: ["open_id", "display_name", "avatar_url"] }),
    });
    const payload = await response.json();
    if (!response.ok || payload.error?.code && payload.error.code !== "ok") {
      throw new Error("TikTok profile lookup failed.");
    }
    return payload.data?.user || {};
  }

  async function refreshTokens(uid, account) {
    const key = keyBytes();
    const refreshToken = decrypt(account.refreshToken, key);
    const body = new URLSearchParams({
      client_key: secret(clientKey),
      client_secret: secret(clientSecret),
      grant_type: "refresh_token",
      refresh_token: refreshToken,
    });
    const response = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    });
    const payload = await response.json();
    if (!response.ok || payload.error || !payload.access_token) {
      throw new Error("TikTok token refresh failed.");
    }
    const now = Date.now();
    const next = {
      ...account,
      accessToken: encrypt(payload.access_token, key),
      refreshToken: encrypt(payload.refresh_token || refreshToken, key),
      accessTokenExpiresAt: now + Number(payload.expires_in || 86400) * 1000,
      refreshTokenExpiresAt: now + Number(payload.refresh_expires_in || 31536000) * 1000,
      updatedAt: now,
    };
    await accountCollection().doc(uid).set(next, { merge: true });
    return next;
  }

  async function beginTikTokOAuth(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in before connecting TikTok.");
    const state = crypto.randomBytes(32).toString("base64url");
    const stateHash = crypto.createHash("sha256").update(state).digest("hex");
    const expiresAt = Date.now() + STATE_TTL_MS;
    await stateCollection().doc(stateHash).create({ uid, expiresAt, createdAt: Date.now() });
    const url = new URL(AUTHORIZE_URL);
    url.search = new URLSearchParams({
      client_key: secret(clientKey),
      response_type: "code",
      scope: "user.info.basic",
      redirect_uri: CALLBACK_URI,
      state,
    }).toString();
    return { authorizationUrl: url.toString(), expiresAt };
  }

  async function getTikTokConnectionStatus(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
    let snapshot = await accountCollection().doc(uid).get();
    if (!snapshot.exists) return { connected: false };
    let account = snapshot.data();
    if (Number(account.accessTokenExpiresAt || 0) <= Date.now() + ACCESS_REFRESH_WINDOW_MS) {
      try {
        account = await refreshTokens(uid, account);
      } catch (_) {
        return { connected: true, needsReconnect: true, displayName: account.displayName || null };
      }
    }
    return {
      connected: true,
      displayName: account.displayName || null,
      openId: account.openId,
      accessTokenExpiresAt: account.accessTokenExpiresAt,
    };
  }

  async function disconnectTikTok(request) {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in first.");
    const accountRef = accountCollection().doc(uid);
    const snapshot = await accountRef.get();
    if (snapshot.exists) {
      try {
        const account = snapshot.data();
        const accessToken = decrypt(account.accessToken, keyBytes());
        const body = new URLSearchParams({
          client_key: secret(clientKey),
          client_secret: secret(clientSecret),
          token: accessToken,
        });
        const response = await fetch(REVOKE_URL, {
          method: "POST",
          headers: { "Content-Type": "application/x-www-form-urlencoded" },
          body,
        });
        const payload = await response.json().catch(() => ({}));
        if (!response.ok || payload.error) {
          throw new Error("TikTok token revocation failed.");
        }
      } catch (_) {
        throw new HttpsError(
          "unavailable",
          "TikTok could not confirm disconnection. Please try again.",
        );
      }
    }
    await accountRef.delete();
    return { disconnected: true };
  }

  async function tiktokOAuthCallback(req, res) {
    if (req.method !== "GET") {
      res.set("Allow", "GET").status(405).send("Method not allowed.");
      return;
    }
    const state = typeof req.query.state === "string" ? req.query.state : "";
    const code = typeof req.query.code === "string" ? req.query.code : "";
    const stateHash = state ? crypto.createHash("sha256").update(state).digest("hex") : "";
    if (!stateHash) {
      res.status(400).send("Invalid TikTok authorization response. Return to Pubget and try again.");
      return;
    }

    let uid;
    try {
      const stateRef = stateCollection().doc(stateHash);
      await db.runTransaction(async (transaction) => {
        const stateSnapshot = await transaction.get(stateRef);
        if (!stateSnapshot.exists) throw new Error("Invalid or already used OAuth state.");
        const stateData = stateSnapshot.data();
        if (stateData.expiresAt < Date.now()) throw new Error("OAuth state expired.");
        uid = stateData.uid;
        transaction.delete(stateRef);
      });
      if (req.query.error || !code) throw new Error("TikTok authorization was declined.");
      const tokens = await exchangeCode(code);
      const profile = await fetchProfile(tokens.access_token);
      const key = keyBytes();
      await accountCollection().doc(uid).set({
        provider: "tiktok",
        openId: tokens.open_id,
        displayName: profile.display_name || null,
        avatarUrl: profile.avatar_url || null,
        scopes: String(tokens.scope || req.query.scopes || "").split(",").filter(Boolean),
        accessToken: encrypt(tokens.access_token, key),
        refreshToken: encrypt(tokens.refresh_token, key),
        accessTokenExpiresAt: Date.now() + Number(tokens.expires_in || 86400) * 1000,
        refreshTokenExpiresAt: Date.now() + Number(tokens.refresh_expires_in || 31536000) * 1000,
        connectedAt: Date.now(),
        updatedAt: Date.now(),
      });
      res.status(200).send(callbackPage(true));
    } catch (_) {
      res.status(400).send(callbackPage(false));
    }
  }

  return { beginTikTokOAuth, getTikTokConnectionStatus, disconnectTikTok, tiktokOAuthCallback };
}

function callbackPage(success) {
  const title = success ? "TikTok connected" : "Connection not completed";
  const message = success
    ? "Your TikTok account is securely connected. Return to Pubget."
    : "Pubget could not complete the TikTok connection. Return to Pubget and try again.";
  return `<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><body style="font-family:system-ui;max-width:34rem;margin:15vh auto;padding:1.5rem;line-height:1.6"><h1>${title}</h1><p>${message}</p><a href="pubget://group">Open Pubget</a></body></html>`;
}

module.exports = { createTikTokOAuth, CALLBACK_URI };
