import {HttpsError} from "firebase-functions/v2/https";

/**
 * `deleteOwnAccount`: the only Cloud Function deployed from this repository
 * (codebase `portal`, Node 22). Every other backend function lives in
 * web_focus_club (codebase `default`).
 *
 * Dependencies are injected so the flow can be tested without Firebase.
 */

export const deletedUserName = "Usuario eliminado";
export const deletedHistoryDescription = "Historial anonimizado por eliminación de cuenta";
/** Ledger of queued customer notices written by web_focus_club. */
export const notificationDeliveryCollection = "notification_deliveries";
const batchLimit = 450;

type Data = Record<string, unknown>;

export interface DocRef {
  update(data: Data): unknown;
  delete(): unknown;
}

export interface DocSnap {
  ref: DocRef;
  data(): Data | undefined;
}

export interface DeleteAccountDb {
  getUser(uid: string): Promise<Data | undefined>;
  queryByField(collection: string, field: string, value: string): Promise<DocSnap[]>;
  /** Commits updates/deletes in one batch (at most `batchLimit` operations). */
  commit(operations: Array<{ref: DocRef; update?: Data; delete?: true}>): Promise<void>;
  recursiveDeleteUser(uid: string): Promise<void>;
  addActivityLog(entry: Data): Promise<void>;
}

export interface DeleteAccountDeps {
  db: DeleteAccountDb;
  deleteAvatarFiles(uid: string): Promise<void>;
  deleteAuthUser(uid: string): Promise<void>;
  now?: () => Date;
}

function stringOrEmpty(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function anonymizeHistoryEntry(entry: unknown): unknown {
  if (!entry || typeof entry !== "object" || Array.isArray(entry)) {
    return entry;
  }
  const record = entry as Record<string, unknown>;
  if (typeof record.descripcion !== "string") {
    return record;
  }
  return {
    ...record,
    descripcion: deletedHistoryDescription,
  };
}

async function commitInBatches(
  db: DeleteAccountDb,
  operations: Array<{ref: DocRef; update?: Data; delete?: true}>,
): Promise<void> {
  for (let index = 0; index < operations.length; index += batchLimit) {
    await db.commit(operations.slice(index, index + batchLimit));
  }
}

export async function deleteOwnAccount(
  deps: DeleteAccountDeps,
  auth: {uid?: string; email?: string} | undefined,
): Promise<{ok: true}> {
  const uid = auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  const {db} = deps;
  const userData = await db.getUser(uid);
  const email = stringOrEmpty(userData?.email) || stringOrEmpty(auth?.email);
  const name = stringOrEmpty(userData?.name);
  const nowIso = (deps.now ?? (() => new Date()))().toISOString();

  const appointments = await db.queryByField("appointments", "userId", uid);
  await commitInBatches(db, appointments.map((doc) => ({
    ref: doc.ref,
    update: {
      name: deletedUserName,
      email: "",
      phone: "",
      reason: "",
      deletedUser: true,
      deletedUserUid: uid,
      updatedAt: nowIso,
    },
  })));

  const bonos = await db.queryByField("bonos", "userId", uid);
  await commitInBatches(db, bonos.map((doc) => {
    const bono = doc.data() ?? {};
    const update: Data = {
      name: deletedUserName,
      email: "",
      phone: "",
      deletedUser: true,
      deletedUserUid: uid,
      updatedAt: nowIso,
    };
    if (Array.isArray(bono.historial)) {
      update.historial = bono.historial.map(anonymizeHistoryEntry);
    }
    return {ref: doc.ref, update};
  }));

  // Queued notices hold the customer's email and would otherwise keep
  // retrying for a deleted account.
  const deliveries = await db.queryByField(notificationDeliveryCollection, "uid", uid);
  await commitInBatches(db, deliveries.map((doc) => ({ref: doc.ref, delete: true as const})));

  await deps.deleteAvatarFiles(uid);
  // Removes users/{uid} with `notifications` and `fcmTokens`.
  await db.recursiveDeleteUser(uid);
  await db.addActivityLog({
    action: "user_deleted_own_account",
    uid,
    email,
    name,
    createdAt: nowIso,
  });
  await deps.deleteAuthUser(uid);

  return {ok: true};
}
