"use strict";

const { EDITS_CONFIG } = require("./editsConfig");

/**
 * Reels are a separate product surface. Keep the shared ranking and
 * moderation defaults, but make the public duration contract explicit here.
 */
const REELS_CONFIG = Object.freeze({
  ...EDITS_CONFIG,
  maxDurationSeconds: 60,
  schemaVersion: 1,
  collectionName: "reels",
  storagePrefix: "reels",
  processedPrefix: "reels-processed",
  uploadKeyCollection: "reelUploadKeys",
});

module.exports = { REELS_CONFIG };