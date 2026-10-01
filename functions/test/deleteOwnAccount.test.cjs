const assert = require("node:assert/strict");
const test = require("node:test");

const {deleteOwnAccount, notificationDeliveryCollection} = require("../lib/deleteOwnAccount.js");

function fakeDeps(initial) {
  const docs = new Map(Object.entries(initial));
  const calls = [];
  const ref = (path) => ({
    path,
    update: () => {},
    delete: () => {},
  });
  const db = {
    async getUser(uid) {
      return docs.get(`users/${uid}`);
    },
    async queryByField(collection, field, value) {
      return [...docs.entries()]
        .filter(([key, data]) => key.startsWith(`${collection}/`) && key.split("/").length === 2 && data[field] === value)
        .map(([key, data]) => ({ref: ref(key), data: () => data}));
    },
    async commit(operations) {
      calls.push("commit");
      for (const operation of operations) {
        if (operation.delete) docs.delete(operation.ref.path);
        else docs.set(operation.ref.path, {...docs.get(operation.ref.path), ...operation.update});
      }
    },
    async recursiveDeleteUser(uid) {
      calls.push("recursiveDelete");
      for (const key of [...docs.keys()]) {
        if (key === `users/${uid}` || key.startsWith(`users/${uid}/`)) docs.delete(key);
      }
    },
    async addActivityLog(entry) {
      calls.push("log");
      docs.set("activity_logs/1", entry);
    },
  };
  return {
    docs,
    calls,
    deps: {
      db,
      deleteAvatarFiles: async () => { calls.push("avatars"); },
      deleteAuthUser: async () => { calls.push("auth"); },
      now: () => new Date("2026-10-01T08:00:00.000Z"),
    },
  };
}

test("deleting the account removes notices, tokens and queued deliveries", async () => {
  const {docs, calls, deps} = fakeDeps({
    "users/u1": {email: "lucia@example.com", name: "Lucía"},
    "users/u1/notifications/n1": {type: "bono_status"},
    "users/u1/fcmTokens/t1": {token: "t1"},
    "appointments/a1": {userId: "u1", name: "Lucía", email: "lucia@example.com"},
    "bonos/b1": {userId: "u1", historial: [{descripcion: "Ajuste manual"}]},
    [`${notificationDeliveryCollection}/d1`]: {uid: "u1", status: "retrying"},
    [`${notificationDeliveryCollection}/d2`]: {uid: "u2", status: "retrying"},
  });

  assert.deepEqual(await deleteOwnAccount(deps, {uid: "u1"}), {ok: true});

  assert.equal([...docs.keys()].some((key) => key.startsWith("users/u1")), false);
  assert.equal(docs.has(`${notificationDeliveryCollection}/d1`), false);
  assert.equal(docs.has(`${notificationDeliveryCollection}/d2`), true);
  assert.equal(docs.get("appointments/a1").email, "");
  assert.equal(docs.get("appointments/a1").deletedUser, true);
  assert.equal(docs.get("bonos/b1").historial[0].descripcion, "Historial anonimizado por eliminación de cuenta");
  assert.equal(docs.get("activity_logs/1").email, "lucia@example.com");
  // The auth user goes last, after every Firestore cleanup step.
  assert.deepEqual(calls.slice(-4), ["avatars", "recursiveDelete", "log", "auth"]);
});

test("requires an authenticated caller", async () => {
  const {deps} = fakeDeps({});
  await assert.rejects(deleteOwnAccount(deps, undefined), /Authentication is required/);
});
