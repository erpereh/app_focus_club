const int maxRecurringOccurrences = 20;
const int defaultRecurringIntervalDays = 3;

final _isoDatePrefix = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
final _exactIsoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

class RecurringEndDateOption {
  const RecurringEndDateOption({
    required this.endDate,
    required this.occurrenceCount,
    required this.totalMinutes,
  });

  final String endDate;
  final int occurrenceCount;
  final int totalMinutes;

  @override
  bool operator ==(Object other) {
    return other is RecurringEndDateOption &&
        other.endDate == endDate &&
        other.occurrenceCount == occurrenceCount &&
        other.totalMinutes == totalMinutes;
  }

  @override
  int get hashCode => Object.hash(endDate, occurrenceCount, totalMinutes);
}

enum RecurringHastaEmptyReason { noStartDate, noValidEnd }

class RecurringHastaViewModel {
  const RecurringHastaViewModel({
    required this.startDate,
    required this.options,
    required this.emptyReason,
  });

  final String? startDate;
  final List<RecurringEndDateOption> options;
  final RecurringHastaEmptyReason? emptyReason;
}

bool isIsoDate(String value) {
  if (!_exactIsoDate.hasMatch(value)) return false;
  return civilDateFromExpiration(value) == value;
}

String? civilDateFromExpiration(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final match = _isoDatePrefix.firstMatch(trimmed);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final utc = DateTime.utc(year, month, day);
  if (utc.year != year || utc.month != month || utc.day != day) {
    return null;
  }
  return _formatIsoDate(utc);
}

String addUtcDays(String dateStr, int days) {
  final parsed = civilDateFromExpiration(dateStr);
  if (parsed == null || parsed != dateStr) {
    throw ArgumentError.value(dateStr, 'dateStr', 'Expected YYYY-MM-DD.');
  }
  final parts = parsed.split('-').map(int.parse).toList(growable: false);
  return _formatIsoDate(
    DateTime.utc(parts[0], parts[1], parts[2]).add(Duration(days: days)),
  );
}

List<String> generateRecurringOccurrenceDates(
  String startDate,
  int intervalDays,
  String endDate,
) {
  if (intervalDays < 1) {
    throw ArgumentError.value(
      intervalDays,
      'intervalDays',
      'Must be an integer greater than or equal to 1.',
    );
  }
  if (!isIsoDate(startDate) || !isIsoDate(endDate)) return const [];
  if (endDate.compareTo(startDate) < 0) return const [];

  final dates = <String>[];
  var current = startDate;
  while (current.compareTo(endDate) <= 0) {
    dates.add(current);
    current = addUtcDays(current, intervalDays);
  }
  return dates;
}

List<RecurringEndDateOption> getRecurringEndDateOptions({
  required String startDate,
  required int intervalDays,
  required int durationMinutes,
  required int remainingMinutes,
  String? bonoExpirationDate,
  int maxOccurrences = maxRecurringOccurrences,
}) {
  if (!isIsoDate(startDate)) return const [];
  if (intervalDays < 1) return const [];
  if (durationMinutes != 30 &&
      durationMinutes != 45 &&
      durationMinutes != 60) {
    return const [];
  }

  final maxByMinutes = remainingMinutes < 0
      ? 0
      : remainingMinutes ~/ durationMinutes;
  final cappedMax = [
    maxOccurrences,
    maxRecurringOccurrences,
    maxByMinutes,
  ].reduce((a, b) => a < b ? a : b);
  if (cappedMax < 2) return const [];

  final expirationDate = bonoExpirationDate == null
      ? null
      : civilDateFromExpiration(bonoExpirationDate);
  final options = <RecurringEndDateOption>[];
  var current = startDate;
  for (var index = 0; index < cappedMax; index += 1) {
    if (expirationDate != null && current.compareTo(expirationDate) > 0) {
      break;
    }
    if (index >= 1) {
      options.add(
        RecurringEndDateOption(
          endDate: current,
          occurrenceCount: index + 1,
          totalMinutes: (index + 1) * durationMinutes,
        ),
      );
    }
    current = addUtcDays(current, intervalDays);
  }
  return options;
}

RecurringHastaViewModel getRecurringHastaViewModel({
  String? startDate,
  required int intervalDays,
  required int durationMinutes,
  required int remainingMinutes,
  String? bonoExpirationDate,
}) {
  final resolvedStart = startDate != null && isIsoDate(startDate)
      ? startDate
      : null;
  if (resolvedStart == null) {
    return const RecurringHastaViewModel(
      startDate: null,
      options: [],
      emptyReason: RecurringHastaEmptyReason.noStartDate,
    );
  }
  final options = getRecurringEndDateOptions(
    startDate: resolvedStart,
    intervalDays: intervalDays,
    durationMinutes: durationMinutes,
    remainingMinutes: remainingMinutes,
    bonoExpirationDate: bonoExpirationDate,
  );
  return RecurringHastaViewModel(
    startDate: resolvedStart,
    options: options,
    emptyReason: options.isEmpty ? RecurringHastaEmptyReason.noValidEnd : null,
  );
}

String? sanitizeRecurringEndDate(
  String? selectedEndDate,
  List<RecurringEndDateOption> options,
) {
  if (selectedEndDate == null || selectedEndDate.isEmpty) return null;
  return options.any((option) => option.endDate == selectedEndDate)
      ? selectedEndDate
      : null;
}

String formatIsoDateEs(String isoDate) {
  final parts = isoDate.split('-');
  if (parts.length != 3) return isoDate;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}

String formatRecurringHastaOptionLabel(RecurringEndDateOption option) {
  return '${formatIsoDateEs(option.endDate)} · ${option.occurrenceCount} sesiones · ${option.totalMinutes} min';
}

String recurringHastaEmptyMessage(RecurringHastaEmptyReason? reason) {
  return switch (reason) {
    RecurringHastaEmptyReason.noStartDate =>
      'Selecciona primero una fecha inicial.',
    RecurringHastaEmptyReason.noValidEnd =>
      'No tienes minutos o vigencia suficientes para programar al menos 2 sesiones.',
    null => '',
  };
}

String _formatIsoDate(DateTime utc) {
  final month = utc.month.toString().padLeft(2, '0');
  final day = utc.day.toString().padLeft(2, '0');
  return '${utc.year}-$month-$day';
}
