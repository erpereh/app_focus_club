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

List<TimeSlot> expandInternalSlots(TimeSlot start, int durationMinutes) {
  if (durationMinutes % internalSlotMinutes != 0) {
    throw ArgumentError.value(
      durationMinutes,
      'durationMinutes',
      'Duration must be divisible by $internalSlotMinutes.',
    );
  }

  final startTotal = parseTimeMinutes(start.time);
  if (startTotal == null) {
    throw FormatException('Expected HH:mm time, got ${start.time}');
  }

  final count = durationMinutes ~/ internalSlotMinutes;
  return List.generate(count, (index) {
    return TimeSlot(
      date: start.date,
      time: formatClockMinutes(startTotal + internalSlotMinutes * index),
    );
  });
}

/// Firestore occupancy/blocked keys that [createRecurringAppointments] validates.
///
/// Matches backend `getSlotBlocks`: 15-minute internals plus legacy 30-minute
/// floors. Do not use this for calendar slot rendering — that stays on
/// [expandInternalSlots].
List<String> expandAvailabilitySlotKeys(
  String startTime,
  int durationMinutes,
) {
  final startTotal = parseTimeMinutes(startTime);
  if (startTotal == null) {
    throw FormatException('Expected HH:mm time, got $startTime');
  }
  if (durationMinutes <= 0) return const [];

  final numBlocks = (durationMinutes / internalSlotMinutes).ceil();
  final blocks = <String>{};
  for (var index = 0; index < numBlocks; index += 1) {
    final total = startTotal + index * internalSlotMinutes;
    final legacyTotal = (total ~/ 30) * 30;
    blocks
      ..add(formatClockMinutes(total))
      ..add(formatClockMinutes(legacyTotal));
  }
  return List<String>.unmodifiable(blocks);
}

int? parseTimeMinutes(String value) {
  final parts = value.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
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
  final interval = siteConfig.slotInterval;
  if (interval <= 0) return false;
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
  return expandInternalSlots(
    start,
    durationMinutes,
  ).any((slot) => blockedKeys.contains(slot.key));
}

bool isDurationFull({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<SlotOccupancy> occupancy,
  required int maxCapacity,
}) {
  final counts = {for (final item in occupancy) item.slot.key: item.count};

  return expandInternalSlots(
    start,
    durationMinutes,
  ).any((slot) => (counts[slot.key] ?? 0) >= maxCapacity);
}

bool overlapsActiveAppointment({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<Appointment> appointments,
  String? excludedAppointmentId,
}) {
  final requestedKeys = expandInternalSlots(
    start,
    durationMinutes,
  ).map((slot) => slot.key).toSet();

  return appointments
      .where(
        (appointment) =>
            appointment.id != excludedAppointmentId &&
            (appointment.status == AppointmentStatus.pending ||
                appointment.status == AppointmentStatus.approved),
      )
      .any((appointment) {
        final slot = appointment.schedulingSlot;
        if (slot == null) return false;
        return expandInternalSlots(
          slot,
          appointment.durationMinutes,
        ).any((candidate) => requestedKeys.contains(candidate.key));
      });
}
