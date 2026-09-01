"use strict";

const DISPLAY_FIELDS = Object.freeze([
  "username",
  "avatarUrl",
  "bio",
  "totalRespect",
  "fansCount",
]);

function buildPublicProfile(data) {
  const profile = {};
  for (const field of DISPLAY_FIELDS) {
    profile[field] = Object.prototype.hasOwnProperty.call(data, field)
      ? data[field]
      : field === "totalRespect" || field === "fansCount" ? 0 : null;
  }
  return profile;
}

function shouldPublishProfile(data) {
  return data.profileVisibility !== "private";
}

module.exports = { DISPLAY_FIELDS, buildPublicProfile, shouldPublishProfile };