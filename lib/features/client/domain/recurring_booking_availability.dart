import 'portal_availability.dart';
import 'portal_models.dart';
import 'recurring_booking.dart';
import 'madrid_date.dart';

enum RecurringHastaAvailability {
  available,
  blocked,
  full,
  conflict,
  outsideSchedule,
  past,
}

enum RecurringHastaAvailabilityPhase { idle, loading, ready, error }

class RecurringAvailabilitySnapshot {
  const RecurringAvailabilitySnapshot({
    this.occupancy = const [],
    this.blockedSlots = const [],
  });

  final List<SlotOccupancy> occupancy;
  final List<BlockedSlot> blockedSlots;

  Map<String, int> get occupancyByKey => {
    for (final item in occupancy) item.slot.key: item.count,
  };

  Set<String> get blockedKeys => {
    for (final item in blockedSlots) item.slot.key,
  };
}

class RecurringHastaOptionStatus {
  const RecurringHastaOptionStatus({
    required this.option,
    required this.availability,
    this.problemDate,
    this.problemTime,
    this.message,
  });

  final RecurringEndDateOption option;
  final RecurringHastaAvailability availability;
  final String? problemDate;
  final String? problemTime;
  final String? message;

  bool get isAvailable => availability == RecurringHastaAvailability.available;

  @override
  bool operator ==(Object other) {
    return other is RecurringHastaOptionStatus &&
        other.option == option &&
        other.availability == availability &&
        other.problemDate == problemDate &&
        other.problemTime == problemTime &&
        other.message == message;
  }

  @override
  int get hashCode =>
      Object.hash(option, availability, problemDate, problemTime, message);
}

class _OccurrenceProblem {
  const _OccurrenceProblem({
    required this.availability,
    required this.problemDate,
    required this.problemTime,
    required this.message,
  });

  final RecurringHastaAvailability availability;
  final String problemDate;
  final String problemTime;
  final String message;
}

String _formatDateShort(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  return '${parts[2]}/${parts[1]}';
}

_OccurrenceProblem? _evaluateRecurringOccurrence({
  required String date,
  required String startTime,
  required int durationMinutes,
  required Map<String, int> occupancy,
  required Set<String> blockedKeys,
  required Iterable<Appointment> appointments,
  required Set<String> excludedAppointmentIds,
  required Map<String, int> occupancyCreditsByKey,
  required bool enforceRescheduleLeadTime,
  required SiteConfig siteConfig,
  required DateTime now,
}) {
  final slot = TimeSlot(date: date, time: startTime);
  final slotDateTime = madridCivilSlotToUtc(date: date, time: startTime);
  final dateShort = _formatDateShort(date);
  final dateEs = formatIsoDateEs(date);

  if (slotDateTime == null || !slotDateTime.isAfter(now.toUtc())) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.past,
      problemDate: date,
      problemTime: startTime,
      message:
          'La franja del $dateShort a las $startTime ya no está disponible.',
    );
  }

  if (enforceRescheduleLeadTime &&
      isInsideCustomerRescheduleLockWindow(
        date: date,
        time: startTime,
        now: now,
      )) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.past,
      problemDate: date,
      problemTime: startTime,
      message: 'La sesión del $dateShort comienza dentro de 24 horas.',
    );
  }

  if (!isGeneratedScheduleTime(time: startTime, siteConfig: siteConfig) ||
      !doesDurationFitInSchedule(
        slot: slot,
        durationMinutes: durationMinutes,
        siteConfig: siteConfig,
      )) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.outsideSchedule,
      problemDate: date,
      problemTime: startTime,
      message:
          'La franja del $dateShort no es válida para el horario configurado.',
    );
  }

  final availabilityKeys = availabilityKeysForSlot(slot, durationMinutes);

  if (availabilityKeys.any(blockedKeys.contains)) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.blocked,
      problemDate: date,
      problemTime: startTime,
      message: 'La sesión del $dateShort está bloqueada.',
    );
  }

  if (overlapsActiveAppointment(
    start: slot,
    durationMinutes: durationMinutes,
    appointments: appointments,
    excludedAppointmentIds: excludedAppointmentIds,
  )) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.conflict,
      problemDate: date,
      problemTime: startTime,
      message: 'Ya tienes una sesión que se solapa el $dateEs.',
    );
  }

  final maxCapacity = siteConfig.maxCapacity;
  final effectiveOccupancy = availabilityKeys.fold<int>(0, (maximum, key) {
    final count = ((occupancy[key] ?? 0) - (occupancyCreditsByKey[key] ?? 0))
        .clamp(0, 1 << 30);
    return count > maximum ? count : maximum;
  });
  if (effectiveOccupancy >= maxCapacity) {
    return _OccurrenceProblem(
      availability: RecurringHastaAvailability.full,
      problemDate: date,
      problemTime: startTime,
      message: 'Franja completa el $dateShort',
    );
  }

  return null;
}

List<RecurringHastaOptionStatus> evaluateRecurringHastaOptions({
  required String startDate,
  required String startTime,
  required int intervalDays,
  required int durationMinutes,
  required List<RecurringEndDateOption> options,
  required Map<String, int> occupancy,
  required Set<String> blockedKeys,
  required Iterable<Appointment> appointments,
  Set<String> excludedAppointmentIds = const {},
  Map<String, int> occupancyCreditsByKey = const {},
  bool enforceRescheduleLeadTime = false,
  required SiteConfig siteConfig,
  required DateTime now,
}) {
  _OccurrenceProblem? firstProblem;
  final checkedDates = <String>{};

  return options
      .map((option) {
        if (firstProblem == null) {
          final dates = generateRecurringOccurrenceDates(
            startDate,
            intervalDays,
            option.endDate,
          );
          for (final date in dates) {
            if (checkedDates.contains(date)) continue;
            checkedDates.add(date);
            firstProblem = _evaluateRecurringOccurrence(
              date: date,
              startTime: startTime,
              durationMinutes: durationMinutes,
              occupancy: occupancy,
              blockedKeys: blockedKeys,
              appointments: appointments,
              excludedAppointmentIds: excludedAppointmentIds,
              occupancyCreditsByKey: occupancyCreditsByKey,
              enforceRescheduleLeadTime: enforceRescheduleLeadTime,
              siteConfig: siteConfig,
              now: now,
            );
            if (firstProblem != null) break;
          }
        }

        final problem = firstProblem;
        if (problem == null) {
          return RecurringHastaOptionStatus(
            option: option,
            availability: RecurringHastaAvailability.available,
          );
        }
        return RecurringHastaOptionStatus(
          option: option,
          availability: problem.availability,
          problemDate: problem.problemDate,
          problemTime: problem.problemTime,
          message: problem.message,
        );
      })
      .toList(growable: false);
}

String? sanitizeRecurringEndDateByAvailability({
  required String? selectedEndDate,
  required List<RecurringHastaOptionStatus> statuses,
  required RecurringHastaAvailabilityPhase phase,
}) {
  if (selectedEndDate == null || selectedEndDate.isEmpty) return null;
  if (phase != RecurringHastaAvailabilityPhase.ready) return selectedEndDate;
  final status = statuses
      .where((item) => item.option.endDate == selectedEndDate)
      .firstOrNull;
  if (status == null || !status.isAvailable) return null;
  return selectedEndDate;
}
