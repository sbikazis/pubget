"use strict";

const GROUP_TYPES = ["public", "animeRoleplay", "openRoleplay"];
const ROLEPLAY_GROUP_TYPES = new Set(["animeRoleplay", "openRoleplay"]);
const JOIN_POLICIES = ["open", "approval", "inviteOnly"];
const ROLES = ["founder", "shogun", "commander", "captain", "sensei", "senpai", "member"];
const ROLE_POSITIONS = Object.fromEntries(ROLES.map((role, index) => [role, ROLES.length - index]));
const ROLE_PERMISSIONS = {
  founder: ["manageMembers", "manageMessages", "deleteMessages", "pin",
    "manageEvents", "manageGames", "manageSettings", "invite",
    "manageRequests", "manageRoles", "manageBackground"],
  shogun: ["manageMembers", "manageMessages", "deleteMessages", "pin",
    "manageEvents", "manageGames", "manageSettings", "invite",
    "manageRequests", "manageRoles", "manageBackground"],
  commander: ["manageMembers", "manageMessages", "deleteMessages", "pin",
    "manageEvents", "manageGames", "invite", "manageRequests"],
  captain: ["manageMessages", "deleteMessages", "pin", "manageEvents", "invite"],
  sensei: ["manageMessages", "deleteMessages", "pin", "invite"],
  senpai: ["pin", "invite"],
  member: [],
};
const CHARACTER_CATALOG = {
  hero: "The Hero",
  rival: "The Rival",
  mentor: "The Mentor",
  trickster: "The Trickster",
};
const GROUP_PROMOTE_COST = 120;
const GROUP_PROMOTE_DAYS = 7;

function validString(value, max) {
  return typeof value === "string" && value.trim().length > 0 &&
    value.trim().length <= max;
}

function authUid(request, HttpsError) {
  if (!request || !request.auth || !validString(request.auth.uid, 128)) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return request.auth.uid;
}

function optionalUrl(value, max) {
  if (value === undefined || value === null || value === "") return true;
  if (typeof value !== "string" || value.length > max) return false;
  const trimmed = value.trim();
  return /^https?:\/\//i.test(trimmed) && !/\s/.test(trimmed);
}

function parseCharacter(raw, HttpsError) {
  if (raw === undefined || raw === null || raw === "") return null;
  if (!raw.character && raw.characterKey === undefined) return null;
  const source = raw.character && typeof raw.character === "object" ? raw.character : raw;
  const key = typeof raw.characterKey === "string" ? raw.characterKey : source.key;
  const name = source && source.name;
  const avatarUrl = source && source.avatarUrl;
  if (!validString(key, 128) || !validString(name, 80) ||
      (avatarUrl !== undefined && avatarUrl !== null &&
       (typeof avatarUrl !== "string" || avatarUrl.length > 500))) {
    throw new HttpsError("invalid-argument", "Character details are invalid.");
  }
  return {
    key: key.trim(),
    name: name.trim(),
    avatarUrl: typeof avatarUrl === "string" ? avatarUrl.trim() : "",
  };
}

function parseInvitedBy(value) {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 || trimmed.length > 80 ? null : trimmed;
}

function groupInput(request, HttpsError) {
  const data = request.data || {};
  if (!validString(data.name, 80) || typeof data.description !== "string" ||
      data.description.length > 500 || !GROUP_TYPES.includes(data.type) ||
      !JOIN_POLICIES.includes(data.joinPolicy) ||
      typeof data.isSearchable !== "boolean" || typeof data.rules !== "string" ||
      data.rules.length > 4000 ||
      (data.animeId !== null && data.animeId !== undefined &&
       !validString(data.animeId, 128)) ||
      !optionalUrl(data.imageUrl, 500) || !optionalUrl(data.coverUrl, 500)) {
    throw new HttpsError("invalid-argument", "Group details are invalid.");
  }
  if (data.type === "animeRoleplay" && !validString(data.animeId, 128)) {
    throw new HttpsError("invalid-argument", "Anime roleplay groups require an animeId.");
  }
  const character = parseCharacter(data, HttpsError);
  if (ROLEPLAY_GROUP_TYPES.has(data.type) && !character) {
    throw new HttpsError("invalid-argument", "Roleplay groups require a founder character.");
  }
  if (data.type === "public" && character) {
    throw new HttpsError("invalid-argument", "Public groups cannot reserve a character.");
  }
  return Object.assign({}, data, { character });
}

