"use strict";

function avatarDownloadUrl(bucketName, filePath, token) {
  return "https://firebasestorage.googleapis.com/v0/b/" +
    `${bucketName}/o/${encodeURIComponent(filePath)}` +
    `?alt=media&token=${token}`;
}

function createAvatarPrivacySync({ db, bucket, randomUUID }) {
  return async function syncAvatarPrivacy(event) {
    const after = event.data && event.data.after;
    if (!after || !after.exists) return;

    const uid = event.params.uid;
    const data = after.data() || {};
    const before = event.data.before.exists ? event.data.before.data() || {} : {};
    const isPrivate = data.profileVisibility === "private";
    const visibilityChanged =
      before.profileVisibility !== data.profileVisibility;
    const avatarChanged = before.avatarUrl !== data.avatarUrl;
    const filePath = `users/${uid}/avatar.jpg`;
    const file = bucket.file(filePath);

    if (isPrivate && data.avatarUrl && (visibilityChanged || avatarChanged)) {
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: randomUUID() },
      });
      await db.collection("users").doc(uid).update({ avatarUrl: null });
      return;
    }

    if (!isPrivate && visibilityChanged && !data.avatarUrl) {
      const [exists] = await file.exists();
      if (!exists) return;
      const token = randomUUID();
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: token },
      });
      await db.collection("users").doc(uid).update({
        avatarUrl: avatarDownloadUrl(bucket.name, filePath, token),
      });
    }
  };
}

function optionalString(value, max) {
  return typeof value === "string" && value.length <= max;
}

function optionalUrl(value, max) {
  if (value === null) return true;
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length <= max &&
    (trimmed === "" || trimmed.startsWith("https://") || trimmed.startsWith("http://"));
}

function validSocialLinks(value) {
  if (!Array.isArray(value) || value.length > 20) return false;
  return value.every((item) => {
    if (!item || typeof item !== "object") return false;
    if (!optionalString(item.url || "", 500)) return false;
    if (item.label !== undefined && !optionalString(item.label, 64)) return false;
    if (item.platform !== undefined && !optionalString(item.platform, 32)) {
      return false;
    }
    return typeof item.url === "string" && item.url.trim().length > 0;
  });
}

function validSectionPrivacy(value) {
  if (!value || typeof value !== "object") return false;
  const keys = [
    "favorites", "activity", "friends", "fans",
    "works", "groups", "ratings", "achievements",
  ];
  return keys.every((key) => value[key] === undefined || typeof value[key] === "boolean");
}

