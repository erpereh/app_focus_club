import 'portal_models.dart';

const int internalSlotMinutes = 15;
const int maxCapacityPerInternalSlot = 2;

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

  final parts = start.time.split(':');
  if (parts.length != 2) {
    throw FormatException('Expected HH:mm time, got ${start.time}');
  }

  final base = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
  final count = durationMinutes ~/ internalSlotMinutes;

  return List.generate(count, (index) {
    final time = base.add(Duration(minutes: internalSlotMinutes * index));
    return TimeSlot(date: start.date, time: _formatTime(time));
  });
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
}) {
  final counts = {for (final item in occupancy) item.slot.key: item.count};

  return expandInternalSlots(
    start,
    durationMinutes,
  ).any((slot) => (counts[slot.key] ?? 0) >= maxCapacityPerInternalSlot);
}

bool overlapsActiveAppointment({
  required TimeSlot start,
  required int durationMinutes,
  required Iterable<Appointment> appointments,
}) {
  final requestedKeys = expandInternalSlots(
    start,
    durationMinutes,
  ).map((slot) => slot.key).toSet();

  return appointments
      .where(
        (appointment) =>
            appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.approved,
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

String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