function groupPath(db, groupId) {
  return db.collection("groups").doc(groupId);
}

function memberPath(db, groupId, uid) {
  return groupPath(db, groupId).collection("members").doc(uid);
}

function rolePath(db, groupId, role) {
  return groupPath(db, groupId).collection("roles").doc(role);
}

function roleDefinition(role) {
  return {
    name: role,
    permissions: ROLE_PERMISSIONS[role],
    position: ROLE_POSITIONS[role],
    isDefault: true,
  };
}

function entitledMaxMembers(userData) {
  const custom = Number(userData && userData.customMaxMembersLimit) || 0;
  if (!Number.isFinite(custom) || custom <= 0) return 100;
  return Math.min(Math.max(Math.trunc(custom), 2), 500);
}

function inviteRankForCount(count) {
  if (count >= 50) return "captain";
  if (count >= 20) return "sensei";
  if (count >= 5) return "senpai";
  return "member";
}

function groupMemberData(uid, role, FieldValue, extras) {
  const extra = extras || {};
  return {
    uid,
    role,
    customRoleId: null,
    roleplayCharacter: extra.character || null,
    invitedBy: extra.invitedBy || null,
    joinedAt: FieldValue.serverTimestamp(),
    inviteCount: 0,
    lastActiveAt: FieldValue.serverTimestamp(),
  };
}

function permissionFor(member, role, permission) {
  return member && (member.role === "founder" ||
    (role && role.permissions && role.permissions.includes(permission)));
}

