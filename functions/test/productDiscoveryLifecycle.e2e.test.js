"use strict";

// Prompt 19.1 multi-user discovery/creator lifecycle E2E against the Firebase
// Emulator Suite. This is not hosted production E2E.
//
// Production Edit state machine (see editsDomain.startUpload + editPipeline):
//   uploading → processing → published | failed
// There is no READY or PENDING_MODERATION state. Tests assert the real
// transitions rather than inventing extra statuses.

const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const fsp = require("node:fs/promises");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
process.env.FIREBASE_STORAGE_EMULATOR_HOST =
  process.env.FIREBASE_STORAGE_EMULATOR_HOST || "127.0.0.1:9199";
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "demo-pubget-security";

const admin = require("firebase-admin");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { createEditsDomain } = require("../src/editsDomain");
const { createEditPipeline } = require("../src/editPipeline");
const { createRecommendationEngine } = require("../src/recommendationEngine");
const { createFanWorksDomain } = require("../src/fanWorksDomain");
const { createGroupsDomain } = require("../src/groupsDomain");
const { createGroupChat } = require("../src/groupChat");
const { createSocialGraph } = require("../src/socialGraph");
const { createDiscoveryScheduler } = require("../src/discoveryEngine");
const { scoreEdit, editEngagement } = require("../src/ranking");

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

const PROJECT = "demo-pubget-security";
const BUCKET = `${PROJECT}.appspot.com`;
const ALICE = "alice";
const BOB = "bob";
const CREATOR = "creator";
const GROUP_OWNER = "groupowner";
const MALLORY = "mallory";
const ACTORS = [ALICE, BOB, CREATOR, GROUP_OWNER, MALLORY];
const ACCOUNT_AGE_MS = 10 * 24 * 60 * 60 * 1000;
const MEMBERSHIP_CLOCK_MS = 25 * 60 * 60 * 1000;
const STORY_BODY = "A short One Piece fan story about the crew leaving port.";

const firestoreRules = fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8");
const storageRules = fs.readFileSync(path.join(__dirname, "..", "..", "storage.rules"), "utf8");

let env;
let db;
let FieldValue;
let bucket;
let processEdit;
let videoBytes;

function auth(uid) {
  return { auth: { uid } };
}

