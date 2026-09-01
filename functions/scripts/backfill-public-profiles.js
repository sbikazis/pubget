#!/usr/bin/env node
"use strict";

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldPath } = require("firebase-admin/firestore");
const {
  buildPublicProfile,
  shouldPublishProfile,
} = require("../src/publicProfile");

const args = process.argv.slice(2);
const apply = args.includes("--apply");

function option(name, fallback) {
  const index = args.indexOf(name);
  return index === -1 ? fallback : args[index + 1];
}

const pageSize = Number(option("--page-size", "250"));
const startAfter = option("--start-after", null);
const maxPages = Number(option("--max-pages", "0"));

if (!Number.isInteger(pageSize) || pageSize < 1 || pageSize > 500) {
  throw new Error("--page-size must be an integer from 1 to 500");
}
if (!Number.isInteger(maxPages) || maxPages < 0) {
  throw new Error("--max-pages must be a non-negative integer");
}

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

async function main() {
  let cursor = startAfter;
  let pages = 0;
  let scanned = 0;
  let written = 0;

  console.log(apply ? "APPLY mode" : "DRY RUN (pass --apply to write)");
  do {
    let query = db.collection("users")
      .orderBy(FieldPath.documentId())
      .limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = apply ? db.batch() : null;
    for (const doc of snapshot.docs) {
      if (batch) {
        const publicRef = db.collection("public_profiles").doc(doc.id);
        if (shouldPublishProfile(doc.data())) {
          batch.set(publicRef, buildPublicProfile(doc.data()));
        } else {
          batch.delete(publicRef);
        }
      }
      scanned += 1;
    }
    if (batch) {
      await batch.commit();
      written += snapshot.size;
    }

    cursor = snapshot.docs[snapshot.docs.length - 1].id;
    pages += 1;
    console.log(`page=${pages} scanned=${scanned} written=${written} resumeAfter=${cursor}`);
    if (maxPages && pages >= maxPages) break;
    if (snapshot.size < pageSize) break;
  } while (true);

  console.log(`complete scanned=${scanned} written=${written} lastDocument=${cursor || ""}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});