function createUpdateSocialProfile({ db, bucket, randomUUID, HttpsError }) {
  return async function updateSocialProfile(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const uid = request.auth.uid;
    const input = request.data || {};

    const hasLegacyBundle =
      typeof input.bio === "string" &&
      Array.isArray(input.favoriteAnimeIds) &&
      typeof input.profileVisibility === "string" &&
      typeof input.activityVisibility === "string";

    if (input.bio !== undefined && !optionalString(input.bio, 500)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.favoriteAnimeIds !== undefined) {
      if (!Array.isArray(input.favoriteAnimeIds) ||
          input.favoriteAnimeIds.length > 50 ||
          input.favoriteAnimeIds.some(
            (id) => typeof id !== "string" || id.length > 128,
          )) {
        throw new HttpsError("invalid-argument", "Profile update is invalid.");
      }
    }
    if (input.favoriteAnimes !== undefined) {
      if (!Array.isArray(input.favoriteAnimes) ||
          input.favoriteAnimes.length > 50 ||
          input.favoriteAnimes.some(
            (id) => typeof id !== "string" || id.length > 64,
          )) {
        throw new HttpsError("invalid-argument", "Profile update is invalid.");
      }
    }
    if (input.profileVisibility !== undefined &&
        !["public", "private"].includes(input.profileVisibility)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.activityVisibility !== undefined &&
        !["public", "private"].includes(input.activityVisibility)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.whoCanMessageMe !== undefined &&
        !["related", "friends"].includes(input.whoCanMessageMe)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.username !== undefined && !optionalString(input.username, 32)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.displayName !== undefined &&
        !optionalString(input.displayName, 64)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.country !== undefined && !optionalString(input.country, 64)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.favoriteQuote !== undefined &&
        !optionalString(input.favoriteQuote, 200)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.animeTwin !== undefined && !optionalString(input.animeTwin, 80)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.age !== undefined && input.age !== null) {
      if (typeof input.age !== "number" ||
          !Number.isInteger(input.age) ||
          input.age < 13 ||
          input.age > 120) {
        throw new HttpsError("invalid-argument", "Profile update is invalid.");
      }
    }
    if (input.socialLinks !== undefined && !validSocialLinks(input.socialLinks)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.sectionPrivacy !== undefined &&
        !validSectionPrivacy(input.sectionPrivacy)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }
    if (input.coverUrl !== undefined && !optionalUrl(input.coverUrl, 1024)) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }

    if (!hasLegacyBundle &&
        input.bio === undefined &&
        input.favoriteAnimeIds === undefined &&
        input.favoriteAnimes === undefined &&
        input.profileVisibility === undefined &&
        input.activityVisibility === undefined &&
        input.whoCanMessageMe === undefined &&
        input.username === undefined &&
        input.displayName === undefined &&
        input.country === undefined &&
        input.favoriteQuote === undefined &&
        input.animeTwin === undefined &&
        input.age === undefined &&
        input.socialLinks === undefined &&
        input.sectionPrivacy === undefined &&
        input.coverUrl === undefined) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }

    const userRef = db.collection("users").doc(uid);
    const snapshot = await userRef.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Profile not found.");
    }
    const current = snapshot.data() || {};
    const update = {};

    if (input.bio !== undefined) update.bio = input.bio.trim();
    if (input.favoriteAnimeIds !== undefined) {
      update.favoriteAnimeIds = input.favoriteAnimeIds;
    }
    if (input.favoriteAnimes !== undefined) {
      update.favoriteAnimes = input.favoriteAnimes;
    }
    if (input.profileVisibility !== undefined) {
      update.profileVisibility = input.profileVisibility;
    }
    if (input.activityVisibility !== undefined) {
      update.activityVisibility = input.activityVisibility;
    }
    if (input.whoCanMessageMe !== undefined) {
      update.whoCanMessageMe = input.whoCanMessageMe;
    }
    if (input.username !== undefined) update.username = input.username.trim();
    if (input.displayName !== undefined) {
      update.displayName = input.displayName.trim();
    }
    if (input.country !== undefined) update.country = input.country.trim();
    if (input.favoriteQuote !== undefined) {
      update.favoriteQuote = input.favoriteQuote.trim();
    }
    if (input.animeTwin !== undefined) update.animeTwin = input.animeTwin.trim();
    if (input.age !== undefined) update.age = input.age;
    if (input.socialLinks !== undefined) {
      update.socialLinks = input.socialLinks.map((item) => ({
        url: String(item.url).trim(),
        ...(item.label ? { label: String(item.label).trim() } : {}),
        ...(item.platform ? { platform: String(item.platform).trim() } : {}),
      }));
    }
    if (input.sectionPrivacy !== undefined) {
      update.sectionPrivacy = {
        favorites: input.sectionPrivacy.favorites !== false,
        activity: input.sectionPrivacy.activity !== false,
        friends: input.sectionPrivacy.friends !== false,
        fans: input.sectionPrivacy.fans !== false,
        works: input.sectionPrivacy.works !== false,
        groups: input.sectionPrivacy.groups !== false,
        ratings: input.sectionPrivacy.ratings !== false,
        achievements: input.sectionPrivacy.achievements !== false,
      };
    }
    if (input.coverUrl !== undefined) {
      update.coverUrl = input.coverUrl === null ? null : String(input.coverUrl).trim();
    }

    const profileVisibility =
      update.profileVisibility || current.profileVisibility || "public";
    const filePath = `users/${uid}/avatar.jpg`;
    const file = bucket.file(filePath);

    if (profileVisibility === "private" &&
        current.profileVisibility !== "private" &&
        current.avatarUrl) {
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: randomUUID() },
      });
      update.avatarUrl = null;
    } else if (profileVisibility === "public" &&
               current.profileVisibility === "private" &&
               !current.avatarUrl) {
      const [exists] = await file.exists();
      if (exists) {
        const token = randomUUID();
        await file.setMetadata({
          metadata: { firebaseStorageDownloadTokens: token },
        });
        update.avatarUrl = avatarDownloadUrl(bucket.name, filePath, token);
      }
    }

    await userRef.update(update);
    return { ok: true };
  };
}

module.exports = {
  avatarDownloadUrl,
  createAvatarPrivacySync,
  createUpdateSocialProfile,
};
