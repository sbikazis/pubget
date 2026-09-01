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

module.exports = { avatarDownloadUrl, createAvatarPrivacySync };