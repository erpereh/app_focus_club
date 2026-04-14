import {initializeApp} from "firebase-admin/app";
import {
  DocumentReference,
  FieldValue,
  getFirestore,
  Timestamp,
  Transaction,
} from "firebase-admin/firestore";
import {defineSecret} from "firebase-functions/params";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

initializeApp();

const db = getFirestore();
const makeReservationWebhookUrl = defineSecret("MAKE_RESERVATION_WEBHOOK_URL");

const region = "europe-west1";
const internalSlotMinutes = 15;
const maxCapacityPerInternalSlot = 2;
const serviceType = "Bono Mensual de Entrenamiento";
const allowedDurations = new Set([30, 45, 60]);

type AppointmentStatus = "pending" | "approved" | "rejected";
type ReservationNotificationEvent =
  | "Reserva confirmada"
  | "Reserva eliminada";

interface TimeSlot {
  date: string;
  time: string;
}

interface UserProfile {
  uid: string;
  email: string;
  name: string;
  phone?: string;
  role?: string;
}

interface Bono {
  userId: string;
  tamano: number;
  minutosTotales: number;
  minutosRestantes: number;
  fechaAsignacion: string;
  fechaExpiracion: string;
  estado: string;
  historial?: Record<string, unknown>[];
  asignadoPor?: string;
  createdAt?: string;
}

interface Appointment {
  userId: string;
  name: string;
  email: string;
  phone: string;
  serviceType: string;
  duration: string;
  preferredSlots: TimeSlot[];
  reason: string;
  status: AppointmentStatus;
  approvedSlot?: TimeSlot;
  assignedTrainer?: string;
  sessionType?: string;
  createdAt: string;
  updatedAt?: string;
}

interface RequestAppointmentPayload {
  duration: string | number;
  preferredSlot: TimeSlot;
  reason?: string;
}

interface ApproveAppointmentPayload {
  appointmentId: string;
  approvedSlot: TimeSlot;
  assignedTrainer?: string;
  sessionType?: string;
}

interface RejectAppointmentPayload {
  appointmentId: string;
}

interface UpdateAppointmentSlotPayload {
  appointmentId: string;
  approvedSlot: TimeSlot;
}

interface AssignBonoToUserPayload {
  userId: string;
  tamano: number;
  mesesValidez?: number;
}

export const requestAppointment = onCall(
  {region},
  async (request) => {
    const uid = requireAuthUid(request.auth?.uid);
    const payload = parseRequestAppointmentPayload(request.data);
    const duration = parseDuration(payload.duration);
    const nowIso = new Date().toISOString();

    await db.runTransaction(async (transaction) => {
      const user = await getUserProfile(transaction, uid);
      if (!user.phone) {
        throw new HttpsError("failed-precondition", "Profile phone is required.");
      }
      requireFutureSlot(payload.preferredSlot);

      const activeBono = await getUniqueActiveBono(transaction, uid);
      if (!activeBono) {
        throw new HttpsError("failed-precondition", "No active bono found.");
      }
      if (activeBono.data.minutosRestantes < duration) {
        throw new HttpsError("failed-precondition", "Not enough bono minutes.");
      }

      await assertSlotAvailability({
        transaction,
        slot: payload.preferredSlot,
        duration,
        userId: uid,
      });

      const appointmentRef = db.collection("appointments").doc();
      transaction.set(appointmentRef, {
        userId: uid,
        name: user.name,
        email: user.email,
        phone: user.phone,
        serviceType,
        duration: String(duration),
        preferredSlots: [payload.preferredSlot],
        reason: payload.reason ?? "",
        status: "pending",
        createdAt: nowIso,
        updatedAt: nowIso,
      } satisfies Appointment);
    });

    return {ok: true};
  },
);

