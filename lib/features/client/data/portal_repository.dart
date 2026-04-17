import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/portal_availability.dart';
import '../domain/portal_models.dart';

abstract interface class PortalRepository {
  Stream<UserProfile?> watchUserProfile(String uid);
  Stream<List<Appointment>> watchAppointmentsByUser(String uid);
  Stream<List<Bono>> watchBonosByUser(String uid);
  Stream<List<Trainer>> watchActiveTrainers();
  Stream<List<BlockedSlot>> watchBlockedSlotsForRange({
    required String startDate,
    required String endDate,
  });
  Stream<List<SlotOccupancy>> watchSlotOccupancyForRange({
    required String startDate,
    required String endDate,
  });
  Stream<SiteConfig?> watchSiteConfig();

  Future<void> createAppointment(AppointmentRequest request);
}

class AppointmentRequest {
  const AppointmentRequest({
    required this.durationMinutes,
    required this.preferredSlot,
    required this.reason,
  });

  final int durationMinutes;
  final TimeSlot preferredSlot;
  final String reason;

  Map<String, Object?> toCallablePayload() {
    return {
      'duration': durationMinutes.toString(),
      'preferredSlot': preferredSlot.toMap(),
      'reason': reason,
    };
  }
}

class FirebasePortalRepository implements PortalRepository {
  FirebasePortalRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Stream<UserProfile?> watchUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    });
  }

  @override
  Stream<List<Appointment>> watchAppointmentsByUser(String uid) {
    return _firestore
        .collection('appointments')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Appointment.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<Bono>> watchBonosByUser(String uid) {
    return _firestore
        .collection('bonos')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Bono.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<Trainer>> watchActiveTrainers() {
    return _firestore
        .collection('trainers')
        .where('active', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Trainer.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<BlockedSlot>> watchBlockedSlotsForRange({
    required String startDate,
    required String endDate,
  }) {
    return _firestore
        .collection('blocked_slots')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BlockedSlot.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<List<SlotOccupancy>> watchSlotOccupancyForRange({
    required String startDate,
    required String endDate,
  }) {
    return _firestore
        .collection('slot_occupancy')
        .where('date', isGreaterThanOrEqualTo: startDate)
        .where('date', isLessThan: endDate)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SlotOccupancy.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

  @override
  Stream<SiteConfig?> watchSiteConfig() {
    return _firestore.collection('site_config').doc('main').snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (data == null) return null;
      return SiteConfig.fromMap(data);
    });
  }

  @override
  Future<void> createAppointment(AppointmentRequest request) async {
    await _functions
        .httpsCallable('createAppointment')
        .call<Object?>(request.toCallablePayload());
  }
}

String appointmentRequestErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = (error.message ?? '').toLowerCase();
    return switch (error.code) {
      'unauthenticated' => 'Tu sesion ha caducado. Vuelve a iniciar sesion.',
      'not-found' when message.contains('profile') =>
        'Completa tu perfil antes de reservar.',
      'failed-precondition' when message.contains('phone') =>
        'Completa tu telefono antes de reservar.',
      'failed-precondition' when message.contains('no active bono') =>
        'No tienes un bono activo disponible.',
      'failed-precondition' when message.contains('not enough') =>
        'No tienes minutos suficientes para esta sesion.',
      'failed-precondition' when message.contains('future') =>
        'Elige una franja futura.',
      'failed-precondition' when message.contains('fit schedule') =>
        'Esta franja no cabe en el horario disponible.',
      'failed-precondition' when message.contains('blocked') =>
        'Esta franja ya no esta disponible.',
      'failed-precondition' when message.contains('full') =>
        'Esta franja esta completa.',
      'failed-precondition' when message.contains('already has') =>
        'Ya tienes una sesion en esa franja.',
      'failed-precondition' when message.contains('more than one') =>
        'Hay una incidencia con tu bono activo. Contacta con Focus Club.',
      _ => 'No hemos podido enviar la solicitud. Intentalo de nuevo.',
    };
  }
  if (error is ActiveBonoConsistencyException) {
    return 'Hay una incidencia con tu bono activo. Contacta con Focus Club.';
  }
  return 'No hemos podido enviar la solicitud. Intentalo de nuevo.';
}

class FakePortalRepository implements PortalRepository {
  FakePortalRepository({
    UserProfile? profile,
    List<Appointment> appointments = const [],
    List<Bono> bonos = const [],
    List<Trainer> trainers = const [],
    List<BlockedSlot> blockedSlots = const [],
    List<SlotOccupancy> slotOccupancy = const [],
    SiteConfig? siteConfig,
  }) : _profile = profile,
       _appointments = appointments,
       _bonos = bonos,
       _trainers = trainers,
       _blockedSlots = blockedSlots,
       _slotOccupancy = slotOccupancy,
       _siteConfig = siteConfig;

  final UserProfile? _profile;
  final List<Appointment> _appointments;
  final List<Bono> _bonos;
  final List<Trainer> _trainers;
  final List<BlockedSlot> _blockedSlots;
  final List<SlotOccupancy> _slotOccupancy;
  final SiteConfig? _siteConfig;
  final List<AppointmentRequest> requests = [];

  @override
  Stream<UserProfile?> watchUserProfile(String uid) => Stream.value(_profile);

  @override
  Stream<List<Appointment>> watchAppointmentsByUser(String uid) {
    return Stream.value(
      _appointments.where((appointment) => appointment.userId == uid).toList(),
    );
  }

  @override
  Stream<List<Bono>> watchBonosByUser(String uid) {
    return Stream.value(_bonos.where((bono) => bono.userId == uid).toList());
  }

  @override
  Stream<List<Trainer>> watchActiveTrainers() {
    return Stream.value(
      _trainers.where((trainer) => trainer.active).toList(growable: false),
    );
  }

  @override
  Stream<List<BlockedSlot>> watchBlockedSlotsForRange({
    required String startDate,
    required String endDate,
  }) {
    return Stream.value(
      _blockedSlots
          .where((slot) => slot.date.compareTo(startDate) >= 0)
          .where((slot) => slot.date.compareTo(endDate) < 0)
          .toList(growable: false),
    );
  }

  @override
  Stream<List<SlotOccupancy>> watchSlotOccupancyForRange({
    required String startDate,
    required String endDate,
  }) {
    return Stream.value(
      _slotOccupancy
          .where((slot) => slot.date.compareTo(startDate) >= 0)
          .where((slot) => slot.date.compareTo(endDate) < 0)
          .toList(growable: false),
    );
  }

  @override
  Stream<SiteConfig?> watchSiteConfig() => Stream.value(_siteConfig);

  @override
  Future<void> createAppointment(AppointmentRequest request) async {
    requests.add(request);
  }
}