function createGroupsDomain({ db, FieldValue, HttpsError, randomUUID, achievements }) {
  function requireGroupId(request) {
    const groupId = request.data && request.data.groupId;
    if (!validString(groupId, 128)) {
      throw new HttpsError("invalid-argument", "groupId is invalid.");
    }
    return groupId.trim();
  }

  async function actorContext(transaction, groupId, uid) {
    const [group, member] = await Promise.all([
      transaction.get(groupPath(db, groupId)),
      transaction.get(memberPath(db, groupId, uid)),
    ]);
    if (!group.exists) throw new HttpsError("not-found", "Group not found.");
    if (!member.exists) {
      throw new HttpsError("permission-denied", "You are not a group member.");
    }
    return { group, member, data: member.data() || {} };
  }

  async function createGroup(request) {
    const uid = authUid(request, HttpsError);
    const data = groupInput(request, HttpsError);
    const idempotencyKey = typeof data.idempotencyKey === "string" &&
      validString(data.idempotencyKey, 80) ? data.idempotencyKey.trim() : null;
    const lockRef = idempotencyKey ?
      db.collection("users").doc(uid).collection("groupCreateKeys").doc(idempotencyKey) :
      null;
    let groupRef = db.collection("groups").doc();
    let reused = false;
    await db.runTransaction(async (transaction) => {
      if (lockRef) {
        const lock = await transaction.get(lockRef);
        if (lock.exists && validString((lock.data() || {}).groupId, 128)) {
          groupRef = db.collection("groups").doc(lock.data().groupId);
          reused = true;
          return;
        }
      }
      const userSnap = await transaction.get(db.collection("users").doc(uid));
      const maxMembers = entitledMaxMembers(userSnap.exists ? userSnap.data() : {});
      const memberRef = memberPath(db, groupRef.id, uid);
      transaction.create(groupRef, {
        name: data.name.trim(),
        searchName: data.name.trim().toLowerCase(),
        description: data.description.trim(),
        imageUrl: typeof data.imageUrl === "string" && optionalUrl(data.imageUrl, 500)
          ? data.imageUrl.trim() : "",
        coverUrl: typeof data.coverUrl === "string" && optionalUrl(data.coverUrl, 500)
          ? data.coverUrl.trim() : "",
        type: data.type,
        animeId: data.animeId || null,
        founderId: uid,
        membersCount: 1,
        maxMembers,
        joinPolicy: data.joinPolicy,
        isSearchable: data.isSearchable,
        createdAt: FieldValue.serverTimestamp(),
        chatBackgroundUrl: null,
        rules: data.rules.trim(),
        activityScore: 0,
        risingEligible: false,
      });
      transaction.create(
        memberRef,
        groupMemberData(uid, "founder", FieldValue, { character: data.character }),
      );
      if (data.character) {
        transaction.create(
          groupRef.collection("characters").doc(data.character.key),
          {
            reservedByUid: uid,
            reservedAt: FieldValue.serverTimestamp(),
            name: data.character.name,
            avatarUrl: data.character.avatarUrl,
          },
        );
      }
      for (const role of ROLES) {
        transaction.create(rolePath(db, groupRef.id, role), roleDefinition(role));
      }
      if (lockRef) {
        transaction.create(lockRef, {
          groupId: groupRef.id,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
    const created = await groupRef.get();
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "group_created",
        userId: uid,
        source: "group",
        metadata: { groupId: groupRef.id },
      });
    }
    return { ok: true, groupId: groupRef.id, group: created.data() };
  }

  async function joinGroup(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const inviteId = request.data && request.data.inviteId;
    await db.runTransaction(async (transaction) => {
      const groupRef = groupPath(db, groupId);
      const memberRef = memberPath(db, groupId, uid);
      const group = await transaction.get(groupRef);
      if (!group.exists) throw new HttpsError("not-found", "Group not found.");
      const [member, ban] = await Promise.all([
        transaction.get(memberRef),
        transaction.get(groupRef.collection("bans").doc(uid)),
      ]);
      const data = group.data() || {};
      if (ban.exists) throw new HttpsError("permission-denied", "You are banned from this group.");
      if (member.exists) return;
      if (data.joinPolicy === "approval") {
        throw new HttpsError("failed-precondition", "This group requires a join request.");
      }
      if (data.joinPolicy === "inviteOnly") {
        if (!validString(inviteId, 128)) {
          throw new HttpsError("permission-denied", "An invitation is required.");
        }
        const invite = await transaction.get(groupRef.collection("invites").doc(inviteId));
        const inviteData = invite.exists ? invite.data() : {};
        if (!invite.exists || inviteData.usedAt || inviteData.toUid !== uid ||
            !inviteData.expiresAt ||
            inviteData.expiresAt.toMillis() <= Date.now()) {
          throw new HttpsError("permission-denied", "This invitation is not valid.");
        }
      }
      if (data.joinPolicy !== "inviteOnly" && inviteId !== undefined) {
        throw new HttpsError(
          "invalid-argument",
          "Invitations can only be redeemed for invite-only groups.",
        );
      }
      if ((data.membersCount || 0) >= (data.maxMembers || 0)) {
        throw new HttpsError("resource-exhausted", "This group is full.");
      }
      const character = parseCharacter(request.data || {}, HttpsError);
      if (ROLEPLAY_GROUP_TYPES.has(data.type) && !character) {
        throw new HttpsError("invalid-argument", "A roleplay character is required.");
      }
      if (!ROLEPLAY_GROUP_TYPES.has(data.type) && character) {
        throw new HttpsError("invalid-argument", "This group does not use characters.");
      }
      let characterRef = null;
      if (character) {
        characterRef = groupRef.collection("characters").doc(character.key);
        const reserved = await transaction.get(characterRef);
        if (reserved.exists && reserved.data().reservedByUid !== uid) {
          throw new HttpsError("already-exists", "This character is already reserved.");
        }
      }
      transaction.create(
        memberRef,
        groupMemberData(uid, "member", FieldValue, {
          character,
          invitedBy: parseInvitedBy((request.data || {}).invitedBy),
        }),
      );
      if (characterRef && character) {
        transaction.set(characterRef, {
          reservedByUid: uid,
          reservedAt: FieldValue.serverTimestamp(),
          name: character.name,
          avatarUrl: character.avatarUrl,
        });
      }
      transaction.update(groupRef, {
        membersCount: (data.membersCount || 0) + 1,
      });
      if (inviteId) {
        transaction.update(groupRef.collection("invites").doc(inviteId), {
          usedAt: FieldValue.serverTimestamp(),
          usedByUid: uid,
        });
      }
    });
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "group_joined",
        userId: uid,
        source: "group",
        metadata: { groupId },
      });
    }
    return { ok: true };
  }

  async function createInvite(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const toUid = request.data && request.data.toUid;
    if (!validString(toUid, 128) || toUid === uid) {
      throw new HttpsError("invalid-argument", "A valid recipient is required.");
    }
    const inviteRef = groupPath(db, groupId).collection("invites").doc();
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const [role, target, ban] = await Promise.all([
        transaction.get(rolePath(db, groupId, context.data.role)),
        transaction.get(memberPath(db, groupId, toUid)),
        transaction.get(groupPath(db, groupId).collection("bans").doc(toUid)),
      ]);
      if (!permissionFor(context.data, role.data(), "invite") ||
          target.exists || ban.exists) {
        throw new HttpsError("permission-denied", "This invitation is not allowed.");
      }
      transaction.create(inviteRef, {
        invitedByUid: uid,
        toUid,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        usedAt: null,
        usedByUid: null,
        rankAppliedAt: null,
      });
    });
    return { ok: true, inviteId: inviteRef.id };
  }

  async function requestToJoin(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    await db.runTransaction(async (transaction) => {
      const groupRef = groupPath(db, groupId);
      const [group, member, ban, existing] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(memberPath(db, groupId, uid)),
        transaction.get(groupRef.collection("bans").doc(uid)),
        transaction.get(groupRef.collection("requests").doc(uid)),
      ]);
      if (!group.exists) throw new HttpsError("not-found", "Group not found.");
      if (ban.exists) throw new HttpsError("permission-denied", "You are banned from this group.");
      if (member.exists) return;
      if (group.data().joinPolicy !== "approval") {
        throw new HttpsError("failed-precondition", "This group accepts direct joins.");
      }
      if (existing.exists && existing.data().status === "pending") return;
      const groupData = group.data() || {};
      const character = parseCharacter(request.data || {}, HttpsError);
      if (ROLEPLAY_GROUP_TYPES.has(groupData.type) && !character) {
        throw new HttpsError("invalid-argument", "A roleplay character is required.");
      }
      if (!ROLEPLAY_GROUP_TYPES.has(groupData.type) && character) {
        throw new HttpsError("invalid-argument", "This group does not use characters.");
      }
      if (character) {
        const reserved = await transaction.get(
          groupRef.collection("characters").doc(character.key),
        );
        if (reserved.exists) {
          throw new HttpsError("already-exists", "This character is already reserved.");
        }
      }
      transaction.set(groupRef.collection("requests").doc(uid), {
        uid,
        status: "pending",
        requestedAt: FieldValue.serverTimestamp(),
        invitedBy: parseInvitedBy((request.data || {}).invitedBy),
        characterReason: typeof (request.data || {}).characterReason === "string" ?
          request.data.characterReason.trim().slice(0, 500) : "",
        roleplayCharacter: character,
      });
    });
    return { ok: true };
  }

  async function leaveGroup(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      if ((context.group.data() || {}).founderId === uid) {
        throw new HttpsError("failed-precondition", "Transfer ownership or disband before leaving.");
      }
      const data = context.group.data() || {};
      const characterKey = context.data.roleplayCharacter &&
        context.data.roleplayCharacter.key;
      const characterRef = characterKey ?
        groupPath(db, groupId).collection("characters").doc(characterKey) : null;
      if (characterRef) await transaction.get(characterRef);
      transaction.delete(memberPath(db, groupId, uid));
      if (characterRef) transaction.delete(characterRef);
      transaction.update(groupPath(db, groupId), {
        membersCount: Math.max(1, (data.membersCount || 1) - 1),
      });
    });
    return { ok: true };
  }

  async function requestContext(request, requirePermission) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const targetUid = request.data && request.data.uid;
    if (!validString(targetUid, 128)) {
      throw new HttpsError("invalid-argument", "uid is invalid.");
    }
    return { uid, groupId, targetUid, requirePermission };
  }

  async function acceptJoinRequest(request) {
    const { uid, groupId, targetUid } = await requestContext(request, "manageRequests");
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const role = await transaction.get(rolePath(db, groupId, context.data.role));
      if (!permissionFor(context.data, role.data(), "manageRequests")) {
        throw new HttpsError("permission-denied", "You cannot manage join requests.");
      }
      const groupRef = groupPath(db, groupId);
      const requestRef = groupRef.collection("requests").doc(targetUid);
      const memberRef = memberPath(db, groupId, targetUid);
      const [joinRequest, member, ban] = await Promise.all([
        transaction.get(requestRef),
        transaction.get(memberRef),
        transaction.get(groupRef.collection("bans").doc(targetUid)),
      ]);
      const data = context.group.data() || {};
      if (!joinRequest.exists || joinRequest.data().status !== "pending") {
        throw new HttpsError("not-found", "Join request not found.");
      }
      if (ban.exists) {
        throw new HttpsError("permission-denied", "This user is banned.");
      }
      if (member.exists) {
        transaction.delete(requestRef);
        return;
      }
      if ((data.membersCount || 0) >= (data.maxMembers || 0)) {
        throw new HttpsError("resource-exhausted", "This group is full.");
      }
      const requestData = joinRequest.data() || {};
      const character = requestData.roleplayCharacter && requestData.roleplayCharacter.key ?
        {
          key: requestData.roleplayCharacter.key,
          name: requestData.roleplayCharacter.name || "",
          avatarUrl: requestData.roleplayCharacter.avatarUrl || "",
        } : null;
      if (character) {
        const characterRef = groupRef.collection("characters").doc(character.key);
        const reserved = await transaction.get(characterRef);
        if (reserved.exists && reserved.data().reservedByUid !== targetUid) {
          throw new HttpsError("already-exists", "This character is already reserved.");
        }
        transaction.set(characterRef, {
          reservedByUid: targetUid,
          reservedAt: FieldValue.serverTimestamp(),
          name: character.name,
          avatarUrl: character.avatarUrl,
        });
      }
      transaction.create(
        memberRef,
        groupMemberData(targetUid, "member", FieldValue, {
          character,
          invitedBy: requestData.invitedBy || null,
        }),
      );
      transaction.update(groupRef, { membersCount: (data.membersCount || 0) + 1 });
      transaction.update(requestRef, {
        status: "accepted",
        decidedAt: FieldValue.serverTimestamp(),
      });
    });
    if (achievements && typeof achievements.evaluate === "function") {
      await achievements.evaluate({
        type: "group_joined",
        userId: targetUid,
        source: "group",
        metadata: { groupId, acceptedBy: uid },
      });
    }
    return { ok: true };
  }

  async function rejectJoinRequest(request) {
    const { uid, groupId, targetUid } = await requestContext(request, "manageRequests");
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const role = await transaction.get(rolePath(db, groupId, context.data.role));
      if (!permissionFor(context.data, role.data(), "manageRequests")) {
        throw new HttpsError("permission-denied", "You cannot manage join requests.");
      }
      transaction.delete(groupPath(db, groupId).collection("requests").doc(targetUid));
    });
    return { ok: true };
  }

  async function changeRole(request) {
    const { uid, groupId, targetUid } = await requestContext(request, "manageRoles");
    const roleName = request.data && request.data.role;
    if (!ROLES.includes(roleName) || roleName === "founder") {
      throw new HttpsError("invalid-argument", "This role cannot be assigned.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const [actorRole, target] = await Promise.all([
        transaction.get(rolePath(db, groupId, context.data.role)),
        transaction.get(memberPath(db, groupId, targetUid)),
      ]);
      if (!permissionFor(context.data, actorRole.data(), "manageRoles") ||
          !target.exists || target.data().role === "founder" ||
          targetUid === uid ||
          ROLE_POSITIONS[context.data.role] <= ROLE_POSITIONS[target.data().role] ||
          ROLE_POSITIONS[context.data.role] <= ROLE_POSITIONS[roleName]) {
        throw new HttpsError("permission-denied", "You cannot change this role.");
      }
      transaction.update(memberPath(db, groupId, targetUid), {
        role: roleName,
        isManualRole: true,
        lastActiveAt: FieldValue.serverTimestamp(),
      });
    });
    return { ok: true };
  }

  async function updateRolePermissions(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const roleName = request.data && request.data.role;
    const permissions = request.data && request.data.permissions;
    const allowedPermissions = new Set(Object.values(ROLE_PERMISSIONS).flat());
    if (!ROLES.includes(roleName) || roleName === "founder" ||
        !Array.isArray(permissions) ||
        permissions.some((permission) => !allowedPermissions.has(permission)) ||
        new Set(permissions).size !== permissions.length) {
      throw new HttpsError("invalid-argument", "Role permissions are invalid.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      if ((context.group.data() || {}).founderId !== uid) {
        throw new HttpsError("permission-denied", "Only the founder can edit roles.");
      }
      transaction.update(rolePath(db, groupId, roleName), { permissions });
    });
    return { ok: true };
  }

  async function removeMember(request, ban) {
    const { uid, groupId, targetUid } = await requestContext(request, "manageMembers");
    if (uid === targetUid) throw new HttpsError("invalid-argument", "You cannot target yourself.");
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const actorRole = await transaction.get(rolePath(db, groupId, context.data.role));
      const targetRef = memberPath(db, groupId, targetUid);
      const target = await transaction.get(targetRef);
      if (!permissionFor(context.data, actorRole.data(), "manageMembers") ||
          !target.exists || target.data().role === "founder" ||
          ROLE_POSITIONS[context.data.role] <= ROLE_POSITIONS[target.data().role]) {
        throw new HttpsError("permission-denied", "You cannot remove this member.");
      }
      const group = context.group.data() || {};
      const characterKey = target.data().roleplayCharacter &&
        target.data().roleplayCharacter.key;
      const characterRef = characterKey ?
        groupPath(db, groupId).collection("characters").doc(characterKey) : null;
      if (characterRef) await transaction.get(characterRef);
      transaction.delete(targetRef);
      if (characterRef) transaction.delete(characterRef);
      transaction.update(groupPath(db, groupId), {
        membersCount: Math.max(1, (group.membersCount || 1) - 1),
      });
      if (ban) {
        transaction.set(groupPath(db, groupId).collection("bans").doc(targetUid), {
          uid: targetUid,
          bannedByUid: uid,
          createdAt: FieldValue.serverTimestamp(),
        });
      }
    });
    return { ok: true };
  }

  async function transferOwnership(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const targetUid = request.data && request.data.uid;
    const confirmationToken = request.data && request.data.confirmationToken;
    if (!validString(targetUid, 128) || !validString(confirmationToken, 128) ||
        uid === targetUid) {
      throw new HttpsError("invalid-argument", "Double confirmation and a target are required.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const targetRef = memberPath(db, groupId, targetUid);
      const confirmationRef = groupPath(db, groupId)
        .collection("transferConfirmations").doc(uid);
      const [target, confirmation] = await Promise.all([
        transaction.get(targetRef),
        transaction.get(confirmationRef),
      ]);
      if ((context.group.data() || {}).founderId !== uid || !target.exists) {
        throw new HttpsError("permission-denied", "Only the founder can transfer ownership.");
      }
      const confirmationData = confirmation.exists ? confirmation.data() : {};
      if (!confirmation.exists || confirmationData.token !== confirmationToken ||
          confirmationData.targetUid !== targetUid ||
          !confirmationData.expiresAt ||
          confirmationData.expiresAt.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "Ownership confirmation expired.");
      }
      transaction.update(memberPath(db, groupId, uid), { role: "member" });
      transaction.update(targetRef, { role: "founder" });
      transaction.update(groupPath(db, groupId), { founderId: targetUid });
      transaction.delete(confirmationRef);
    });
    return { ok: true };
  }

  async function prepareOwnershipTransfer(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const targetUid = request.data && request.data.uid;
    if (!validString(targetUid, 128) || uid === targetUid) {
      throw new HttpsError("invalid-argument", "A valid new founder is required.");
    }
    const token = randomUUID();
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const target = await transaction.get(memberPath(db, groupId, targetUid));
      if ((context.group.data() || {}).founderId !== uid || !target.exists) {
        throw new HttpsError("permission-denied", "Only the founder can transfer ownership.");
      }
      transaction.set(
        groupPath(db, groupId).collection("transferConfirmations").doc(uid),
        {
          token,
          targetUid,
          expiresAt: new Date(Date.now() + 5 * 60 * 1000),
        },
      );
    });
    return { ok: true, confirmationToken: token };
  }

  async function updateGroupSettings(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const data = request.data || {};
    const updates = {};
    if (data.name !== undefined) {
      if (!validString(data.name, 80)) {
        throw new HttpsError("invalid-argument", "Group name is invalid.");
      }
      updates.name = data.name.trim();
      updates.searchName = data.name.trim().toLowerCase();
    }
    if (data.description !== undefined) {
      if (typeof data.description !== "string" || data.description.length > 500) {
        throw new HttpsError("invalid-argument", "Group description is invalid.");
      }
      updates.description = data.description.trim();
    }
    if (data.rules !== undefined) {
      if (typeof data.rules !== "string" || data.rules.length > 4000) {
        throw new HttpsError("invalid-argument", "Group rules are invalid.");
      }
      updates.rules = data.rules.trim();
    }
    if (data.joinPolicy !== undefined) {
      if (!JOIN_POLICIES.includes(data.joinPolicy)) {
        throw new HttpsError("invalid-argument", "joinPolicy is invalid.");
      }
      updates.joinPolicy = data.joinPolicy;
    }
    if (data.isSearchable !== undefined) {
      if (typeof data.isSearchable !== "boolean") {
        throw new HttpsError("invalid-argument", "isSearchable must be a boolean.");
      }
      updates.isSearchable = data.isSearchable;
    }
    if (Object.keys(updates).length === 0) {
      throw new HttpsError("invalid-argument", "No supported settings were provided.");
    }
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const role = await transaction.get(rolePath(db, groupId, context.data.role));
      if (!permissionFor(context.data, role.data(), "manageSettings")) {
        throw new HttpsError("permission-denied", "You cannot manage group settings.");
      }
      transaction.update(groupPath(db, groupId), updates);
    });
    return { ok: true };
  }

  async function unbanMember(request) {
    const { uid, groupId, targetUid } = await requestContext(request, "manageMembers");
    await db.runTransaction(async (transaction) => {
      const context = await actorContext(transaction, groupId, uid);
      const actorRole = await transaction.get(rolePath(db, groupId, context.data.role));
      const banRef = groupPath(db, groupId).collection("bans").doc(targetUid);
      const ban = await transaction.get(banRef);
      if (!permissionFor(context.data, actorRole.data(), "manageMembers")) {
        throw new HttpsError("permission-denied", "You cannot manage members.");
      }
      if (!ban.exists) return;
      transaction.delete(banRef);
    });
    return { ok: true };
  }

  async function reserveRoleplayCharacter(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const parsed = parseCharacter(request.data || {}, HttpsError);
    if (!parsed) {
      throw new HttpsError("invalid-argument", "Character details are invalid.");
    }
    const characterKey = parsed.key;
    const character = parsed;
    await db.runTransaction(async (transaction) => {
      const memberRef = memberPath(db, groupId, uid);
      const characterRef = groupPath(db, groupId).collection("characters").doc(characterKey);
      const [group, member, reserved] = await Promise.all([
        transaction.get(groupPath(db, groupId)),
        transaction.get(memberRef),
        transaction.get(characterRef),
      ]);
      if (!group.exists || !member.exists) {
        throw new HttpsError("permission-denied", "You must be a member to reserve a character.");
      }
      if (!ROLEPLAY_GROUP_TYPES.has((group.data() || {}).type)) {
        throw new HttpsError(
          "failed-precondition",
          "Characters can only be reserved in roleplay groups.",
        );
      }
      if (reserved.exists && reserved.data().reservedByUid !== uid) {
        throw new HttpsError("already-exists", "This character is already reserved.");
      }
      const previousKey = member.data().roleplayCharacter &&
        member.data().roleplayCharacter.key;
      const previousRef = previousKey && previousKey !== characterKey ?
        groupPath(db, groupId).collection("characters").doc(previousKey) : null;
      if (previousRef) await transaction.get(previousRef);
      if (previousRef) transaction.delete(previousRef);
      transaction.set(characterRef, {
        reservedByUid: uid,
        reservedAt: FieldValue.serverTimestamp(),
        name: character.name,
        avatarUrl: typeof character.avatarUrl === "string" ? character.avatarUrl : "",
      });
      transaction.update(memberRef, {
        roleplayCharacter: {
          key: characterKey,
          name: character.name,
          avatarUrl: typeof character.avatarUrl === "string" ? character.avatarUrl : "",
        },
      });
    });
    return { ok: true };
  }

  async function releaseRoleplayCharacter(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const characterKey = request.data && request.data.characterKey;
    if (!validString(characterKey, 128)) {
      throw new HttpsError("invalid-argument", "characterKey is invalid.");
    }
    await db.runTransaction(async (transaction) => {
      const characterRef = groupPath(db, groupId).collection("characters").doc(characterKey);
      const memberRef = memberPath(db, groupId, uid);
      const [character, member] = await Promise.all([
        transaction.get(characterRef),
        transaction.get(memberRef),
      ]);
      if (!member.exists || !character.exists || character.data().reservedByUid !== uid) return;
      transaction.delete(characterRef);
      transaction.update(memberRef, { roleplayCharacter: null });
    });
    return { ok: true };
  }

  async function recalculateInviteRanks(event) {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const invite = event.data && event.data.after ? event.data.after.data() : null;
    if (!invite || !before || !event.params ||
        before.usedAt || !invite.usedAt || !invite.usedByUid ||
        invite.rankAppliedAt || invite.usedByUid !== invite.toUid ||
        !validString(invite.invitedByUid, 128)) return null;
    const groupId = event.params.groupId;
    const uid = invite.invitedByUid;
    await db.runTransaction(async (transaction) => {
      const memberRef = memberPath(db, groupId, uid);
      const inviteRef = groupPath(db, groupId).collection("invites")
        .doc(event.params.inviteId);
      const [member, currentInvite] = await Promise.all([
        transaction.get(memberRef),
        transaction.get(inviteRef),
      ]);
      if (!member.exists || !currentInvite.exists ||
          currentInvite.data().rankAppliedAt || !currentInvite.data().usedAt) return;
      const count = (member.data().inviteCount || 0) + 1;
      const nextRole = inviteRankForCount(count);
      const updates = { inviteCount: count };
      if (member.data().isManualRole !== true) updates.role = nextRole;
      transaction.update(memberRef, updates);
      transaction.update(inviteRef, {
        rankAppliedAt: FieldValue.serverTimestamp(),
      });
    });
    return null;
  }

  async function promoteGroup(request) {
    const uid = authUid(request, HttpsError);
    const groupId = requireGroupId(request);
    const nowMs = Date.now();
    const durationMs = GROUP_PROMOTE_DAYS * 24 * 60 * 60 * 1000;
    const result = await db.runTransaction(async (transaction) => {
      const groupRef = groupPath(db, groupId);
      const userRef = db.collection("users").doc(uid);
      const [groupSnap, userSnap] = await Promise.all([
        transaction.get(groupRef),
        transaction.get(userRef),
      ]);
      if (!groupSnap.exists) {
        throw new HttpsError("not-found", "Group not found.");
      }
      const group = groupSnap.data() || {};
      const founderId = group.founderId || group.createdBy;
      if (founderId !== uid) {
        throw new HttpsError(
          "permission-denied",
          "Only the founder can promote this group.",
        );
      }
      if (!userSnap.exists) {
        throw new HttpsError("not-found", "User not found.");
      }
      const user = userSnap.data() || {};
      const coins = Number(user.coinsBalance || 0);
      if (!Number.isFinite(coins) || coins < GROUP_PROMOTE_COST) {
        throw new HttpsError(
          "failed-precondition",
          "You do not have enough coins.",
        );
      }
      const currentExpiry = group.promotionExpiresAt &&
        typeof group.promotionExpiresAt.toMillis === "function"
        ? group.promotionExpiresAt.toMillis()
        : (group.promotionExpiresAt instanceof Date
          ? group.promotionExpiresAt.getTime()
          : (typeof group.promotionExpiresAt === "number"
            ? group.promotionExpiresAt
            : 0));
      const base = Math.max(nowMs, currentExpiry || 0);
      const expiresAt = new Date(base + durationMs);
      transaction.update(userRef, {
        coinsBalance: coins - GROUP_PROMOTE_COST,
        economyUpdatedAt: FieldValue.serverTimestamp(),
      });
      transaction.update(groupRef, {
        isPromoted: true,
        promotionExpiresAt: expiresAt,
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(groupRef.collection("promotions").doc(), {
        founderId: uid,
        cost: GROUP_PROMOTE_COST,
        days: GROUP_PROMOTE_DAYS,
        createdAt: FieldValue.serverTimestamp(),
        expiresAt,
      });
      return { expiresAt: expiresAt.toISOString() };
    });
    return {
      ok: true,
      cost: GROUP_PROMOTE_COST,
      days: GROUP_PROMOTE_DAYS,
      promotionExpiresAt: result.expiresAt,
    };
  }

  return {
    acceptJoinRequest,
    banMember: (request) => removeMember(request, true),
    changeRole,
    createInvite,
    createGroup,
    joinGroup,
    kickMember: (request) => removeMember(request, false),
    leaveGroup,
    prepareOwnershipTransfer,
    recalculateInviteRanks,
    rejectJoinRequest,
    releaseRoleplayCharacter,
    requestToJoin,
    reserveRoleplayCharacter,
    transferOwnership,
    unbanMember,
    updateGroupSettings,
    updateRolePermissions,
    promoteGroup,
  };
}

module.exports = {
  GROUP_TYPES,
  JOIN_POLICIES,
  ROLE_PERMISSIONS,
  ROLES,
  GROUP_PROMOTE_COST,
  GROUP_PROMOTE_DAYS,
  createGroupsDomain,
  entitledMaxMembers,
  inviteRankForCount,
};