export const approveAppointment = onCall(
  {region, secrets: [makeReservationWebhookUrl]},
  async (request) => {
    await requireAdmin(request.auth?.uid);
    const payload = parseApprovePayload(request.data);
    const nowIso = new Date().toISOString();
    const notification = await db.runTransaction(async (transaction) => {
      const appointmentRef = db.collection("appointments").doc(payload.appointmentId);
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }
      const appointment = snapshot.data() as Appointment;
      if (appointment.status !== "pending") {
        throw new HttpsError("failed-precondition", "Only pending appointments can be approved.");
      }

      const duration = parseDuration(appointment.duration);
      await assertSlotAvailability({
        transaction,
        slot: payload.approvedSlot,
        duration,
        userId: appointment.userId,
        ignoreAppointmentId: payload.appointmentId,
      });
      const activeBono = await getUniqueActiveBono(transaction, appointment.userId);
      if (!activeBono || activeBono.data.minutosRestantes < duration) {
        throw new HttpsError("failed-precondition", "Bono minutes are not available.");
      }

      transaction.update(appointmentRef, {
        status: "approved",
        approvedSlot: payload.approvedSlot,
        assignedTrainer: payload.assignedTrainer ?? FieldValue.delete(),
        sessionType: payload.sessionType ?? FieldValue.delete(),
        updatedAt: nowIso,
      });
      transaction.update(activeBono.ref, {
        minutosRestantes: activeBono.data.minutosRestantes - duration,
        estado: activeBono.data.minutosRestantes - duration <= 0 ? "agotado" : "activo",
        historial: FieldValue.arrayUnion({
          tipo: "descuento",
          minutos: duration,
          appointmentId: payload.appointmentId,
          fecha: nowIso,
        }),
      });
      writeOccupancyDelta(transaction, payload.approvedSlot, duration, 1);

      return makeNotificationPayload("Reserva confirmada", {
        ...appointment,
        status: "approved",
        approvedSlot: payload.approvedSlot,
        assignedTrainer: payload.assignedTrainer,
        sessionType: payload.sessionType,
        updatedAt: nowIso,
      });
    });

    await notifyMakeIfEnabled(notification);
    return {ok: true};
  },
);

export const rejectAppointment = onCall(
  {region},
  async (request) => {
    await requireAdmin(request.auth?.uid);
    const payload = parseRejectPayload(request.data);
    const nowIso = new Date().toISOString();

    await db.runTransaction(async (transaction) => {
      const appointmentRef = db.collection("appointments").doc(payload.appointmentId);
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }
      const appointment = snapshot.data() as Appointment;
      const duration = parseDuration(appointment.duration);

      transaction.update(appointmentRef, {
        status: "rejected",
        updatedAt: nowIso,
      });

      if (appointment.status === "approved" && appointment.approvedSlot) {
        const activeBono = await getUniqueActiveBono(transaction, appointment.userId);
        if (activeBono) {
          transaction.update(activeBono.ref, {
            minutosRestantes: activeBono.data.minutosRestantes + duration,
            estado: "activo",
            historial: FieldValue.arrayUnion({
              tipo: "devolucion",
              minutos: duration,
              appointmentId: payload.appointmentId,
              fecha: nowIso,
            }),
          });
        }
        writeOccupancyDelta(transaction, appointment.approvedSlot, duration, -1);
      }
    });

    return {ok: true};
  },
);

export const updateAppointmentSlot = onCall(
  {region},
  async (request) => {
    await requireAdmin(request.auth?.uid);
    const payload = parseUpdateSlotPayload(request.data);
    const nowIso = new Date().toISOString();

    await db.runTransaction(async (transaction) => {
      const appointmentRef = db.collection("appointments").doc(payload.appointmentId);
      const snapshot = await transaction.get(appointmentRef);
      if (!snapshot.exists) {
        throw new HttpsError("not-found", "Appointment not found.");
      }
      const appointment = snapshot.data() as Appointment;
      if (appointment.status !== "approved" || !appointment.approvedSlot) {
        throw new HttpsError("failed-precondition", "Only approved appointments can move approved slots.");
      }

      const duration = parseDuration(appointment.duration);
      await assertSlotAvailability({
        transaction,
        slot: payload.approvedSlot,
        duration,
        userId: appointment.userId,
        ignoreAppointmentId: payload.appointmentId,
      });

      writeOccupancyDelta(transaction, appointment.approvedSlot, duration, -1);
      writeOccupancyDelta(transaction, payload.approvedSlot, duration, 1);
      transaction.update(appointmentRef, {
        approvedSlot: payload.approvedSlot,
        updatedAt: nowIso,
      });
    });

    return {ok: true};
  },
);

