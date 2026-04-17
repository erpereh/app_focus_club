import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/portal_repository.dart';
import '../domain/portal_availability.dart';
import '../domain/portal_models.dart';

class ClientPortalState {
  const ClientPortalState({
    this.profile,
    this.appointments = const [],
    this.bonos = const [],
    this.trainers = const [],
    this.blockedSlots = const [],
    this.slotOccupancy = const [],
    this.siteConfig,
    this.activeBono,
    this.error,
    this.isLoading = true,
  });

  final UserProfile? profile;
  final List<Appointment> appointments;
  final List<Bono> bonos;
  final List<Trainer> trainers;
  final List<BlockedSlot> blockedSlots;
  final List<SlotOccupancy> slotOccupancy;
  final SiteConfig? siteConfig;
  final Bono? activeBono;
  final Object? error;
  final bool isLoading;

  List<Appointment> get activeAppointments {
    return appointments
        .where(
          (appointment) =>
              appointment.status == AppointmentStatus.pending ||
              appointment.status == AppointmentStatus.approved,
        )
        .toList(growable: false);
  }

  List<Appointment> get rejectedAppointments {
    return appointments
        .where(
          (appointment) => appointment.status == AppointmentStatus.rejected,
        )
        .toList(growable: false);
  }

  List<Bono> get inactiveBonos {
    return bonos.where((bono) => !bono.isActive).toList(growable: false);
  }

  ClientPortalState copyWith({
    UserProfile? profile,
    List<Appointment>? appointments,
    List<Bono>? bonos,
    List<Trainer>? trainers,
    List<BlockedSlot>? blockedSlots,
    List<SlotOccupancy>? slotOccupancy,
    SiteConfig? siteConfig,
    Bono? activeBono,
    bool clearActiveBono = false,
    Object? error,
    bool? isLoading,
  }) {
    return ClientPortalState(
      profile: profile ?? this.profile,
      appointments: appointments ?? this.appointments,
      bonos: bonos ?? this.bonos,
      trainers: trainers ?? this.trainers,
      blockedSlots: blockedSlots ?? this.blockedSlots,
      slotOccupancy: slotOccupancy ?? this.slotOccupancy,
      siteConfig: siteConfig ?? this.siteConfig,
      activeBono: clearActiveBono ? null : activeBono ?? this.activeBono,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ClientPortalViewModel extends ChangeNotifier {
  ClientPortalViewModel({
    required PortalRepository repository,
    required String uid,
  }) : _repository = repository,
       _uid = uid;

  final PortalRepository _repository;
  final String _uid;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  ClientPortalState _state = const ClientPortalState();
  ClientPortalState get state => _state;

  void start() {
    final range = _bookingRange();
    _subscriptions
      ..add(
        _repository
            .watchUserProfile(_uid)
            .listen(_setProfile, onError: _setError),
      )
      ..add(
        _repository
            .watchAppointmentsByUser(_uid)
            .listen(_setAppointments, onError: _setError),
      )
      ..add(
        _repository
            .watchBonosByUser(_uid)
            .listen(_setBonos, onError: _setError),
      )
      ..add(
        _repository.watchActiveTrainers().listen(
          _setTrainers,
          onError: _setError,
        ),
      )
      ..add(
        _repository
            .watchBlockedSlotsForRange(
              startDate: range.start,
              endDate: range.end,
            )
            .listen(_setBlockedSlots, onError: _setError),
      )
      ..add(
        _repository
            .watchSlotOccupancyForRange(
              startDate: range.start,
              endDate: range.end,
            )
            .listen(_setSlotOccupancy, onError: _setError),
      )
      ..add(
        _repository.watchSiteConfig().listen(
          _setSiteConfig,
          onError: _setError,
        ),
      );
  }

  Future<void> createAppointment({
    required int durationMinutes,
    required TimeSlot preferredSlot,
    required String reason,
  }) async {
    await _repository.createAppointment(
      AppointmentRequest(
        durationMinutes: durationMinutes,
        preferredSlot: preferredSlot,
        reason: reason,
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _setProfile(UserProfile? profile) {
    _state = _state.copyWith(profile: profile, isLoading: false);
    notifyListeners();
  }

  void _setAppointments(List<Appointment> appointments) {
    _state = _state.copyWith(appointments: appointments, isLoading: false);
    notifyListeners();
  }

  void _setBonos(List<Bono> bonos) {
    try {
      final activeBono = selectUniqueActiveBono(bonos);
      _state = _state.copyWith(
        bonos: bonos,
        activeBono: activeBono,
        clearActiveBono: activeBono == null,
        isLoading: false,
      );
    } catch (error) {
      _state = _state.copyWith(bonos: bonos, error: error, isLoading: false);
    }
    notifyListeners();
  }

  void _setTrainers(List<Trainer> trainers) {
    _state = _state.copyWith(trainers: trainers, isLoading: false);
    notifyListeners();
  }

  void _setBlockedSlots(List<BlockedSlot> blockedSlots) {
    _state = _state.copyWith(blockedSlots: blockedSlots, isLoading: false);
    notifyListeners();
  }

  void _setSlotOccupancy(List<SlotOccupancy> slotOccupancy) {
    _state = _state.copyWith(slotOccupancy: slotOccupancy, isLoading: false);
    notifyListeners();
  }

  void _setSiteConfig(SiteConfig? siteConfig) {
    _state = _state.copyWith(siteConfig: siteConfig, isLoading: false);
    notifyListeners();
  }

  void _setError(Object error) {
    _state = _state.copyWith(error: error, isLoading: false);
    notifyListeners();
  }

  ({String start, String end}) _bookingRange() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 22));
    return (start: _wireDate(start), end: _wireDate(end));
  }

  String _wireDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
