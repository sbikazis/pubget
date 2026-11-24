"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const ROOT = path.resolve(__dirname, "../..");
const read = (relative) => fs.readFileSync(path.join(ROOT, relative), "utf8");

function dartFiles(relativeDir) {
  const dir = path.join(ROOT, relativeDir);
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return dartFiles(path.join(relativeDir, entry.name));
    return entry.name.endsWith(".dart") ? [full] : [];
  });
}

test("the Flutter app no longer depends on the Firebase Storage SDK", () => {
  assert.doesNotMatch(read("pubspec.yaml"), /^\s*firebase_storage\s*:/m);
  for (const file of dartFiles("lib")) {
    assert.doesNotMatch(
      fs.readFileSync(file, "utf8"),
      /package:firebase_storage\//,
      `${file} still imports the Storage SDK`,
    );
  }
});

test("no dead GCS upload signer can be reintroduced into Functions", () => {
  for (const file of fs.readdirSync(path.join(ROOT, "functions/src"))) {
    if (!file.endsWith(".js")) continue;
    const source = read(`functions/src/${file}`);
    assert.doesNotMatch(source, /createFanWorksSigner/, file);
    assert.doesNotMatch(source, /createResumableUpload/, file);
  }
});

test("legacy reads stay a bounded bridge, never a permanent bearer URL", () => {
  const bridge = read("functions/src/legacyMediaBridge.js");
  assert.doesNotMatch(bridge, /getDownloadURL/);
  assert.doesNotMatch(bridge, /firebaseStorageDownloadTokens/);
  assert.match(bridge, /getSignedUrl/);
  assert.match(bridge, /authorizeLegacyPath/);
  assert.match(read("functions/index.js"), /exports\.resolveLegacyMedia/);
});