function edits() {
  return createEditsDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

function recs() {
  return createRecommendationEngine({ db, HttpsError: TestHttpsError });
}

function fanWorks() {
  return createFanWorksDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

function groups() {
  return createGroupsDomain({ db, FieldValue, HttpsError: TestHttpsError });
}

function chat() {
  return createGroupChat({ db, FieldValue, HttpsError: TestHttpsError });
}

function social() {
  return createSocialGraph({ db, FieldValue, HttpsError: TestHttpsError });
}

function scheduler(clock) {
  return createDiscoveryScheduler({ db, FieldValue, clock });
}

function client(uid) {
  return env.authenticatedContext(uid).firestore();
}

function feedHas(feed, section, targetId) {
  const items = feed.sections[section] && feed.sections[section].items || [];
  return items.some((item) => item.targetId === targetId);
}

function feedItem(feed, section, targetId) {
  const items = feed.sections[section] && feed.sections[section].items || [];
  return items.find((item) => item.targetId === targetId) || null;
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function run(binary, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(binary, args, { stdio: ["ignore", "ignore", "pipe"] });
    let stderr = "";
    child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
    child.once("error", reject);
    child.once("exit", (code) => code === 0 ? resolve(stderr) :
      reject(new Error(`ffmpeg failed: ${code} ${stderr.slice(-500)}`)));
  });
}

async function generateShortMp4() {
  const destDir = await fsp.mkdtemp(path.join(os.tmpdir(), "pubget-e2e-edit-"));
  const dest = path.join(destDir, "clip.mp4");
  // 22s so one heartbeat (elapsed+2 cap) stays under the 10% qualification bar.
  await run("ffmpeg", [
    "-f", "lavfi", "-i", "color=c=blue:s=128x96:d=22:r=8",
    "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
    "-shortest", "-t", "22",
    "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "ultrafast",
    "-c:a", "aac", "-b:a", "32k",
    "-y", dest,
  ]);
  const bytes = await fsp.readFile(dest);
  await fsp.rm(destDir, { recursive: true, force: true });
  return bytes;
}

async function seedActors() {
  const createdAt = new Date(Date.now() - ACCOUNT_AGE_MS);
  await Promise.all(ACTORS.map((uid) => db.doc(`users/${uid}`).set({
    username: uid,
    favoriteAnimeIds: ["one_piece"],
    profileVisibility: "public",
    createdAt,
  })));
}

async function startEdit(caption = "Gear five port") {
  return edits().startUpload({
    ...auth(CREATOR),
    data: { caption, animeTag: "one_piece" },
  });
}

async function uploadEditBytes(videoStoragePath, bytes, contentType = "video/mp4") {
  const storage = env.authenticatedContext(CREATOR).storage();
  await assertSucceeds(storage.ref(videoStoragePath).put(bytes, { contentType }));
  await assertFails(
    env.authenticatedContext(MALLORY).storage().ref(videoStoragePath).put(bytes, { contentType }),
  );
  // Admin writes the same object the pipeline downloads. The rules-unit-testing
  // client and Admin SDK can land in different emulator bucket views.
  await bucket.file(videoStoragePath).save(bytes, {
    resumable: false,
    metadata: { contentType },
  });
}

async function runProcessEdit(videoStoragePath, bytes, contentType = "video/mp4") {
  let size = bytes.length;
  let type = contentType;
  try {
    const [meta] = await bucket.file(videoStoragePath).getMetadata();
    size = Number(meta.size || size);
    type = meta.contentType || type;
  } catch (_) {
    // Metadata is best-effort; the pipeline still receives the client MIME/size.
  }
  await processEdit({
    data: { name: videoStoragePath, contentType: type, size },
  });
}

async function publishCreatorEdit() {
  const started = await startEdit();
  const uploading = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(uploading.status, "uploading");
  assert.equal(uploading.creatorId, CREATOR);
  assert.equal(uploading.videoPath, `edits/${CREATOR}/${started.editId}.mp4`);
  await uploadEditBytes(started.videoPath, videoBytes);
  await runProcessEdit(started.videoPath, videoBytes);
  const published = (await db.doc(`edits/${started.editId}`).get()).data();
  return { editId: started.editId, data: published, videoPath: started.videoPath };
}

async function publishCreatorStory(title = "Log pose notes") {
  const draft = await fanWorks().saveFanWorkDraft({
    ...auth(CREATOR),
    data: {
      type: "story",
      title,
      description: "A credited One Piece fan story for discovery.",
      animeId: "one_piece",
      animeTitle: "One Piece",
      body: STORY_BODY,
      copyright: {
        originalWorkId: "one_piece",
        sourceTitle: "One Piece",
        credit: "Eiichiro Oda",
        license: "fan-work",
      },
    },
  });
  const unpublished = (await db.doc(`fanWorks/${draft.workId}`).get()).data();
  assert.equal(unpublished.status, "draft");
  assert.equal(unpublished.moderationStatus, "pending");
  const published = await fanWorks().publishFanWork({
    ...auth(CREATOR),
    data: { workId: draft.workId },
  });
  return { workId: draft.workId, alreadyPublished: published.alreadyPublished };
}

async function createSearchableGroup(uid, name) {
  return groups().createGroup({
    ...auth(uid),
    data: {
      name,
      description: "Straw hat sailors talk strategy every week here",
      type: "animeRoleplay",
      animeId: "one_piece",
      joinPolicy: "open",
      isSearchable: true,
      rules: "No spoilers in the main chat please stay kind",
    },
  });
}

async function sendText(uid, groupId, messageId, text, replyToMessageId) {
  return chat().sendMessage({
    ...auth(uid),
    data: {
      groupId,
      messageId,
      type: "text",
      text,
      ...(replyToMessageId ? { replyToMessageId } : {}),
    },
  });
}

async function qualifyWatch(uid, editId) {
  const playback = await edits().startPlayback({
    ...auth(uid),
    data: { editId },
  });
  assert.equal(playback.sessionId, uid);
  await wait(1500);
  await edits().recordView({
    ...auth(uid),
    data: {
      editId,
      sessionId: playback.sessionId,
      watchPercent: 40,
      watchSeconds: 10,
    },
  });
  return playback.sessionId;
}

async function reinitAdmin() {
  if (admin.apps.length) {
    try {
      await admin.app().delete();
    } catch (_) {
      // A prior emulator file may have terminated this app already.
    }
  }
  admin.initializeApp({
    projectId: PROJECT,
    storageBucket: BUCKET,
  });
  db = admin.firestore();
  FieldValue = admin.firestore.FieldValue;
  bucket = admin.storage().bucket(BUCKET);
  processEdit = createEditPipeline({ db, bucket });
}

test.before(async () => {
  await reinitAdmin();
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: { host: "127.0.0.1", port: 8080, rules: firestoreRules },
    storage: { host: "127.0.0.1", port: 9199, rules: storageRules },
  });
  videoBytes = await generateShortMp4();
});

