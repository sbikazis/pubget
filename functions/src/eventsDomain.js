"use strict";

// Events domain (PROMPT 11).
//
// Independent of group-chat internals: chat activity is posted through
// postEventChatActivity as type "event" system cards. Notifications use the
// existing notification builder. Group permissions reuse ROLE_PERMISSIONS.

const { ROLE_PERMISSIONS } = require("./groupsDomain");
const catalog = require("./gameCatalog");

const MAX_DURATION_MS = 7 * 24 * 60 * 60 * 1000;
const TITLE_MAX = 80;
const DESCRIPTION_MAX = 500;
const OPTION_MAX = 10;
const OPTION_MIN = 2;
const TEXT_MAX = 1000;
const EVENT_ID_MAX = 128;

const EVENT_TYPES = [
  "poll", "multipleChoice", "ranking", "versus", "theory", "prediction",
  "quiz", "imageComparison", "characterComparison", "animeComparison",
  "openDiscussion", "challenge",
];

const STATUSES = [
  "draft", "scheduled", "active", "ended", "cancelled", "archived",
];

const TRANSITIONS = {
  draft: new Set(["scheduled", "active", "cancelled"]),
  scheduled: new Set(["active", "cancelled"]),
  active: new Set(["ended", "cancelled"]),
  ended: new Set(["archived"]),
  cancelled: new Set(["archived"]),
  archived: new Set(),
};

const TEMPLATES = {
  animeBattle: { type: "versus", title: "Anime Battle" },
  bestCharacter: { type: "characterComparison", title: "Best Character" },
  theoryNight: { type: "theory", title: "Theory Night" },
  emojiChallenge: { type: "challenge", title: "Emoji Challenge" },
  guessCharacter: { type: "quiz", title: "Guess the Character" },
};

const CHALLENGE_KINDS = Object.freeze([
  "finish_game",
  "publish_edit",
  "create_group",
  "participate_event",
  "self_report",
]);

const CHALLENGE_EVIDENCE = Object.freeze({
  finish_game: { achievementId: "community_milestone" },
  publish_edit: { achievementId: "first_edit" },
  create_group: { achievementId: "first_group" },
});

const IMAGE_MIME_TYPES = Object.freeze([
  "image/jpeg", "image/png", "image/webp", "image/gif",
]);

const COMPARISON_TYPES = Object.freeze([
  "imageComparison", "characterComparison", "animeComparison",
]);

function validString(value, max) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= max;
}

