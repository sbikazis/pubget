#!/usr/bin/env node
"use strict";

/**
 * Migrate group memberships from legacy ranks → Pubget MIKADO edition (rankV2).
 *
 * Dry-run by default. Pass --apply to write.
 *
 * Mapping:
 *   founder→mikado, shogun→shogun, commander→daimyo, captain→hatamoto,
 *   sensei→samurai, senpai→gokenin, member→ronin
 * Corrupt/null → ronin (fail-safe).
 *
 * Dual-write: sets rankV2 + roleLegacy, updates role to new id, seeds role docs,
 * stamps groups.migrationVersion = 2 (skips already-migrated groups).
 */

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const {
  LEGACY_ROLE_MAP,
  ROLE_PERMISSIONS,
  ROLE_POSITIONS,
  ROLES,
  normalizeRole,
  roleDefinition,
} = require("../src/pubgetRanks");

const args = process.argv.slice(2);
const apply = args.includes("--apply");
const pageSize = Number((() => {
  const i = args.indexOf("--page-size");
  return i === -1 ? "50" : args[i + 1];
})());

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const audit = {
  groupsScanned: 0,
  groupsMigrated: 0,
  groupsSkipped: 0,
  membersUpdated: 0,
  legacyCounts: Object.create(null),
  newCounts: Object.create(null),
  corruptToRonin: 0,
};

function mapRole(raw) {
  if (raw === undefined || raw === null || raw === "") {
    audit.corruptToRonin += 1;
    return "ronin";
  }
  const key = String(raw).trim().toLowerCase();
  audit.legacyCounts[key] = (audit.legacyCounts[key] || 0) + 1;
  if (LEGACY_ROLE_MAP[key]) return LEGACY_ROLE_MAP[key];
  if (ROLES.includes(key)) return key;
  audit.corruptToRonin += 1;
  return "ronin";
}

async function migrateGroup(groupDoc) {
  audit.groupsScanned += 1;
  const group = groupDoc.data() || {};
  if (group.migrationVersion === 2) {
    audit.groupsSkipped += 1;
    return;
  }

  const membersSnap = await groupDoc.ref.collection("members").get();
  const batch = db.batch();
  let ops = 0;

  for (const memberDoc of membersSnap.docs) {
    const data = memberDoc.data() || {};
    const legacy = data.role;
    const next = mapRole(data.rankV2 || legacy);
    audit.newCounts[next] = (audit.newCounts[next] || 0) + 1;
    batch.update(memberDoc.ref, {
      roleLegacy: typeof legacy === "string" ? legacy : null,
      role: next,
      rankV2: next,
      rankNoticePending: true,
      migratedAt: FieldValue.serverTimestamp(),
    });
    ops += 1;
    audit.membersUpdated += 1;
  }

  for (const role of ROLES) {
    batch.set(groupDoc.ref.collection("roles").doc(role), roleDefinition(role), {
      merge: true,
    });
    ops += 1;
  }

  batch.set(
    groupDoc.ref.collection("rankAudit").doc(),
    {
      type: "migration_v2",
      at: FieldValue.serverTimestamp(),
      memberCount: membersSnap.size,
      legacyCounts: { ...audit.legacyCounts },
    },
  );
  batch.update(groupDoc.ref, {
    migrationVersion: 2,
    ranksMigratedAt: FieldValue.serverTimestamp(),
  });
  ops += 2;

  if (apply && ops > 0) {
    await batch.commit();
    audit.groupsMigrated += 1;
  } else if (!apply) {
    audit.groupsMigrated += 1;
  }
}

async function main() {
  console.log(apply ? "APPLY mode" : "DRY RUN (pass --apply to write)");
  console.log("Using LEGACY_ROLE_MAP:", LEGACY_ROLE_MAP);
  let cursor = null;
  do {
    let query = db.collection("groups").orderBy("__name__").limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      await migrateGroup(doc);
    }
    cursor = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  } while (cursor);

  console.log(JSON.stringify(audit, null, 2));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