test.after(async () => {
  if (env) await env.cleanup();
  try {
    if (db) await db.terminate();
  } catch (_) {
    // Combined emulator runs must not hang on open clients.
  }
  if (admin.apps.length) {
    try {
      await admin.app().delete();
    } catch (_) {
      // Best-effort process teardown.
    }
  }
});

test.beforeEach(async () => {
  if (env && typeof env.clearFirestore === "function") {
    await env.clearFirestore();
  }
  await seedActors();
});

test("creator publishes an edit through the production pipeline", { timeout: 120000 }, async () => {
  const started = await startEdit();
  const uploading = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(uploading.status, "uploading");
  assert.equal(uploading.creatorId, CREATOR);
  assert.equal(uploading.videoPath, `edits/${CREATOR}/${started.editId}.mp4`);
  assert.match(uploading.videoPath, new RegExp(`^edits/${CREATOR}/`));

  const aliceBefore = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceBefore, "recommendedEdits", started.editId), false);

  await assert.rejects(
    edits().startPlayback({ ...auth(BOB), data: { editId: started.editId } }),
    (error) => error.code === "not-found",
  );

  await uploadEditBytes(started.videoPath, videoBytes);
  await runProcessEdit(started.videoPath, videoBytes);
  const published = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(published.status, "published");
  assert.equal(published.creatorId, CREATOR);
  assert.ok(published.durationSeconds > 20);
  assert.ok(String(published.videoUrl).startsWith("edits-processed/"));
  assert.ok(String(published.thumbnailUrl).includes(`t_${started.editId}.jpg`));

  await runProcessEdit(started.videoPath, videoBytes);
  const afterDuplicate = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(afterDuplicate.status, "published");
  assert.equal(afterDuplicate.qualifiedViewsCount, 0);

  const aliceAfter = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceAfter, "recommendedEdits", started.editId), true);

  const failedStart = await startEdit("broken clip");
  await uploadEditBytes(failedStart.videoPath, Buffer.from("not-an-mp4"));
  await runProcessEdit(failedStart.videoPath, Buffer.from("not-an-mp4"));
  const failed = (await db.doc(`edits/${failedStart.editId}`).get()).data();
  assert.equal(failed.status, "failed");
  const aliceFailed = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceFailed, "recommendedEdits", failedStart.editId), false);
});

