"use strict";

const DISPLAY_FIELDS = Object.freeze([
  "username",
  "displayName",
  "avatarUrl",
  "coverUrl",
  "bio",
  "age",
  "country",
  "favoriteQuote",
  "animeTwin",
  "socialLinks",
  "totalRespect",
  "fansCount",
  "equippedFrameId",
  "equippedBadgeId",
  "equippedNameplateId",
  "favoriteAnimeIds",
  "favoriteAnimes",
  "sectionPrivacy",
  "createdAt",
]);

function defaultFor(field) {
  if (field === "totalRespect" || field === "fansCount") return 0;
  if (field === "favoriteAnimeIds" || field === "favoriteAnimes") return [];
  if (field === "socialLinks") return [];
  if (field === "sectionPrivacy") {
    return {
      favorites: true,
      activity: true,
      friends: true,
      fans: true,
      works: true,
      groups: true,
      ratings: true,
      achievements: true,
    };
  }
  if (field.startsWith("equipped")) return "";
  return null;
}

function buildPublicProfile(data) {
  const profile = {};
  const privacy = data.sectionPrivacy || {};
  for (const field of DISPLAY_FIELDS) {
    profile[field] = Object.prototype.hasOwnProperty.call(data, field)
      ? data[field]
      : defaultFor(field);
  }

  // Honor per-section privacy on the public projection itself.
  if (privacy.favorites === false) {
    profile.favoriteAnimeIds = [];
    profile.favoriteAnimes = [];
  }
  if (privacy.fans === false) {
    profile.fansCount = 0;
  }
  return profile;
}

function shouldPublishProfile(data) {
  return data.profileVisibility !== "private";
}

module.exports = { DISPLAY_FIELDS, buildPublicProfile, shouldPublishProfile };
