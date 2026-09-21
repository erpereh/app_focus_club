import 'madrid_date.dart';
import 'portal_models.dart';

const int internalSlotMinutes = 15;

class ActiveBonoConsistencyException implements Exception {
  const ActiveBonoConsistencyException(this.activeCount);

  final int activeCount;

  @override
  String toString() {
    return 'Expected at most one active bono, found $activeCount.';
  }
}

Bono? selectUniqueActiveBono(Iterable<Bono> bonos) {
  final active = bonos.where((bono) => bono.isActive).toList(growable: false);
  if (active.length > 1) {
    throw ActiveBonoConsistencyException(active.length);
  }
  return active.firstOrNull;
}

/// Canonical occupancy blocks of [internalSlotMinutes]. Never rounds a session
/// to an earlier start and never adds 30-minute floors.
List<String> getCanonicalSlotBlocks(String startTime, int durationMinutes) {
  final startTotal = parseTimeMinutes(startTime);
  if (startTotal == null) return const [];
  if (durationMinutes <= 0) return const [];

  final numBlocks = (durationMinutes / internalSlotMinutes).ceil();
  return List<String>.unmodifiable(
    List.generate(numBlocks, (index) {
      return formatClockMinutes(startTotal + internalSlotMinutes * index);
    }),
  );
}

List<TimeSlot> expandInternalSlots(TimeSlot start, int durationMinutes) {
  return getCanonicalSlotBlocks(
    start.time,
    durationMinutes,
  ).map((time) => TimeSlot(date: start.date, time: time)).toList();
}

int? parseTimeMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

String formatClockMinutes(int totalMinutes) {
  final hour = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final minute = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$hour:$minute';
}

bool isGeneratedScheduleTime({
  required String time,
  required SiteConfig siteConfig,
}) {
  final startMinutes = parseTimeMinutes(time);
  if (startMinutes == null) return false;
  final interval = normalizeSlotInterval(siteConfig.slotInterval);
  final scheduleStart = siteConfig.startHour * 60;
  final scheduleEnd = siteConfig.endHour * 60;
  if (startMinutes < scheduleStart || startMinutes >= scheduleEnd) {
    return false;
  }
  return (startMinutes - scheduleStart) % interval == 0;
}

bool doesDurationFitInSchedule({
  required TimeSlot slot,
  required int durationMinutes,
  required SiteConfig siteConfig,
}) {
  final startMinutes = parseTimeMinutes(slot.time);
  if (startMinutes == null) return false;
  final scheduleStart = siteConfig.startHour * 60;
  final scheduleEnd = siteConfig.endHour * 60;
  final endMinutes = startMinutes + durationMinutes;
  return startMinutes >= scheduleStart && endMinutes <= scheduleEnd;
}

bool isDurationBlocked({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<BlockedSlot> blockedSlots,
}) {
  final blockedKeys = blockedSlots.map((blocked) => blocked.slot.key).toSet();
  return availabilityKeysForSlot(
    start,
    durationMinutes,
  ).any(blockedKeys.contains);
}

bool isDurationFull({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<SlotOccupancy> occupancy,
  required int maxCapacity,
}) {
  return maxEffectiveOccupancyForDuration(
        start: start,
        durationMinutes: durationMinutes,
        occupancy: occupancy,
      ) >=
      maxCapacity;
}

bool overlapsActiveAppointment({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<Appointment> appointments,
  Set<String> excludedAppointmentIds = const {},
}) {
  final requestedKeys = availabilityKeysForSlot(start, durationMinutes);

  return appointments
      .where(
        (appointment) =>
            !excludedAppointmentIds.contains(appointment.id) &&
            (appointment.status == AppointmentStatus.pending ||
                appointment.status == AppointmentStatus.approved),
      )
      .any((appointment) {
        final slot = appointment.schedulingSlot;
        if (slot == null) return false;
        return availabilityKeysForSlot(
          slot,
          appointment.durationMinutes,
        ).any(requestedKeys.contains);
      });
}

Set<String> availabilityKeysForSlot(TimeSlot slot, int durationMinutes) {
  return getCanonicalSlotBlocks(
    slot.time,
    durationMinutes,
  ).map((time) => '${slot.date}_$time').toSet();
}

Map<String, int> buildOccupancyCreditsByKey(
  Iterable<Appointment> appointments,
) {
  final credits = <String, int>{};
  for (final appointment in appointments) {
    if (appointment.status != AppointmentStatus.approved) continue;
    final slot = appointment.schedulingSlot;
    if (slot == null) continue;
    for (final key in availabilityKeysForSlot(
      slot,
      appointment.durationMinutes,
    )) {
      credits[key] = (credits[key] ?? 0) + 1;
    }
  }
  return Map.unmodifiable(credits);
}