test("bob discovers, watches, and a qualified view changes ranking", { timeout: 120000 }, async () => {
  const { editId } = await publishCreatorEdit();
  const beforeDoc = (await db.doc(`edits/${editId}`).get()).data();
  assert.equal(beforeDoc.status, "published");
  assert.equal(beforeDoc.qualifiedViewsCount, 0);
  const rankingNow = new Date();
  const profile = { userId: ALICE, animeIds: ["one_piece"] };
  const engagementBefore = editEngagement(beforeDoc);
  const scoreBefore = scoreEdit(beforeDoc, profile, rankingNow);
  const aliceBefore = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceBefore, "recommendedEdits", editId), true);
  const aliceScoreBefore = feedItem(aliceBefore, "recommendedEdits", editId).score;

  const bobFeed = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(bobFeed, "recommendedEdits", editId), true);
  const sessionId = await qualifyWatch(BOB, editId);
  const session = (await db.doc(`edits/${editId}/playbackSessions/${sessionId}`).get()).data();
  assert.equal(session.viewerId, BOB);
  assert.notEqual(BOB, CREATOR);

  const afterDoc = (await db.doc(`edits/${editId}`).get()).data();
  assert.equal(afterDoc.qualifiedViewsCount, 1);
  assert.ok(editEngagement(afterDoc) > engagementBefore);
  assert.ok(scoreEdit(afterDoc, profile, rankingNow) > scoreBefore);
  const aliceAfter = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  const aliceScoreAfter = feedItem(aliceAfter, "recommendedEdits", editId).score;
  assert.ok(aliceScoreAfter > aliceScoreBefore);

  await edits().recordView({
    ...auth(BOB),
    data: { editId, sessionId, watchPercent: 50, watchSeconds: 12 },
  });
  assert.equal((await db.doc(`edits/${editId}`).get()).data().qualifiedViewsCount, 1);

  const selfPlayback = await edits().startPlayback({
    ...auth(CREATOR),
    data: { editId },
  });
  await wait(1500);
  await edits().recordView({
    ...auth(CREATOR),
    data: {
      editId,
      sessionId: selfPlayback.sessionId,
      watchPercent: 40,
      watchSeconds: 10,
    },
  });
  assert.equal((await db.doc(`edits/${editId}`).get()).data().qualifiedViewsCount, 1);

  const second = await publishCreatorEdit();
  const fakePlayback = await edits().startPlayback({
    ...auth(BOB),
    data: { editId: second.editId },
  });
  await edits().recordView({
    ...auth(BOB),
    data: {
      editId: second.editId,
      sessionId: fakePlayback.sessionId,
      watchPercent: 100,
      watchSeconds: 3600,
    },
  });
  const fabricated = (await db.doc(`edits/${second.editId}`).get()).data();
  assert.equal(fabricated.qualifiedViewsCount, 0);
  const fakeSession = (await db.doc(
    `edits/${second.editId}/playbackSessions/${fakePlayback.sessionId}`,
  ).get()).data();
  assert.ok(fakeSession.creditedSeconds < 8);
  await assert.rejects(
    edits().recordView({
      ...auth(BOB),
      data: {
        editId: second.editId,
        sessionId: ALICE,
        watchPercent: 40,
        watchSeconds: 10,
      },
    }),
    (error) => error.code === "failed-precondition",
  );
});

test("fan work enters discovery and leaves when flagged or archived", async () => {
  const { workId } = await publishCreatorStory();
  const stored = (await db.doc(`fanWorks/${workId}`).get()).data();
  assert.equal(stored.status, "published");
  assert.equal(stored.visibility, "public");
  assert.equal(stored.moderationStatus, "approved");
  assert.equal(stored.creatorId, CREATOR);
  assert.equal(stored.copyright.originalWorkId, "one_piece");
  assert.ok(stored.content.body.length >= 20);

  const duplicate = await fanWorks().publishFanWork({
    ...auth(CREATOR),
    data: { workId },
  });
  assert.equal(duplicate.alreadyPublished, true);
  assert.equal((await db.doc(`fanWorks/${workId}`).get()).data().status, "published");

  const bob = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(bob, "recommendedFanWorks", workId), true);

  await fanWorks().reportFanWork({
    ...auth(ALICE),
    data: { workId, reason: "spam", details: "copy" },
  });
  assert.equal((await db.doc(`fanWorks/${workId}`).get()).data().moderationStatus, "flagged");
  const afterFlag = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(afterFlag, "recommendedFanWorks", workId), false);

  const second = await publishCreatorStory("Thousand Sunny log");
  await fanWorks().archiveFanWork({
    ...auth(CREATOR),
    data: { workId: second.workId },
  });
  assert.equal((await db.doc(`fanWorks/${second.workId}`).get()).data().status, "archived");
  const afterArchive = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(afterArchive, "recommendedFanWorks", second.workId), false);
});

