/**
 * Cloud Functions deployed from the mobile repository (codebase `portal`).
 *
 * Only `deleteOwnAccount` lives here. Appointments, bonos, notifications and
 * Firestore rules belong to web_focus_club (codebase `default`), which is the
 * single source of truth for the backend. The legacy mobile callables
 * (`createAppointment`, `requestAppointment`, `approveAppointment`,
 * `rejectAppointment`, `updateAppointmentSlot`, `assignBonoToUser`,
 * `expireOverdueBonos`) were never deployed from this codebase and were
 * removed so a deploy from here can never claim or replace the web versions.
 * `scripts/check-exports.cjs` enforces this list before every deploy.
 */
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {DocumentReference, getFirestore} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {onCall} from "firebase-functions/v2/https";

import {deleteOwnAccount as deleteOwnAccountFlow, type DeleteAccountDb} from "./deleteOwnAccount";

initializeApp();

const db = getFirestore();
const region = "europe-west1";

const accountDb: DeleteAccountDb = {
  async getUser(uid) {
    const snapshot = await db.collection("users").doc(uid).get();
    return snapshot.data();
  },
  async queryByField(collection, field, value) {
    const snapshot = await db.collection(collection).where(field, "==", value).get();
    return snapshot.docs;
  },
  async commit(operations) {
    const batch = db.batch();
    for (const operation of operations) {
      const ref = operation.ref as DocumentReference;
      if (operation.delete) {
        batch.delete(ref);
      } else if (operation.update) {
        batch.update(ref, operation.update);
      }
    }
    await batch.commit();
  },
  async recursiveDeleteUser(uid) {
    await db.recursiveDelete(db.collection("users").doc(uid));
  },
  async addActivityLog(entry) {
    await db.collection("activity_logs").add(entry);
  },
};

export const deleteOwnAccount = onCall({region}, (request) => deleteOwnAccountFlow({
  db: accountDb,
  deleteAvatarFiles: async (uid) => {
    await getStorage().bucket().deleteFiles({prefix: `user-avatars/${uid}/`});
  },
  deleteAuthUser: async (uid) => {
    await getAuth().deleteUser(uid);
  },
}, {uid: request.auth?.uid, email: request.auth?.token.email}));