export const assignBonoToUser = onCall(
  {region},
  async (request) => {
    const admin = await requireAdmin(request.auth?.uid);
    const payload = parseAssignBonoPayload(request.data);
    const now = new Date();
    const expiration = new Date(now);
    expiration.setMonth(now.getMonth() + (payload.mesesValidez ?? 1));

    await db.runTransaction(async (transaction) => {
      const userRef = db.collection("users").doc(payload.userId);
      const userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw new HttpsError("not-found", "User not found.");
      }

      const activeQuery = db.collection("bonos")
        .where("userId", "==", payload.userId)
        .where("estado", "==", "activo");
      const activeSnapshot = await transaction.get(activeQuery);
      activeSnapshot.docs.forEach((doc) => {
        transaction.update(doc.ref, {estado: "eliminado"});
      });
      transaction.set(db.collection("bonos").doc(), {
        userId: payload.userId,
        tamano: payload.tamano,
        minutosTotales: payload.tamano,
        minutosRestantes: payload.tamano,
        fechaAsignacion: now.toISOString(),
        fechaExpiracion: expiration.toISOString(),
        estado: "activo",
        historial: [],
        asignadoPor: admin.email,
        createdAt: now.toISOString(),
      } satisfies Bono);
    });

    return {ok: true};
  },
);

export const expireOverdueBonos = onSchedule(
  {region, schedule: "every 24 hours"},
  async () => {
    const nowIso = new Date().toISOString();
    const snapshot = await db.collection("bonos")
      .where("estado", "==", "activo")
      .where("fechaExpiracion", "<", nowIso)
      .get();

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.update(doc.ref, {estado: "expirado"}));
    await batch.commit();
  },
);

async function requireAdmin(uid?: string): Promise<UserProfile> {
  const adminUid = requireAuthUid(uid);
  const admin = await getUserProfileDirect(adminUid);
  if (admin.role !== "admin") {
    throw new HttpsError("permission-denied", "Admin role is required.");
  }
  return admin;
}

function requireAuthUid(uid?: string): string {
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

async function getUserProfileDirect(uid: string): Promise<UserProfile> {
  const snapshot = await db.collection("users").doc(uid).get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  return snapshot.data() as UserProfile;
}

async function getUserProfile(
  transaction: Transaction,
  uid: string,
): Promise<UserProfile> {
  const snapshot = await transaction.get(db.collection("users").doc(uid));
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }
  return snapshot.data() as UserProfile;
}

async function getUniqueActiveBono(
  transaction: Transaction,
  userId: string,
): Promise<{ref: DocumentReference; data: Bono} | null> {
  const snapshot = await transaction.get(
    db.collection("bonos")
      .where("userId", "==", userId)
      .where("estado", "==", "activo")
      .limit(2),
  );
  if (snapshot.size > 1) {
    throw new HttpsError("failed-precondition", "More than one active bono found.");
  }
  const doc = snapshot.docs[0];
  return doc ? {ref: doc.ref, data: doc.data() as Bono} : null;
}

async function assertSlotAvailability(params: {
  transaction: Transaction;
  slot: TimeSlot;
  duration: number;
  userId: string;
  ignoreAppointmentId?: string;
}): Promise<void> {
  requireFutureSlot(params.slot);
  const internalSlots = expandInternalSlots(params.slot, params.duration);

  for (const slot of internalSlots) {
    const blockedSnapshot = await params.transaction.get(
      db.collection("blocked_slots")
        .where("date", "==", slot.date)
        .where("time", "==", slot.time)
        .limit(1),
    );
    if (!blockedSnapshot.empty) {
      throw new HttpsError("failed-precondition", "Slot is blocked.");
    }

    const occupancyRef = db.collection("slot_occupancy").doc(slotKey(slot));
    const occupancy = await params.transaction.get(occupancyRef);
    const count = (occupancy.data()?.count as number | undefined) ?? 0;
    if (count >= maxCapacityPerInternalSlot) {
      throw new HttpsError("failed-precondition", "Slot is full.");
    }
  }

  const userAppointments = await params.transaction.get(
    db.collection("appointments")
      .where("userId", "==", params.userId)
      .where("status", "in", ["pending", "approved"]),
  );
  const requestedKeys = new Set(internalSlots.map((slot) => slotKey(slot)));
  for (const doc of userAppointments.docs) {
    if (doc.id === params.ignoreAppointmentId) continue;
    const appointment = doc.data() as Appointment;
    const slot = appointment.approvedSlot ?? appointment.preferredSlots?.[0];
    if (!slot) continue;
    const overlaps = expandInternalSlots(slot, parseDuration(appointment.duration))
      .some((candidate) => requestedKeys.has(slotKey(candidate)));
    if (overlaps) {
      throw new HttpsError("failed-precondition", "User already has a session at this time.");
    }
  }
}

function writeOccupancyDelta(
  transaction: Transaction,
  slot: TimeSlot,
  duration: number,
  delta: 1 | -1,
): void {
  expandInternalSlots(slot, duration).forEach((internalSlot) => {
    const ref = db.collection("slot_occupancy").doc(slotKey(internalSlot));
    transaction.set(
      ref,
      {
        date: internalSlot.date,
        time: internalSlot.time,
        count: FieldValue.increment(delta),
      },
      {merge: true},
    );
  });
}