test("group becomes rising eligible from real activity", async () => {
  const active = await createSearchableGroup(GROUP_OWNER, "Active crew");
  await groups().joinGroup({ ...auth(ALICE), data: { groupId: active.groupId } });
  await groups().joinGroup({ ...auth(BOB), data: { groupId: active.groupId } });
  await sendText(GROUP_OWNER, active.groupId, "m1", "Planning the next island run together");
  await sendText(ALICE, active.groupId, "m2", "I can chart the log pose tonight", "m1");
  await sendText(BOB, active.groupId, "m3", "I will bring snacks for the crew", "m2");
  await sendText(GROUP_OWNER, active.groupId, "m1", "Planning the next island run together");
  const quiet = await createSearchableGroup(MALLORY, "Quiet bench");
  await groups().joinGroup({ ...auth(ALICE), data: { groupId: quiet.groupId } });
  await db.doc("groups/large-idle").set({
    name: "Huge idle club",
    searchName: "huge idle club",
    description: "A large group that barely talks anymore at all",
    rules: "Keep the hall civil even when nobody is posting",
    imageUrl: "https://example.com/idle.png",
    type: "public",
    animeId: "one_piece",
    founderId: MALLORY,
    membersCount: 90,
    maxMembers: 100,
    joinPolicy: "open",
    isSearchable: true,
    createdAt: new Date(Date.now() - 40 * 24 * 60 * 60 * 1000),
  });

  const before = (await db.doc(`groups/${active.groupId}`).get()).data();
  assert.equal(before.risingEligible, false);
  assert.equal(before.activityScore, 0);

  await scheduler({
    now: () => new Date(Date.now() + MEMBERSHIP_CLOCK_MS),
  }).updateScores();

  const activeAfter = (await db.doc(`groups/${active.groupId}`).get()).data();
  const quietAfter = (await db.doc(`groups/${quiet.groupId}`).get()).data();
  const idleAfter = (await db.doc("groups/large-idle").get()).data();
  assert.equal(activeAfter.risingEligible, true);
  assert.ok(activeAfter.risingScore > 0);
  assert.ok(activeAfter.activityScore > 0);
  assert.ok(activeAfter.risingScore > (quietAfter.risingScore || 0));
  assert.ok(activeAfter.risingScore > (idleAfter.risingScore || 0));
  assert.ok((idleAfter.membersCount || 0) > (activeAfter.membersCount || 0));

  const rising = await db.collection("groups")
    .where("risingEligible", "==", true)
    .get();
  assert.equal(rising.docs.some((doc) => doc.id === active.groupId), true);
  const malloryFeed = await recs().getDiscoveryFeed({ ...auth(MALLORY) });
  assert.equal(feedHas(malloryFeed, "recommendedGroups", active.groupId), true);
});

test("blocked creator content is excluded only for the blocker", { timeout: 120000 }, async () => {
  const { editId } = await publishCreatorEdit();
  const { workId } = await publishCreatorStory();
  const aliceBefore = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  const bobBefore = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(aliceBefore, "recommendedEdits", editId), true);
  assert.equal(feedHas(aliceBefore, "recommendedFanWorks", workId), true);
  assert.equal(feedHas(bobBefore, "recommendedEdits", editId), true);

  await social().blockUser({ ...auth(ALICE), data: { otherUserId: CREATOR } });
  await social().blockUser({ ...auth(ALICE), data: { otherUserId: CREATOR } });
  const aliceBlocked = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  const bobStill = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(aliceBlocked, "recommendedEdits", editId), false);
  assert.equal(feedHas(aliceBlocked, "recommendedFanWorks", workId), false);
  assert.equal(feedHas(aliceBlocked, "risingCreators", CREATOR), false);
  assert.equal(feedHas(bobStill, "recommendedEdits", editId), true);
  assert.equal(feedHas(bobStill, "recommendedFanWorks", workId), true);
  assert.equal((await db.doc(`edits/${editId}`).get()).data().status, "published");

  await social().unblockUser({ ...auth(ALICE), data: { otherUserId: CREATOR } });
  const aliceUnblocked = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceUnblocked, "recommendedEdits", editId), true);
  assert.equal(feedHas(aliceUnblocked, "recommendedFanWorks", workId), true);
});

