import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/portal_repository.dart';
import '../data/push_notification_service.dart';
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
    this.recurringSeriesById = const {},
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
  final Map<String, RecurringAppointmentSeries> recurringSeriesById;
  final Object? error;
  final bool isLoading;

  List<Appointment> activeAppointmentsAt(DateTime now) {
    final result = appointments
        .where(
          (appointment) =>
              (appointment.status == AppointmentStatus.pending ||
                  appointment.status == AppointmentStatus.approved) &&
              (appointment.schedulingDateTime?.isAfter(now) ?? false),
        )
        .toList();
    result.sort(
      (a, b) => a.schedulingDateTime!.compareTo(b.schedulingDateTime!),
    );
    return List.unmodifiable(result);
  }

  List<Appointment> get activeAppointments =>
      activeAppointmentsAt(DateTime.now());

  List<Appointment> dashboardAppointmentsAt(DateTime now) {
    return activeAppointmentsAt(now).take(2).toList(growable: false);
  }

  List<Appointment> get dashboardAppointments =>
      dashboardAppointmentsAt(DateTime.now());

  List<Appointment> dashboardHistoryAppointmentsAt(DateTime now) {
    final result = appointments
        .where(
          (appointment) =>
              (appointment.status == AppointmentStatus.pending ||
                  appointment.status == AppointmentStatus.approved) &&
              (appointment.schedulingDateTime?.isAfter(now) == false),
        )
        .toList();
    result.sort(
      (a, b) => b.schedulingDateTime!.compareTo(a.schedulingDateTime!),
    );
    return List.unmodifiable(result.take(2));
  }

  List<Appointment> get dashboardHistoryAppointments =>
      dashboardHistoryAppointmentsAt(DateTime.now());

  List<Appointment> historyAppointmentsAt(DateTime now) {
    final result = appointments
        .where(
          (appointment) =>
              appointment.status == AppointmentStatus.rejected ||
              appointment.status == AppointmentStatus.cancelled ||
              ((appointment.status == AppointmentStatus.pending ||
                      appointment.status == AppointmentStatus.approved) &&
                  !(appointment.schedulingDateTime?.isAfter(now) ?? false)),
        )
        .toList();
    result.sort((a, b) {
      final aDate = a.schedulingDateTime;
      final bDate = b.schedulingDateTime;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return List.unmodifiable(result);
  }

  List<Appointment> get historyAppointments =>
      historyAppointmentsAt(DateTime.now());

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
    Map<String, RecurringAppointmentSeries>? recurringSeriesById,
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
      recurringSeriesById: recurringSeriesById ?? this.recurringSeriesById,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

typedef AppointmentTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class ClientPortalViewModel extends ChangeNotifier {
  ClientPortalViewModel({
    required PortalRepository repository,
    required String uid,
    FirebasePushNotificationService? pushNotificationService,
    DateTime Function()? now,
    AppointmentTimerFactory? appointmentTimerFactory,
  }) : _repository = repository,
       _uid = uid,
       _now = now ?? DateTime.now,
       _appointmentTimerFactory =
           appointmentTimerFactory ??
           ((duration, callback) => Timer(duration, callback)),
       _pushNotificationService =
           pushNotificationService ?? FirebasePushNotificationService.instance;

  final PortalRepository _repository;
  final String _uid;
  final DateTime Function() _now;
  final AppointmentTimerFactory _appointmentTimerFactory;
  final FirebasePushNotificationService _pushNotificationService;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Timer? _appointmentBoundaryTimer;
  int _appointmentTimerGeneration = 0;
  bool _isDisposed = false;

  ClientPortalState _state = const ClientPortalState();
  ClientPortalState get state => _state;
  DateTime get currentTime => _now();

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
      )
      ..add(
        _repository
            .watchRecurringSeriesByUser(_uid)
            .listen(_setRecurringSeries, onError: _setError),
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

  Future<void> createRecurringAppointments({
    required int durationMinutes,
    required TimeSlot preferredSlot,
    required int intervalDays,
    required String endDate,
    required String reason,
  }) async {
    await _repository.createRecurringAppointments(
      RecurringAppointmentRequest(
        durationMinutes: durationMinutes,
        preferredSlot: preferredSlot,
        intervalDays: intervalDays,
        endDate: endDate,
        comment: reason,
      ),
    );
  }

  Future<void> cancelAppointment(String appointmentId) {
    return _repository.cancelOwnAppointment(appointmentId);
  }

  Future<void> updateAppointmentSlot({
    required String appointmentId,
    required TimeSlot preferredSlot,
  }) {
    return _repository.updateOwnAppointmentSlot(
      appointmentId: appointmentId,
      preferredSlot: preferredSlot,
    );
  }

  Future<void> cancelRecurringAppointmentSeries(String seriesId) {
    return _repository.cancelOwnRecurringAppointmentSeries(seriesId);
  }

  void refreshTemporalState() {
    if (_isDisposed) return;
    _scheduleAppointmentBoundary();
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _appointmentTimerGeneration++;
    _appointmentBoundaryTimer?.cancel();
    _appointmentBoundaryTimer = null;
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    unawaited(_pushNotificationService.stop());
    super.dispose();
  }

  void _setProfile(UserProfile? profile) {
    _state = _state.copyWith(profile: profile, isLoading: false);
    if (profile != null) {
      unawaited(
        _pushNotificationService.configureForUser(
          uid: _uid,
          enabled: profile.pushNotificationsEnabled,
          repository: _repository,
        ),
      );
    }
    notifyListeners();
  }

  void _setAppointments(List<Appointment> appointments) {
    _state = _state.copyWith(appointments: appointments, isLoading: false);
    _scheduleAppointmentBoundary();
    notifyListeners();
  }

  void _scheduleAppointmentBoundary() {
    _appointmentBoundaryTimer?.cancel();
    _appointmentBoundaryTimer = null;
    final generation = ++_appointmentTimerGeneration;
    if (_isDisposed) return;

    final now = _now();
    DateTime? nextBoundary;
    for (final appointment in _state.appointments) {
      if (appointment.status != AppointmentStatus.pending &&
          appointment.status != AppointmentStatus.approved) {
        continue;
      }
      final date = appointment.schedulingDateTime;
      if (date == null || !date.isAfter(now)) continue;
      if (nextBoundary == null || date.isBefore(nextBoundary)) {
        nextBoundary = date;
      }
    }
    if (nextBoundary == null) return;

    final remaining = nextBoundary.difference(now);
    final delay = remaining < const Duration(milliseconds: 1)
        ? const Duration(milliseconds: 1)
        : remaining;
    _appointmentBoundaryTimer = _appointmentTimerFactory(delay, () {
      if (_isDisposed || generation != _appointmentTimerGeneration) return;
      _appointmentBoundaryTimer = null;
      notifyListeners();
      _scheduleAppointmentBoundary();
    });
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

  void _setRecurringSeries(List<RecurringAppointmentSeries> series) {
    _state = _state.copyWith(
      recurringSeriesById: {
        for (final item in series) item.id: item,
      },
      isLoading: false,
    );
    notifyListeners();
  }

  void _setError(Object error) {
    _state = _state.copyWith(error: error, isLoading: false);
    notifyListeners();
  }

  ({String start, String end}) _bookingRange() {
    final now = _now();
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