int maxEffectiveOccupancyForDuration({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<SlotOccupancy> occupancy,
  Map<String, int> occupancyCreditsByKey = const {},
}) {
  final counts = {for (final item in occupancy) item.slot.key: item.count};
  var maximum = 0;
  for (final key in availabilityKeysForSlot(start, durationMinutes)) {
    final effective = ((counts[key] ?? 0) - (occupancyCreditsByKey[key] ?? 0))
        .clamp(0, 1 << 30);
    if (effective > maximum) maximum = effective;
  }
  return maximum;
}

bool canCustomerRescheduleAppointment(Appointment appointment, DateTime now) {
  if (appointment.status != AppointmentStatus.pending &&
      appointment.status != AppointmentStatus.approved) {
    return false;
  }
  final slot = appointment.schedulingSlot;
  if (slot == null) return false;
  return isMadridSlotFuture(date: slot.date, time: slot.time, now: now) &&
      !isInsideCustomerRescheduleLockWindow(
        date: slot.date,
        time: slot.time,
        now: now,
      );
}

List<Appointment> futureActiveOccurrencesForSeries({
  required String seriesId,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  final occurrences = appointments
      .where((appointment) {
        if (appointment.recurrenceSeriesId != seriesId ||
            (appointment.status != AppointmentStatus.pending &&
                appointment.status != AppointmentStatus.approved)) {
          return false;
        }
        final slot = appointment.schedulingSlot;
        return slot != null &&
            isMadridSlotFuture(date: slot.date, time: slot.time, now: now);
      })
      .toList(growable: false);
  occurrences.sort((left, right) {
    final leftSlot = left.schedulingSlot!;
    final rightSlot = right.schedulingSlot!;
    return '${leftSlot.date}_${leftSlot.time}'.compareTo(
      '${rightSlot.date}_${rightSlot.time}',
    );
  });
  return occurrences;
}

bool canCustomerReplaceRecurringSeries({
  required String seriesId,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  final future = futureActiveOccurrencesForSeries(
    seriesId: seriesId,
    appointments: appointments,
    now: now,
  );
  if (future.isEmpty) return false;
  return future.every((appointment) {
    final slot = appointment.schedulingSlot!;
    return !isInsideCustomerRescheduleLockWindow(
      date: slot.date,
      time: slot.time,
      now: now,
    );
  });
}

class RecurringSeriesReplacementBonoPolicy {
  const RecurringSeriesReplacementBonoPolicy({
    required this.isAvailable,
    required this.availableMinutes,
    required this.expirationDate,
  });

  final bool isAvailable;
  final int availableMinutes;
  final String? expirationDate;
}

RecurringSeriesReplacementBonoPolicy recurringSeriesReplacementBonoPolicy({
  required Bono? bono,
  required String seriesId,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  if (bono == null || bono.estado == BonoStatus.eliminado) {
    return const RecurringSeriesReplacementBonoPolicy(
      isAvailable: false,
      availableMinutes: 0,
      expirationDate: null,
    );
  }

  final reserved = futureActiveOccurrencesForSeries(
    seriesId: seriesId,
    appointments: appointments,
    now: now,
  ).fold<int>(0, (total, item) => total + item.durationMinutes);
  final expiration = _backendExpirationInstant(bono.fechaExpiracion);
  final isExpired =
      bono.estado == BonoStatus.expirado ||
      (expiration != null && expiration.isBefore(now.toUtc()));
  final canExpand = bono.estado == BonoStatus.activo && !isExpired;

  return RecurringSeriesReplacementBonoPolicy(
    isAvailable: true,
    availableMinutes: reserved + (canExpand ? bono.minutosRestantes : 0),
    expirationDate: isExpired ? null : bono.fechaExpiracion,
  );
}

int availableMinutesForSeriesReplacement({
  required Bono bono,
  required String seriesId,
  required Iterable<Appointment> appointments,
  required DateTime now,
}) {
  return recurringSeriesReplacementBonoPolicy(
    bono: bono,
    seriesId: seriesId,
    appointments: appointments,
    now: now,
  ).availableMinutes;
}

DateTime? _backendExpirationInstant(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;

  final civilMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
  if (civilMatch != null) {
    final year = int.parse(civilMatch.group(1)!);
    final month = int.parse(civilMatch.group(2)!);
    final day = int.parse(civilMatch.group(3)!);
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day
        ? parsed
        : null;
  }

  final hasExplicitZone = RegExp(
    r'(?:[zZ]|[+-]\d{2}:?\d{2})$',
  ).hasMatch(trimmed);
  final parsed = DateTime.tryParse(hasExplicitZone ? trimmed : '${trimmed}Z');
  return parsed?.toUtc();
}

enum BookingSlotAvailability {
  available,
  partial,
  almostFull,
  ownAppointment,
  blocked,
  full,
  unavailable,
  past,
}

class BookingSlotState {
  const BookingSlotState({
    required this.slot,
    required this.availability,
    required this.occupied,
    required this.remaining,
    required this.maxCapacity,
    required this.label,
  });

  final TimeSlot slot;
  final BookingSlotAvailability availability;
  final int occupied;
  final int remaining;
  final int maxCapacity;
  final String label;

  bool get isEnabled =>
      availability == BookingSlotAvailability.available ||
      availability == BookingSlotAvailability.partial ||
      availability == BookingSlotAvailability.almostFull;
}

BookingSlotState bookingSlotState({
  required TimeSlot slot,
  required int durationMinutes,
  required SiteConfig siteConfig,
  required Iterable<BlockedSlot> blockedSlots,
  required Iterable<SlotOccupancy> occupancy,
  required Iterable<Appointment> appointments,
  Set<String> excludedAppointmentIds = const {},
  Map<String, int> occupancyCreditsByKey = const {},
  bool enforceRescheduleLeadTime = false,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final instant = madridCivilSlotToUtc(date: slot.date, time: slot.time);
  if (instant == null || !instant.isAfter(current.toUtc())) {
    return _slotState(
      slot: slot,
      availability: BookingSlotAvailability.past,
      maxCapacity: siteConfig.maxCapacity,
      label: 'No disponible',
    );
  }
  if (enforceRescheduleLeadTime &&
      isInsideCustomerRescheduleLockWindow(
        date: slot.date,
        time: slot.time,
        now: current,
      )) {
    return _slotState(
      slot: slot,
      availability: BookingSlotAvailability.unavailable,
      maxCapacity: siteConfig.maxCapacity,
      label: 'No disponible',
    );
  }
  if (!doesDurationFitInSchedule(
    slot: slot,
    durationMinutes: durationMinutes,
    siteConfig: siteConfig,
  )) {
    return _slotState(
      slot: slot,
      availability: BookingSlotAvailability.unavailable,
      maxCapacity: siteConfig.maxCapacity,
      label: 'No disponible',
    );
  }

  final requestedKeys = availabilityKeysForSlot(slot, durationMinutes);
  final blockedKeys = blockedSlots.map((item) => item.slot.key).toSet();
  if (requestedKeys.any(blockedKeys.contains)) {
    return _slotState(
      slot: slot,
      availability: BookingSlotAvailability.blocked,
      maxCapacity: siteConfig.maxCapacity,
      label: 'Bloqueado',
    );
  }
  if (overlapsActiveAppointment(
    start: slot,
    durationMinutes: durationMinutes,
    appointments: appointments,
    excludedAppointmentIds: excludedAppointmentIds,
  )) {
    return _slotState(
      slot: slot,
      availability: BookingSlotAvailability.ownAppointment,
      maxCapacity: siteConfig.maxCapacity,
      label: 'Tu sesión',
    );
  }

  final occupied = maxEffectiveOccupancyForDuration(
    start: slot,
    durationMinutes: durationMinutes,
    occupancy: occupancy,
    occupancyCreditsByKey: occupancyCreditsByKey,
  );
  final remaining = (siteConfig.maxCapacity - occupied).clamp(
    0,
    siteConfig.maxCapacity,
  );
  if (occupied >= siteConfig.maxCapacity) {
    return BookingSlotState(
      slot: slot,
      availability: BookingSlotAvailability.full,
      occupied: occupied,
      remaining: 0,
      maxCapacity: siteConfig.maxCapacity,
      label: 'Completo',
    );
  }
  if (occupied == 0) {
    return BookingSlotState(
      slot: slot,
      availability: BookingSlotAvailability.available,
      occupied: 0,
      remaining: siteConfig.maxCapacity,
      maxCapacity: siteConfig.maxCapacity,
      label: 'Disponible',
    );
  }
  if (remaining == 1) {
    return BookingSlotState(
      slot: slot,
      availability: BookingSlotAvailability.almostFull,
      occupied: occupied,
      remaining: remaining,
      maxCapacity: siteConfig.maxCapacity,
      label: 'Casi lleno · 1 plaza',
    );
  }
  return BookingSlotState(
    slot: slot,
    availability: BookingSlotAvailability.partial,
    occupied: occupied,
    remaining: remaining,
    maxCapacity: siteConfig.maxCapacity,
    label: '$remaining plazas',
  );
}

BookingSlotState _slotState({
  required TimeSlot slot,
  required BookingSlotAvailability availability,
  required int maxCapacity,
  required String label,
}) {
  return BookingSlotState(
    slot: slot,
    availability: availability,
    occupied: 0,
    remaining: maxCapacity,
    maxCapacity: maxCapacity,
    label: label,
  );
}