test("clients cannot forge discovery authority fields", { timeout: 120000 }, async () => {
  const { editId } = await publishCreatorEdit();
  const { workId } = await publishCreatorStory();
  const group = await createSearchableGroup(GROUP_OWNER, "Authority crew");
  await assertFails(client(CREATOR).doc(`edits/${editId}`).update({
    status: "published", qualifiedViewsCount: 99, score: 99,
  }));
  await assertFails(client(BOB).doc(`edits/${editId}/playbackSessions/${CREATOR}`).set({
    viewerId: CREATOR, consumed: false, creditedSeconds: 50,
  }));
  await assertFails(client(ALICE).doc(`fanWorks/${workId}`).update({
    status: "published", moderationStatus: "approved",
  }));
  await assertFails(client(GROUP_OWNER).doc(`groups/${group.groupId}`).update({
    risingScore: 99, risingEligible: true, activityScore: 99,
  }));
  await assertFails(client(BOB).doc("friendships/alice_creator").set({
    userA: ALICE, userB: CREATOR, userIds: [ALICE, CREATOR],
    status: "blocked", blockedBy: BOB,
  }));
});

test("integrated creator discovery lifecycle", { timeout: 180000 }, async () => {
  const started = await startEdit();
  assert.equal(feedHas(
    await recs().getDiscoveryFeed({ ...auth(ALICE) }),
    "recommendedEdits",
    started.editId,
  ), false);
  await uploadEditBytes(started.videoPath, videoBytes);
  await runProcessEdit(started.videoPath, videoBytes);
  const edit = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(edit.status, "published");
  const { workId } = await publishCreatorStory();
  const active = await createSearchableGroup(GROUP_OWNER, "Integrated crew");
  await groups().joinGroup({ ...auth(ALICE), data: { groupId: active.groupId } });
  await groups().joinGroup({ ...auth(BOB), data: { groupId: active.groupId } });
  await sendText(GROUP_OWNER, active.groupId, "i1", "Crew meeting starts at sundown tonight");
  await sendText(ALICE, active.groupId, "i2", "I will bring the log pose notes", "i1");
  await sendText(BOB, active.groupId, "i3", "I saved a table at the tavern", "i2");
  await scheduler({
    now: () => new Date(Date.now() + MEMBERSHIP_CLOCK_MS),
  }).updateScores();
  const groupAfter = (await db.doc(`groups/${active.groupId}`).get()).data();
  assert.equal(groupAfter.risingEligible, true);

  const aliceSees = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  assert.equal(feedHas(aliceSees, "recommendedEdits", started.editId), true);
  assert.equal(feedHas(aliceSees, "recommendedFanWorks", workId), true);
  const mallorySees = await recs().getDiscoveryFeed({ ...auth(MALLORY) });
  assert.equal(feedHas(mallorySees, "recommendedGroups", active.groupId), true);

  const beforeWatch = (await db.doc(`edits/${started.editId}`).get()).data();
  const rankingNow = new Date();
  const profile = { userId: ALICE, animeIds: ["one_piece"] };
  const scoreBefore = scoreEdit(beforeWatch, profile, rankingNow);
  const engagementBefore = editEngagement(beforeWatch);
  await qualifyWatch(BOB, started.editId);
  const afterWatch = (await db.doc(`edits/${started.editId}`).get()).data();
  assert.equal(afterWatch.qualifiedViewsCount, 1);
  assert.ok(editEngagement(afterWatch) > engagementBefore);
  assert.ok(scoreEdit(afterWatch, profile, rankingNow) > scoreBefore);

  await social().blockUser({ ...auth(ALICE), data: { otherUserId: CREATOR } });
  const aliceBlocked = await recs().getDiscoveryFeed({ ...auth(ALICE) });
  const bobStill = await recs().getDiscoveryFeed({ ...auth(BOB) });
  assert.equal(feedHas(aliceBlocked, "recommendedEdits", started.editId), false);
  assert.equal(feedHas(aliceBlocked, "recommendedFanWorks", workId), false);
  assert.equal(feedHas(bobStill, "recommendedEdits", started.editId), true);
  assert.equal(feedHas(bobStill, "recommendedFanWorks", workId), true);
});
