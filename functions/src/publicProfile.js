"use strict";

const DISPLAY_FIELDS = Object.freeze([
  "username",
  "nickname",
  "avatarUrl",
  "bio",
  "favoriteAnimes",
  "age",
  "country",
  "nameColor",
  "totalRespect",
  "fansCount",
]);

function activePremiumBadge(data, now = new Date()) {
  if (data.subscriptionType !== "premium") return false;
  const expiry = data.premiumExpiresAt;
  const expiryDate = expiry && typeof expiry.toDate === "function"
    ? expiry.toDate()
    : expiry instanceof Date ? expiry : null;
  return expiryDate instanceof Date && expiryDate.getTime() > now.getTime();
}

function buildPublicProfile(uid, data, now = new Date()) {
  const profile = { uid, id: uid };
  for (const field of DISPLAY_FIELDS) {
    if (Object.prototype.hasOwnProperty.call(data, field) &&
        typeof data[field] !== "undefined") {
      profile[field] = data[field];
    }
  }
  profile.isPremium = activePremiumBadge(data, now);
  return profile;
}

module.exports = { DISPLAY_FIELDS, activePremiumBadge, buildPublicProfile };