function requireAuth(request, HttpsError) {
  if (!request || !request.auth || !validString(request.auth.uid, 128)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function eventRef(db, eventId) {
  return db.collection("events").doc(eventId);
}

function participantRef(db, eventId, uid) {
  return eventRef(db, eventId).collection("participants").doc(uid);
}

function responseRef(db, eventId, uid) {
  return eventRef(db, eventId).collection("responses").doc(uid);
}

function groupRef(db, groupId) {
  return db.collection("groups").doc(groupId);
}

function memberRef(db, groupId, uid) {
  return groupRef(db, groupId).collection("members").doc(uid);
}

function roleRef(db, groupId, role) {
  return groupRef(db, groupId).collection("roles").doc(role);
}

function assertTransition(from, to, HttpsError) {
  if (!STATUSES.includes(from) || !STATUSES.includes(to) ||
      !TRANSITIONS[from].has(to)) {
    throw new HttpsError(
      "failed-precondition",
      `Cannot move an event from ${from} to ${to}.`,
    );
  }
}

function dateOf(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "string" || typeof value === "number") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function assertDuration(startAt, endAt, HttpsError) {
  const start = dateOf(startAt);
  const end = dateOf(endAt);
  if (!start || !end || Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) {
    throw new HttpsError("invalid-argument", "Start and end times are required.");
  }
  if (end.getTime() <= start.getTime()) {
    throw new HttpsError("invalid-argument", "End time must be after start time.");
  }
  if (end.getTime() - start.getTime() > MAX_DURATION_MS) {
    throw new HttpsError("invalid-argument", "Events cannot last longer than 7 days.");
  }
  return { start, end };
}

function normalizeOptions(raw, { min = OPTION_MIN, max = OPTION_MAX } = {}) {
  if (!Array.isArray(raw) || raw.length < min || raw.length > max) return null;
  const options = [];
  const seen = new Set();
  for (let index = 0; index < raw.length; index += 1) {
    const item = raw[index];
    let id;
    let label;
    let imageUrl = "";
    if (typeof item === "string") {
      label = item.trim();
      id = `opt-${index + 1}`;
    } else if (item && typeof item === "object") {
      label = typeof item.label === "string" ? item.label.trim()
        : (typeof item.name === "string" ? item.name.trim() : "");
      id = validString(item.id, 64) ? item.id.trim() : `opt-${index + 1}`;
      imageUrl = typeof item.imageUrl === "string" ? item.imageUrl.trim() : "";
      if (imageUrl.length > 1024) return null;
    } else {
      return null;
    }
    if (!label || label.length > 80 || seen.has(id)) return null;
    seen.add(id);
    options.push({ id, label, imageUrl });
  }
  return options;
}

function optionIds(options) {
  return new Set(options.map((item) => item.id));
}

function validateQuiz(questions) {
  if (!Array.isArray(questions) || questions.length < 1 || questions.length > 20) {
    return null;
  }
  const normalized = [];
  for (let index = 0; index < questions.length; index += 1) {
    const question = questions[index];
    if (!question || !validString(question.prompt, 200)) return null;
    const options = normalizeOptions(question.options, { min: 2, max: 6 });
    if (!options) return null;
    const correctId = typeof question.correctOptionId === "string"
      ? question.correctOptionId
      : (options[Number.isInteger(question.correctIndex) ? question.correctIndex : 0] || {}).id;
    if (!optionIds(options).has(correctId)) return null;
    normalized.push({
      id: validString(question.id, 64) ? question.id.trim() : `q-${index + 1}`,
      prompt: question.prompt.trim(),
      options,
      correctOptionId: correctId,
    });
  }
  return normalized;
}

function pickCriterion(input) {
  const value = input.criterion || input.question || input.prompt || input.title;
  return validString(value, 200) ? value.trim() : "";
}

function validHttpsImageUrl(url) {
  if (typeof url !== "string" || url.trim().length < 12 || url.trim().length > 1024) {
    return false;
  }
  try {
    const parsed = new URL(url.trim());
    return parsed.protocol === "https:" &&
      !parsed.username &&
      !parsed.password &&
      Boolean(parsed.hostname);
  } catch (_) {
    return false;
  }
}

function candidateList(input) {
  return input.candidates || input.options || input.items;
}

function validateCharacterComparison(input) {
  const criterion = pickCriterion(input);
  const raw = candidateList(input);
  if (!criterion || !Array.isArray(raw) || raw.length < OPTION_MIN || raw.length > OPTION_MAX) {
    return null;
  }
  const options = [];
  const seen = new Set();
  for (const item of raw) {
    let characterId = "";
    if (typeof item === "string") characterId = item.trim();
    else if (item && typeof item === "object") {
      characterId = validString(item.characterId, 64) ? item.characterId.trim()
        : (validString(item.id, 64) ? item.id.trim() : "");
    }
    const character = catalog.characterById(characterId);
    if (!character || seen.has(character.id)) return null;
    seen.add(character.id);
    options.push({
      id: character.id,
      label: character.name,
      characterId: character.id,
      animeId: character.animeId,
      animeTitle: character.animeTitle,
    });
  }
  return {
    allowMultiple: false,
    allowUpdate: input.allowUpdate === true,
    question: criterion,
    criterion,
    comparisonType: "character",
    options,
    candidates: options.map((item) => ({
      characterId: item.characterId,
      animeId: item.animeId,
    })),
    maxSelections: 1,
  };
}

function validateAnimeComparison(input) {
  const criterion = pickCriterion(input);
  const raw = candidateList(input);
  if (!criterion || !Array.isArray(raw) || raw.length < OPTION_MIN || raw.length > OPTION_MAX) {
    return null;
  }
  const options = [];
  const seen = new Set();
  for (const item of raw) {
    let animeId = "";
    if (typeof item === "string") animeId = item.trim();
    else if (item && typeof item === "object") {
      animeId = validString(item.animeId, 64) ? item.animeId.trim()
        : (validString(item.id, 64) ? item.id.trim() : "");
    }
    const anime = catalog.byAnimeId(animeId);
    if (!anime || seen.has(anime.id)) return null;
    seen.add(anime.id);
    options.push({
      id: anime.id,
      label: anime.title,
      animeId: anime.id,
    });
  }
  return {
    allowMultiple: false,
    allowUpdate: input.allowUpdate === true,
    question: criterion,
    criterion,
    comparisonType: "anime",
    options,
    candidates: options.map((item) => ({ animeId: item.animeId })),
    maxSelections: 1,
  };
}

function validateImageComparison(input) {
  const criterion = pickCriterion(input);
  const raw = candidateList(input);
  if (!criterion || !Array.isArray(raw) || raw.length < OPTION_MIN || raw.length > OPTION_MAX) {
    return null;
  }
  const options = [];
  const seenUrls = new Set();
  for (let index = 0; index < raw.length; index += 1) {
    const item = raw[index];
    if (!item || typeof item !== "object") return null;
    const imageUrl = typeof item.imageUrl === "string" ? item.imageUrl.trim() : "";
    const mimeType = typeof item.mimeType === "string" ? item.mimeType.trim().toLowerCase() : "";
    const license = typeof item.license === "string" ? item.license.trim() : "";
    const attribution = typeof item.attribution === "string" ? item.attribution.trim() : "";
    const label = validString(item.label || item.caption, 80)
      ? (item.label || item.caption).trim()
      : `Image ${index + 1}`;
    if (!validHttpsImageUrl(imageUrl) ||
        !IMAGE_MIME_TYPES.includes(mimeType) ||
        !validString(license, 80) ||
        !validString(attribution, 200) ||
        seenUrls.has(imageUrl)) {
      return null;
    }
    seenUrls.add(imageUrl);
    const id = validString(item.id, 64) ? item.id.trim() : `img-${index + 1}`;
    if (options.some((option) => option.id === id)) return null;
    options.push({
      id,
      label,
      imageUrl,
      mimeType,
      license,
      attribution,
    });
  }
  return {
    allowMultiple: false,
    allowUpdate: input.allowUpdate === true,
    question: criterion,
    criterion,
    comparisonType: "image",
    options,
    candidates: options.map((item) => ({
      id: item.id,
      imageUrl: item.imageUrl,
      mimeType: item.mimeType,
      license: item.license,
      attribution: item.attribution,
    })),
    maxSelections: 1,
  };
}

function validateChallenge(input) {
  const prompt = validString(input.prompt || input.question, 200)
    ? (input.prompt || input.question).trim()
    : "";
  if (!prompt) return null;
  const challengeKind = validString(input.challengeKind, 40)
    ? input.challengeKind.trim()
    : "self_report";
  if (!CHALLENGE_KINDS.includes(challengeKind)) return null;
  let targetEventId = "";
  if (challengeKind === "participate_event") {
    if (!validString(input.targetEventId, EVENT_ID_MAX)) return null;
    targetEventId = input.targetEventId.trim();
  }
  return {
    allowMultiple: false,
    allowUpdate: input.allowUpdate === true,
    prompt,
    challengeKind,
    targetEventId,
    verification: challengeKind === "self_report" ? "self_reported" : "server",
    completionRule: typeof input.completionRule === "string"
      ? input.completionRule.trim().slice(0, 200)
      : "",
    allowVoting: false,
  };
}

function validateConfiguration(type, raw) {
  const input = raw && typeof raw === "object" ? raw : {};
  const allowMultiple = input.allowMultiple === true;
  const allowUpdate = input.allowUpdate === true;
  const base = { allowMultiple, allowUpdate };
  if (type === "quiz") {
    const questions = validateQuiz(input.questions);
    if (!questions) return null;
    return { ...base, allowUpdate: false, questions };
  }
  if (type === "characterComparison") return validateCharacterComparison(input);
  if (type === "animeComparison") return validateAnimeComparison(input);
  if (type === "imageComparison") return validateImageComparison(input);
  if (type === "challenge") return validateChallenge(input);
  if (type === "theory" || type === "openDiscussion") {
    const prompt = validString(input.prompt || input.question, 200)
      ? (input.prompt || input.question).trim()
      : "";
    if (!prompt) return null;
    return {
      ...base,
      prompt,
      allowVoting: input.allowVoting === true,
      completionRule: typeof input.completionRule === "string"
        ? input.completionRule.trim().slice(0, 200)
        : "",
    };
  }
  const question = validString(input.question || input.prompt || input.title, 200)
    ? (input.question || input.prompt || input.title).trim()
    : "";
  const source = input.options || input.candidates || input.items;
  const min = type === "versus" ? 2 : OPTION_MIN;
  const options = normalizeOptions(source, { min, max: OPTION_MAX });
  if (!question || !options) return null;
  let maxSelections = 1;
  if (type === "poll" && allowMultiple) maxSelections = options.length;
  if (type === "multipleChoice") {
    maxSelections = Number.isInteger(input.maxSelections) ? input.maxSelections : 1;
    if (maxSelections < 1 || maxSelections > options.length) return null;
  }
  return { ...base, question, options, maxSelections };
}

function validateResponse(type, configuration, data) {
  const payload = data && typeof data === "object" ? data : {};
  if (type === "quiz") {
    const answers = payload.answers && typeof payload.answers === "object"
      ? payload.answers
      : {};
    const next = {};
    for (const question of configuration.questions) {
      const chosen = answers[question.id];
      if (!validString(chosen, 64) || !optionIds(question.options).has(chosen)) {
        return null;
      }
      next[question.id] = chosen;
    }
    return { answers: next };
  }
  if (type === "challenge") {
    const text = typeof payload.text === "string" ? payload.text.trim().slice(0, TEXT_MAX) : "";
    return {
      text,
      challengeKind: configuration.challengeKind || "self_report",
    };
  }
  if (type === "theory" || type === "openDiscussion") {
    if (!validString(payload.text, TEXT_MAX)) return null;
    return { text: payload.text.trim() };
  }
  if (type === "ranking") {
    const ranked = Array.isArray(payload.rankedIds) ? payload.rankedIds : [];
    const expected = configuration.options.map((item) => item.id);
    if (ranked.length !== expected.length) return null;
    const seen = new Set();
    for (const id of ranked) {
      if (!expected.includes(id) || seen.has(id)) return null;
      seen.add(id);
    }
    return { rankedIds: ranked };
  }
  const ids = Array.isArray(payload.optionIds)
    ? payload.optionIds
    : (payload.optionId ? [payload.optionId] : []);
  if (ids.length < 1 || ids.length > (configuration.maxSelections || 1)) return null;
  const allowed = optionIds(configuration.options || []);
  const unique = [];
  for (const id of ids) {
    if (!allowed.has(id) || unique.includes(id)) return null;
    unique.push(id);
  }
  return { optionIds: unique, optionId: unique[0] };
}

function emptyTally(configuration, type) {
  if (type === "quiz") {
    return { correctCounts: {}, submissions: 0 };
  }
  if (type === "ranking") {
    const scores = {};
    (configuration.options || []).forEach((item) => { scores[item.id] = 0; });
    return { scores, submissions: 0 };
  }
  if (type === "theory" || type === "openDiscussion" || type === "challenge") {
    return {
      submissions: 0,
      verifiedCompletions: 0,
      selfReported: 0,
    };
  }
  const votes = {};
  (configuration.options || []).forEach((item) => { votes[item.id] = 0; });
  return { votes, submissions: 0 };
}

function bumpMap(map, id, amount) {
  map[id] = Math.max(0, (map[id] || 0) + amount);
}

function applyTally(tally, type, configuration, responseData, delta = 1) {
  const step = delta < 0 ? -1 : 1;
  const payload = responseData && typeof responseData === "object" ? responseData : {};
  const next = {
    submissions: Math.max(0, (tally.submissions || 0) + step),
    votes: { ...(tally.votes || {}) },
    scores: { ...(tally.scores || {}) },
    correctCounts: { ...(tally.correctCounts || {}) },
    verifiedCompletions: tally.verifiedCompletions || 0,
    selfReported: tally.selfReported || 0,
  };
  if (type === "quiz") {
    const answers = payload.answers && typeof payload.answers === "object"
      ? payload.answers
      : {};
    (configuration.questions || []).forEach((question) => {
      if (answers[question.id] === question.correctOptionId) {
        bumpMap(next.correctCounts, question.id, step);
      }
    });
    return next;
  }
  if (type === "ranking") {
    const ranked = Array.isArray(payload.rankedIds) ? payload.rankedIds : [];
    const n = ranked.length;
    ranked.forEach((id, index) => {
      bumpMap(next.scores, id, step * (n - index));
    });
    return next;
  }
  if (type === "challenge") {
    if (payload.verified === true) {
      next.verifiedCompletions = Math.max(0, next.verifiedCompletions + step);
    }
    if (payload.verification === "self_reported") {
      next.selfReported = Math.max(0, next.selfReported + step);
    }
    return next;
  }
  if (type === "theory" || type === "openDiscussion") {
    return next;
  }
  (payload.optionIds || []).forEach((id) => {
    bumpMap(next.votes, id, step);
  });
  return next;
}

function winnersFromMap(map) {
  let best = -1;
  const ids = [];
  Object.entries(map || {}).forEach(([id, value]) => {
    if (value > best) {
      best = value;
      ids.splice(0, ids.length, id);
    } else if (value === best && best > 0) {
      ids.push(id);
    }
  });
  return { ids, value: best < 0 ? 0 : best };
}

function calculateResult({ type, configuration, tally, responsesCount }) {
  const submissions = tally.submissions || responsesCount || 0;
  if (type === "quiz") {
    return {
      kind: type,
      submissions,
      correctCounts: tally.correctCounts || {},
    };
  }
  if (type === "ranking") {
    const win = winnersFromMap(tally.scores || {});
    return { kind: type, submissions, scores: tally.scores || {}, winnerIds: win.ids };
  }
  if (type === "challenge") {
    return {
      kind: type,
      challengeKind: configuration.challengeKind || "self_report",
      verification: configuration.verification || "server",
      submissions,
      verifiedCompletions: tally.verifiedCompletions || 0,
      selfReported: tally.selfReported || 0,
    };
  }
  if (type === "theory" || type === "openDiscussion") {
    return { kind: type, submissions };
  }
  const win = winnersFromMap(tally.votes || {});
  if (COMPARISON_TYPES.includes(type)) {
    const byId = {};
    (configuration.options || []).forEach((item) => {
      byId[item.id] = item;
    });
    return {
      kind: type,
      comparisonKind: configuration.comparisonType || type,
      criterion: configuration.criterion || configuration.question || "",
      submissions,
      votes: tally.votes || {},
      winnerIds: win.ids,
      winners: win.ids.map((id) => {
        const option = byId[id] || { id };
        return {
          id,
          label: option.label || id,
          characterId: option.characterId || null,
          animeId: option.animeId || null,
          imageUrl: option.imageUrl || null,
          license: option.license || null,
        };
      }),
    };
  }
  return { kind: type, submissions, votes: tally.votes || {}, winnerIds: win.ids };
}

function applyTemplate(input) {
  if (!input.templateId) return input;
  const template = TEMPLATES[input.templateId];
  if (!template) return input;
  return {
    ...input,
    type: input.type || template.type,
    title: input.title || template.title,
  };
}

function searchNameOf(title) {
  return title.trim().toLowerCase();
}

async function loadPermissions(transaction, db, groupId, uid) {
  if (!groupId) return { member: false, manageEvents: false, role: null };
  const [member, group] = await Promise.all([
    transaction.get(memberRef(db, groupId, uid)),
    transaction.get(groupRef(db, groupId)),
  ]);
  if (!group.exists) return { member: false, manageEvents: false, role: null, missingGroup: true };
  if (!member.exists) return { member: false, manageEvents: false, role: null };
  const data = member.data() || {};
  const role = data.role || "member";
  const customRoleId = validString(data.customRoleId, 128) ? data.customRoleId.trim() : null;
  const roleSnap = await transaction.get(roleRef(db, groupId, customRoleId || role));
  const permissions = roleSnap.exists && Array.isArray(roleSnap.data().permissions)
    ? roleSnap.data().permissions
    : (ROLE_PERMISSIONS[role] || []);
  return {
    member: true,
    manageEvents: role === "founder" || permissions.includes("manageEvents"),
    role,
  };
}

function displayNameOf(user, uid) {
  if (user && validString(user.username, 80)) return user.username.trim();
  if (user && validString(user.displayName, 80)) return user.displayName.trim();
  return uid;
}

async function postEventChatActivity(db, FieldValue, {
  groupId, eventId, kind, text,
}) {
  if (!validString(groupId, 128) || !validString(eventId, EVENT_ID_MAX)) return;
  const ref = groupRef(db, groupId).collection("messages").doc();
  await ref.set({
    senderId: "system",
    senderName: "Pubget",
    senderAvatar: "",
    senderRole: "system",
    type: "event",
    text: String(text || "").slice(0, 200),
    mediaId: eventId,
    mediaUrl: null,
    thumbnailUrl: null,
    replyToMessageId: null,
    createdAt: FieldValue.serverTimestamp(),
    editedAt: null,
    deletedAt: null,
    pinnedAt: null,
    reactions: {},
    reactionUsers: {},
    recipientCount: 0,
    deliveredCount: 0,
    readCount: 0,
    deliveredBy: {},
    readBy: {},
    eventActivity: kind,
  });
}

function notifySafe(builder, payload) {
  if (!builder || typeof builder.build !== "function") return Promise.resolve();
  return builder.build(payload).catch(() => {});
}

const RECIPIENT_CAP = 200;

async function listCollectionDocs(collectionRef, limit = RECIPIENT_CAP) {
  if (!collectionRef) return [];
  if (typeof collectionRef.limit === "function") {
    const snapshot = await collectionRef.limit(limit).get();
    return snapshot.docs;
  }
  const snapshot = await collectionRef.get();
  return snapshot.docs.slice(0, limit);
}

async function listGroupMemberIds(db, groupId) {
  if (!validString(groupId, 128)) return [];
  const docs = await listCollectionDocs(groupRef(db, groupId).collection("members"));
  return docs.map((doc) => doc.id).filter((id) => validString(id, 128));
}

async function listActiveParticipantIds(db, eventId) {
  if (!validString(eventId, EVENT_ID_MAX)) return [];
  const docs = await listCollectionDocs(
    eventRef(db, eventId).collection("participants"),
  );
  return docs
    .filter((doc) => !(doc.data() || {}).leftAt)
    .map((doc) => doc.id)
    .filter((id) => validString(id, 128));
}

function uniqueRecipientIds(ids) {
  return [...new Set((ids || []).filter((id) => validString(id, 128)))]
    .slice(0, RECIPIENT_CAP);
}

function achievementItemRef(db, uid, achievementId) {
  return db.collection("user_achievements").doc(uid)
    .collection("items").doc(achievementId);
}

async function verifyChallengeCompletion(transaction, db, uid, configuration, eventId, HttpsError) {
  const kind = configuration.challengeKind || "self_report";
  if (kind === "self_report") {
    return {
      verified: false,
      verification: "self_reported",
      challengeKind: kind,
    };
  }
  if (kind === "participate_event") {
    const target = configuration.targetEventId;
    if (!validString(target, EVENT_ID_MAX) || target === eventId) {
      throw new HttpsError("failed-precondition", "This challenge is not complete yet.");
    }
    const evidence = await transaction.get(responseRef(db, target, uid));
    if (!evidence.exists) {
      throw new HttpsError("failed-precondition", "This challenge is not complete yet.");
    }
    return {
      verified: true,
      verification: "server",
      challengeKind: kind,
      evidence: { eventId: target },
    };
  }
  const mapped = CHALLENGE_EVIDENCE[kind];
  if (!mapped) {
    throw new HttpsError("invalid-argument", "Unknown challenge kind.");
  }
  const evidence = await transaction.get(achievementItemRef(db, uid, mapped.achievementId));
  if (!evidence.exists) {
    throw new HttpsError("failed-precondition", "This challenge is not complete yet.");
  }
  return {
    verified: true,
    verification: "server",
    challengeKind: kind,
    evidence: { achievementId: mapped.achievementId },
  };
}

function createEventsDomain({
  db, FieldValue, HttpsError, notificationBuilder, economy, achievements,
}) {
  async function notifyEventLifecycle({ kind, eventId, groupId, creatorId, title }) {
    if (!validString(eventId, EVENT_ID_MAX)) return;
    const started = kind === "started";
    let recipientIds = started
      ? await listGroupMemberIds(db, groupId)
      : await listActiveParticipantIds(db, eventId);
    if (!started && recipientIds.length === 0) {
      recipientIds = await listGroupMemberIds(db, groupId);
    }
    if (creatorId) recipientIds.push(creatorId);
    recipientIds = uniqueRecipientIds(recipientIds);
    if (recipientIds.length === 0) return;
    await notifySafe(notificationBuilder, {
      id: started ? `event-start-${eventId}` : `event-end-${eventId}`,
      recipientIds,
      type: started ? "event_starting" : "event_ended",
      actorId: creatorId || null,
      targetId: eventId,
      action: started ? "started" : "ended",
      destination: `/event/${eventId}`,
      metadata: { groupId: groupId || "" },
      title: started ? "Event started" : "Event ended",
      body: title || (started ? "An event just started." : "Results are ready."),
      pushWorthy: started,
    });
  }

  async function saveEventDraft(request) {
    const uid = requireAuth(request, HttpsError);
    const input = applyTemplate(request.data || {});
    const type = EVENT_TYPES.includes(input.type) ? input.type : null;
    if (!type || !validString(input.title, TITLE_MAX)) {
      throw new HttpsError("invalid-argument", "A valid type and title are required.");
    }
    if (typeof input.description === "string" && input.description.length > DESCRIPTION_MAX) {
      throw new HttpsError("invalid-argument", "Description is too long.");
    }
    const configuration = validateConfiguration(type, input.configuration || input);
    if (!configuration) {
      throw new HttpsError("invalid-argument", "Event configuration is invalid.");
    }
    const groupId = input.groupId ? String(input.groupId).trim() : null;
    if (groupId && !validString(groupId, 128)) {
      throw new HttpsError("invalid-argument", "groupId is invalid.");
    }
    const existingId = validString(input.eventId, EVENT_ID_MAX) ? input.eventId.trim() : null;
    const ref = existingId ? eventRef(db, existingId) : db.collection("events").doc();
    await db.runTransaction(async (transaction) => {
      const access = await loadPermissions(transaction, db, groupId, uid);
      if (groupId && access.missingGroup) {
        throw new HttpsError("not-found", "Group not found.");
      }
      if (groupId && !access.manageEvents) {
        throw new HttpsError(
          "permission-denied",
          "You need the Manage Events permission to create events.",
        );
      }
      if (!groupId) {
        throw new HttpsError(
          "invalid-argument",
          "Events must belong to a group in this version.",
        );
      }
      const existing = await transaction.get(ref);
      if (existing.exists) {
        const current = existing.data() || {};
        if (current.creatorId !== uid) {
          throw new HttpsError("permission-denied", "You cannot edit this draft.");
        }
        if (current.status !== "draft") {
          throw new HttpsError("failed-precondition", "Only drafts can be edited this way.");
        }
        transaction.update(ref, {
          type,
          title: input.title.trim(),
          description: typeof input.description === "string" ? input.description.trim() : "",
          configuration,
          templateId: TEMPLATES[input.templateId] ? input.templateId : null,
          coverUrl: typeof input.coverUrl === "string" ? input.coverUrl.trim().slice(0, 1024) : "",
          searchName: searchNameOf(input.title),
          updatedAt: FieldValue.serverTimestamp(),
          version: 1,
        });
        return;
      }
      transaction.create(ref, {
        type,
        creatorId: uid,
        groupId,
        title: input.title.trim(),
        description: typeof input.description === "string" ? input.description.trim() : "",
        configuration,
        status: "draft",
        startAt: null,
        endAt: null,
        participantsCount: 0,
        responsesCount: 0,
        tally: emptyTally(configuration, type),
        result: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        publishedAt: null,
        cancelledAt: null,
        archivedAt: null,
        templateId: TEMPLATES[input.templateId] ? input.templateId : null,
        coverUrl: typeof input.coverUrl === "string" ? input.coverUrl.trim().slice(0, 1024) : "",
        searchName: searchNameOf(input.title),
        version: 1,
      });
    });
    return { ok: true, eventId: ref.id, status: "draft" };
  }

  async function publishEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const { start, end } = assertDuration(
      request.data.startAt, request.data.endAt, HttpsError,
    );
    const ref = eventRef(db, eventId.trim());
    let published;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (current.creatorId !== uid && !access.manageEvents) {
        throw new HttpsError("permission-denied", "You cannot publish this event.");
      }
      if (!access.manageEvents) {
        throw new HttpsError("permission-denied", "You need Manage Events to publish.");
      }
      if (current.status !== "draft" && current.status !== "scheduled") {
        if (current.status === "active" || current.status === "scheduled") {
          published = { status: current.status, eventId: ref.id };
          return;
        }
        throw new HttpsError("failed-precondition", "This event cannot be published.");
      }
      const now = Date.now();
      const nextStatus = start.getTime() <= now ? "active" : "scheduled";
      assertTransition(current.status === "scheduled" ? "scheduled" : "draft", nextStatus, HttpsError);
      transaction.update(ref, {
        status: nextStatus,
        startAt: start,
        endAt: end,
        publishedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      published = { status: nextStatus, eventId: ref.id, groupId: current.groupId, title: current.title };
    });
    if (published && published.status === "active") {
      await postEventChatActivity(db, FieldValue, {
        groupId: published.groupId,
        eventId: published.eventId,
        kind: "started",
        text: `Event started: ${published.title}`,
      });
      await notifyEventLifecycle({
        kind: "started",
        eventId: published.eventId,
        groupId: published.groupId,
        creatorId: uid,
        title: published.title,
      });
    } else if (published) {
      await postEventChatActivity(db, FieldValue, {
        groupId: published.groupId,
        eventId: published.eventId,
        kind: "created",
        text: `Event scheduled: ${published.title}`,
      });
    }
    return { ok: true, ...published };
  }

  async function cancelEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    let cancelled;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      if (current.status === "cancelled" || current.status === "archived") {
        cancelled = { eventId: ref.id, status: current.status };
        return;
      }
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (current.creatorId !== uid && !access.manageEvents) {
        throw new HttpsError("permission-denied", "You cannot cancel this event.");
      }
      assertTransition(current.status, "cancelled", HttpsError);
      transaction.update(ref, {
        status: "cancelled",
        cancelledAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      cancelled = { eventId: ref.id, status: "cancelled", groupId: current.groupId, title: current.title };
    });
    if (cancelled && cancelled.groupId && cancelled.status === "cancelled") {
      await postEventChatActivity(db, FieldValue, {
        groupId: cancelled.groupId,
        eventId: cancelled.eventId,
        kind: "cancelled",
        text: `Event cancelled: ${cancelled.title}`,
      });
    }
    return { ok: true, ...cancelled };
  }

  async function finalizeEvent(transaction, snapshot, { reason }) {
    const current = snapshot.data() || {};
    if (current.status === "ended" || current.status === "archived") {
      return current;
    }
    assertTransition(current.status, "ended", HttpsError);
    const result = calculateResult({
      type: current.type,
      configuration: current.configuration || {},
      tally: current.tally || {},
      responsesCount: current.responsesCount || 0,
    });
    transaction.update(snapshot.ref, {
      status: "ended",
      result,
      endedReason: reason || "completed",
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ...current, status: "ended", result };
  }

  async function endEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    let ended;
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.manageEvents && current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot end this event.");
      }
      ended = await finalizeEvent(transaction, snapshot, { reason: "manual" });
    });
    if (ended && ended.status === "ended") {
      await postEventChatActivity(db, FieldValue, {
        groupId: ended.groupId,
        eventId: ref.id,
        kind: "ended",
        text: `Event ended: ${ended.title}`,
      });
      await notifyEventLifecycle({
        kind: "ended",
        eventId: ref.id,
        groupId: ended.groupId,
        creatorId: ended.creatorId || uid,
        title: ended.title,
      });
      await grantEventRewards(ref.id, ended);
    }
    return { ok: true, eventId: ref.id, status: "ended", result: ended.result };
  }

  async function archiveEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      if (current.status === "archived") return;
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.manageEvents && current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot archive this event.");
      }
      assertTransition(current.status, "archived", HttpsError);
      transaction.update(ref, {
        status: "archived",
        archivedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true, eventId: ref.id, status: "archived" };
  }

  async function deleteEventDraft(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      const current = snapshot.data() || {};
      if (current.creatorId !== uid) {
        throw new HttpsError("permission-denied", "You cannot delete this draft.");
      }
      if (current.status !== "draft") {
        throw new HttpsError("failed-precondition", "Only drafts can be deleted.");
      }
      transaction.delete(ref);
    });
    return { ok: true };
  }

  async function joinEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    const person = participantRef(db, eventId.trim(), uid);
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing, user] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
        transaction.get(db.collection("users").doc(uid)),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to participate.");
      }
      if (current.status !== "active" && current.status !== "scheduled") {
        throw new HttpsError("failed-precondition", "This event is not open to join.");
      }
      if (existing.exists && !existing.data().leftAt) return;
      const userData = user.exists ? user.data() : {};
      transaction.set(person, {
        userId: uid,
        displayName: displayNameOf(userData, uid),
        joinedAt: FieldValue.serverTimestamp(),
        leftAt: null,
      });
      if (!existing.exists) {
        transaction.update(ref, {
          participantsCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        transaction.update(ref, {
          participantsCount: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { ok: true };
  }

  async function leaveEvent(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    const person = participantRef(db, eventId.trim(), uid);
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      if (current.status !== "active" && current.status !== "scheduled") {
        throw new HttpsError("failed-precondition", "You cannot leave this event now.");
      }
      if (!existing.exists || existing.data().leftAt) return;
      transaction.update(person, { leftAt: FieldValue.serverTimestamp() });
      transaction.update(ref, {
        participantsCount: FieldValue.increment(-1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function submitEventResponse(request) {
    const uid = requireAuth(request, HttpsError);
    const eventId = request.data && request.data.eventId;
    if (!validString(eventId, EVENT_ID_MAX)) {
      throw new HttpsError("invalid-argument", "eventId is required.");
    }
    const ref = eventRef(db, eventId.trim());
    const person = participantRef(db, eventId.trim(), uid);
    const answer = responseRef(db, eventId.trim(), uid);
    await db.runTransaction(async (transaction) => {
      const [snapshot, existing, prior, user] = await Promise.all([
        transaction.get(ref),
        transaction.get(person),
        transaction.get(answer),
        transaction.get(db.collection("users").doc(uid)),
      ]);
      if (!snapshot.exists) throw new HttpsError("not-found", "Event not found.");
      const current = snapshot.data() || {};
      const access = await loadPermissions(transaction, db, current.groupId, uid);
      if (!access.member) {
        throw new HttpsError("permission-denied", "Join the group to participate.");
      }
      if (current.status !== "active") {
        throw new HttpsError("failed-precondition", "This event is not accepting responses.");
      }
      const end = dateOf(current.endAt);
      if (end && end.getTime() <= Date.now()) {
        throw new HttpsError("failed-precondition", "This event has already ended.");
      }
      const configuration = current.configuration || {};
      let responseData = validateResponse(current.type, configuration, request.data && request.data.responseData);
      if (!responseData) {
        throw new HttpsError("invalid-argument", "The response does not match this event type.");
      }
      if (current.type === "challenge") {
        const verified = await verifyChallengeCompletion(
          transaction, db, uid, configuration, ref.id, HttpsError,
        );
        responseData = { ...responseData, ...verified };
      }
      if (prior.exists && configuration.allowUpdate !== true) {
        throw new HttpsError("already-exists", "You already submitted a response.");
      }
      const userData = user.exists ? user.data() : {};
      if (!existing.exists || existing.data().leftAt) {
        transaction.set(person, {
          userId: uid,
          displayName: displayNameOf(userData, uid),
          joinedAt: FieldValue.serverTimestamp(),
          leftAt: null,
        });
      }
      const payload = {
        eventId: ref.id,
        userId: uid,
        submittedAt: prior.exists ? prior.data().submittedAt : FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        responseData,
        metadata: { version: 1 },
      };
      let tally = current.tally || emptyTally(configuration, current.type);
      if (prior.exists) {
        tally = applyTally(
          tally,
          current.type,
          configuration,
          prior.data().responseData || {},
          -1,
        );
        tally = applyTally(
          tally,
          current.type,
          configuration,
          responseData,
          1,
        );
        transaction.update(answer, payload);
        transaction.update(ref, {
          tally,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      transaction.create(answer, payload);
      tally = applyTally(
        tally,
        current.type,
        configuration,
        responseData,
        1,
      );
      const joinedNow = !existing.exists || existing.data().leftAt;
      const eventUpdate = {
        tally,
        responsesCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (joinedNow) eventUpdate.participantsCount = FieldValue.increment(1);
      transaction.update(ref, eventUpdate);
    });
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "event_participated",
        userId: uid,
        source: "event",
        metadata: { eventId: eventId.trim() },
      });
    }
    return { ok: true };
  }

  async function processEventLifecycle() {
    const now = new Date();
    const activating = await db.collection("events")
      .where("status", "==", "scheduled")
      .where("startAt", "<=", now)
      .limit(25)
      .get();
    for (const doc of activating.docs) {
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(doc.ref);
        if (!snap.exists || snap.data().status !== "scheduled") return;
        transaction.update(doc.ref, {
          status: "active",
          updatedAt: FieldValue.serverTimestamp(),
        });
      });
      const data = doc.data() || {};
      await postEventChatActivity(db, FieldValue, {
        groupId: data.groupId,
        eventId: doc.id,
        kind: "started",
        text: `Event started: ${data.title || "Event"}`,
      });
      await notifyEventLifecycle({
        kind: "started",
        eventId: doc.id,
        groupId: data.groupId,
        creatorId: data.creatorId,
        title: data.title,
      });
    }

    const expiring = await db.collection("events")
      .where("status", "==", "active")
      .where("endAt", "<=", now)
      .limit(25)
      .get();
    for (const doc of expiring.docs) {
      let ended;
      await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(doc.ref);
        if (!snap.exists || snap.data().status !== "active") return;
        ended = await finalizeEvent(transaction, snap, { reason: "expired" });
      });
      if (ended && ended.status === "ended") {
        await postEventChatActivity(db, FieldValue, {
          groupId: ended.groupId,
          eventId: doc.id,
          kind: "ended",
          text: `Event ended: ${ended.title || "Event"}`,
        });
        await notifyEventLifecycle({
          kind: "ended",
          eventId: doc.id,
          groupId: ended.groupId,
          creatorId: ended.creatorId,
          title: ended.title,
        });
        await grantEventRewards(doc.id, ended);
      }
    }
    return { ok: true };
  }

  async function grantEventRewards(eventId, event) {
    if (!economy || typeof economy.grantDomainRewards !== "function") return;
    const winners = Array.isArray(event && event.result && event.result.winnerIds)
      ? event.result.winnerIds
      : [];
    if (winners.length === 0) return;
    await economy.grantDomainRewards(winners, {
      type: "earn_event",
      referenceId: eventId,
      source: "event",
      metadata: { eventType: event.type || "" },
    });
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "event_won",
        userIds: winners,
        source: "event",
        metadata: { eventId },
      });
    }
  }

  return {
    saveEventDraft,
    publishEvent,
    cancelEvent,
    endEvent,
    archiveEvent,
    deleteEventDraft,
    joinEvent,
    leaveEvent,
    submitEventResponse,
    processEventLifecycle,
  };
}

module.exports = {
  EVENT_TYPES,
  MAX_DURATION_MS,
  STATUSES,
  TEMPLATES,
  TRANSITIONS,
  applyTally,
  assertDuration,
  assertTransition,
  calculateResult,
  createEventsDomain,
  emptyTally,
  validateConfiguration,
  validateResponse,
  CHALLENGE_KINDS,
  COMPARISON_TYPES,
};