function expandInternalSlots(start: TimeSlot, duration: number): TimeSlot[] {
  const [hour, minute] = start.time.split(":").map((part) => Number(part));
  const base = new Date(Date.UTC(2000, 0, 1, hour, minute));
  const count = duration / internalSlotMinutes;
  return Array.from({length: count}, (_, index) => {
    const time = new Date(base.getTime() + index * internalSlotMinutes * 60_000);
    return {
      date: start.date,
      time: `${String(time.getUTCHours()).padStart(2, "0")}:${String(time.getUTCMinutes()).padStart(2, "0")}`,
    };
  });
}

function slotKey(slot: TimeSlot): string {
  return `${slot.date}_${slot.time}`;
}

function parseDuration(value: string | number): number {
  const duration = typeof value === "number" ? value : Number(value);
  if (!allowedDurations.has(duration)) {
    throw new HttpsError("invalid-argument", "Duration must be 30, 45, or 60.");
  }
  return duration;
}

function requireFutureSlot(slot: TimeSlot): void {
  const slotDate = new Date(`${slot.date}T${slot.time}:00`);
  if (Number.isNaN(slotDate.getTime()) || slotDate <= new Date()) {
    throw new HttpsError("failed-precondition", "Slot must be in the future.");
  }
}

function parseRequestAppointmentPayload(data: unknown): RequestAppointmentPayload {
  const payload = requireRecord(data);
  return {
    duration: payload.duration as string | number,
    preferredSlot: parseTimeSlot(payload.preferredSlot),
    reason: typeof payload.reason === "string" ? payload.reason : "",
  };
}

function parseApprovePayload(data: unknown): ApproveAppointmentPayload {
  const payload = requireRecord(data);
  return {
    appointmentId: requireString(payload.appointmentId, "appointmentId"),
    approvedSlot: parseTimeSlot(payload.approvedSlot),
    assignedTrainer: optionalString(payload.assignedTrainer),
    sessionType: optionalString(payload.sessionType),
  };
}

function parseRejectPayload(data: unknown): RejectAppointmentPayload {
  const payload = requireRecord(data);
  return {appointmentId: requireString(payload.appointmentId, "appointmentId")};
}

function parseUpdateSlotPayload(data: unknown): UpdateAppointmentSlotPayload {
  const payload = requireRecord(data);
  return {
    appointmentId: requireString(payload.appointmentId, "appointmentId"),
    approvedSlot: parseTimeSlot(payload.approvedSlot),
  };
}

function parseAssignBonoPayload(data: unknown): AssignBonoToUserPayload {
  const payload = requireRecord(data);
  const tamano = Number(payload.tamano);
  if (![240, 360, 480].includes(tamano)) {
    throw new HttpsError("invalid-argument", "Unsupported bono size.");
  }
  return {
    userId: requireString(payload.userId, "userId"),
    tamano,
    mesesValidez: payload.mesesValidez ? Number(payload.mesesValidez) : undefined,
  };
}

function parseTimeSlot(value: unknown): TimeSlot {
  const payload = requireRecord(value);
  return {
    date: requireString(payload.date, "date"),
    time: requireString(payload.time, "time"),
  };
}

function requireRecord(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "Expected object payload.");
  }
  return value as Record<string, unknown>;
}

function requireString(value: unknown, field: string): string {
  if (typeof value !== "string" || !value.trim()) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  return value.trim();
}

function optionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function makeNotificationPayload(
  event: ReservationNotificationEvent,
  appointment: Appointment,
): Record<string, unknown> {
  return {
    event,
    appointment: {
      userId: appointment.userId,
      name: appointment.name,
      email: appointment.email,
      phone: appointment.phone,
      serviceType: appointment.serviceType,
      duration: appointment.duration,
      approvedSlot: appointment.approvedSlot,
      assignedTrainer: appointment.assignedTrainer,
      sessionType: appointment.sessionType,
    },
    sentAt: Timestamp.now().toDate().toISOString(),
  };
}

async function notifyMakeIfEnabled(payload: Record<string, unknown>): Promise<void> {
  if (process.env.MAKE_WEBHOOK_ENABLED !== "true") return;
  const url = makeReservationWebhookUrl.value();
  if (!url) return;

  const response = await fetch(url, {
    method: "POST",
    headers: {"content-type": "application/json"},
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new HttpsError("internal", "Make.com webhook failed.");
  }
}
