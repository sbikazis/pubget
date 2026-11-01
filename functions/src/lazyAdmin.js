"use strict";

const admin = require("firebase-admin");

// The Functions deploy discovery process loads every module in this
// codebase and gives it a 10s window to start. Eager admin.firestore()
// / admin.storage() calls resolve cloud resources and open gRPC channels
// at load time, which can block past that window on slow or
// credential-less machines and fail the deploy with "Cannot determine
// backend specification". Return shared proxies that initialize the real
// client on first use instead — the cloud runtime has fast, valid
// credentials.
function lazyClient(init) {
  let client;
  return new Proxy({}, {
    get(_target, prop) {
      client ??= init();
      const value = client[prop];
      return typeof value === "function" ? value.bind(client) : value;
    },
  });
}

const firestore = lazyClient(() => admin.firestore());
const storageBucket = lazyClient(() => admin.storage().bucket());
const messaging = lazyClient(() => admin.messaging());

module.exports = { firestore, storageBucket, messaging };
