"use strict";

// Shared caption/text keyword filter. Fan Works and Group Chat only have
// report *reasons* today — there is no existing word-list to reuse.
// Visual/video-frame moderation is not available in this stack.

const BANNED_TERMS = Object.freeze([
  "kill yourself",
  "kys",
  "crypto giveaway",
  "free nitro",
  "nigger",
  "faggot",
]);

function normalize(text) {
  return String(text || "")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]+/gu, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function matchesTerm(haystack, term) {
  const escaped = String(term)
    .toLowerCase()
    .replace(/[.*+?^${}()|[\]\\]/g, "\\$&")
    .replace(/\s+/g, "\\s+");
  return new RegExp(`(?:^|\\s)${escaped}(?:$|\\s)`, "u").test(haystack);
}

function scanText(text) {
  const haystack = normalize(text);
  if (!haystack) return { flagged: false, term: null, reason: null };
  for (const term of BANNED_TERMS) {
    if (matchesTerm(haystack, term)) {
      return {
        flagged: true,
        term,
        reason: "Caption or tag contains prohibited language.",
      };
    }
  }
  return { flagged: false, term: null, reason: null };
}

function moderateEditCopy({ caption, animeTag } = {}) {
  return scanText([caption, animeTag].filter(Boolean).join(" "));
}

module.exports = {
  BANNED_TERMS,
  moderateEditCopy,
  scanText,
};
