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

function createUpdateSocialProfile({ db, bucket, randomUUID, HttpsError }) {
  return async function updateSocialProfile(request) {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }
    const uid = request.auth.uid;
    const input = request.data || {};
    const bio = input.bio;
    const favoriteAnimeIds = input.favoriteAnimeIds;
    const profileVisibility = input.profileVisibility;
    const activityVisibility = input.activityVisibility;
    const whoCanMessageMe = input.whoCanMessageMe;
    if (typeof bio !== "string" || bio.length > 500 ||
        !Array.isArray(favoriteAnimeIds) || favoriteAnimeIds.length > 50 ||
        favoriteAnimeIds.some((id) => typeof id !== "string" || id.length > 128) ||
        !["public", "private"].includes(profileVisibility) ||
        !["public", "private"].includes(activityVisibility) ||
        (whoCanMessageMe !== undefined &&
          !["related", "friends"].includes(whoCanMessageMe))) {
      throw new HttpsError("invalid-argument", "Profile update is invalid.");
    }

    const userRef = db.collection("users").doc(uid);
    const snapshot = await userRef.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "Profile not found.");
    }
    const current = snapshot.data() || {};
    const update = {
      bio: bio.trim(),
      favoriteAnimeIds,
      profileVisibility,
      activityVisibility,
    };
    if (whoCanMessageMe) update.whoCanMessageMe = whoCanMessageMe;
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