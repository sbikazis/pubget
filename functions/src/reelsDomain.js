"use strict";

const { createEditsDomain } = require("./editsDomain");
const { REELS_CONFIG } = require("./reelsConfig");

function withReelId(request) {
  const data = { ...(request.data || {}) };
  if (data.reelId && !data.editId) data.editId = data.reelId;
  return { ...request, data };
}

function mapId(result) {
  if (!result || typeof result !== "object") return result;
  const mapped = { ...result };
  if (mapped.editId) {
    mapped.reelId = mapped.editId;
    delete mapped.editId;
  }
  return mapped;
}

/**
 * Reuse the hardened upload/playback/social implementation while exposing a
 * first-class Reels collection and storage namespace. This adapter is
 * deliberately narrow: Reels never read or write the legacy edits collection.
 */
function createReelsDomain(options) {
  const domain = createEditsDomain({
    ...options,
    collectionName: REELS_CONFIG.collectionName,
    uploadKeyCollection: REELS_CONFIG.uploadKeyCollection,
    storagePrefix: REELS_CONFIG.storagePrefix,
    config: REELS_CONFIG,
  });

  const call = (name, map = mapId) => async (request) =>
    map(await domain[name](withReelId(request)));

  return {
    startUpload: call("startUpload"),
    repost: call("repost"),
    deleteReel: call("deleteEdit"),
    likeReel: call("like"),
    comment: call("comment"),
    startPlayback: call("startPlayback"),
    recordView: call("recordView"),
    signal: call("signal"),
    commentAction: call("commentAction"),
    getFeed: call("getEditFeed"),
    retryProcessing: call("retryProcessing"),
    finalizeUpload: call("finalizeUpload"),
  };
}

module.exports = { createReelsDomain };