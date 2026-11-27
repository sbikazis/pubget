import { describe, expect, test, vi } from "vitest";
import { CallableError, CALLABLE_ROUTES, createCallableHandler } from "./callables";

const ORIGIN = "https://pubget-media.pubget.workers.dev";
const env = {
  FIREBASE_PROJECT_ID: "pubget-test",
  FIRESTORE_SERVICE_ACCOUNT_EMAIL: "",
  FIRESTORE_SERVICE_ACCOUNT_PRIVATE_KEY: "",
};

function request(path: string, body?: unknown, token = "id-token"): Request {
  return new Request(`${ORIGIN}${path}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

describe("authenticated callable bridge", () => {
  test("routes a chat write to the correct domain method with the verified uid", async () => {
    const sendMessage = vi.fn(async () => ({ messageId: "m1", ok: true }));
    const handler = createCallableHandler({
      verifyToken: async () => ({ uid: "alice", claims: { moderator: true } }),
      createDb: async () => ({}),
      createDomains: () => ({ groupChat: { sendMessage } }),
    });

    const response = await handler(
      request("/callables/sendGroupMessage", { groupId: "g1", messageId: "m1" }),
      env,
    );

    expect(response?.status).toBe(200);
    expect(await response?.json()).toEqual({ messageId: "m1", ok: true });
    expect(sendMessage).toHaveBeenCalledWith({
      auth: { uid: "alice", token: { moderator: true } },
      data: { groupId: "g1", messageId: "m1" },
    });
  });

  test("maps domain errors to honest HTTP statuses", async () => {
    const handler = createCallableHandler({
      verifyToken: async () => ({ uid: "alice" }),
      createDb: async () => ({}),
      createDomains: () => ({
        social: {
          giveRespect: async () => {
            throw new CallableError("permission-denied", "Blocked relationship.");
          },
        },
      }),
    });

    const response = await handler(
      request("/callables/giveRespect", { toUserId: "bob", value: 1 }),
      env,
    );

    expect(response?.status).toBe(403);
    expect(await response?.json()).toMatchObject({
      code: "permission-denied",
      error: "Blocked relationship.",
    });
  });

  test("rejects unknown routes and anonymous callers", async () => {
    const handler = createCallableHandler({
      verifyToken: async () => ({ uid: "alice" }),
      createDb: async () => ({}),
      createDomains: () => ({}),
    });

    expect((await handler(request("/callables/notARealCallable", {}), env))?.status)
      .toBe(404);
    expect((await handler(request("/callables/giveRespect", {}, ""), env))?.status)
      .toBe(401);
  });

  test("registers every chat and social callable used by the Flutter client", () => {
    for (const name of [
      "sendGroupMessage", "editGroupMessage", "deleteGroupMessage",
      "pinGroupMessage", "addGroupMessageReaction", "markGroupMessagesRead",
      "markGroupMessagesDelivered", "updateGroupChatBackground",
      "forwardGroupMessage", "reportGroupMessage",
      "startPrivateChat", "sendPrivateMessage", "deletePrivateMessage",
      "editPrivateMessage", "pinPrivateMessage", "addPrivateMessageReaction",
      "reportPrivateMessage", "markPrivateMessagesRead",
      "markPrivateMessagesDelivered", "deletePrivateChat",
      "giveRespect", "sendFriendRequest", "cancelFriendRequest",
      "respondToFriendRequest", "removeFriend", "blockUser", "unblockUser",
      "joinGroup", "requestToJoin", "leaveGroup", "updateGroupSettings",
      "promoteGroup", "createGroupInvite", "updateRolePermissions",
      "changeRole", "kickMember", "banMember", "transferOwnership",
      "acceptJoinRequest", "rejectJoinRequest", "unbanMember", "warnMember",
      "prepareOwnershipTransfer", "reserveRoleplayCharacter",
      "releaseRoleplayCharacter", "browseAnimeCatalog",
      "browseRoleplayCharacters", "reservedGroupCharacters",
    ]) {
      expect(CALLABLE_ROUTES[name]).toBeTruthy();
    }
    // Disband needs Storage prefix deletion and stays on the legacy path.
    expect(CALLABLE_ROUTES.disbandGroup).toBeUndefined();
  });
});
