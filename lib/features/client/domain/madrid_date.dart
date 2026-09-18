int madridUtcOffsetHoursAt(DateTime instant) {
  final utc = instant.toUtc();
  final dstStart = _lastSundayUtc(utc.year, 3, hour: 1);
  final dstEnd = _lastSundayUtc(utc.year, 10, hour: 1);
  if (!utc.isBefore(dstStart) && utc.isBefore(dstEnd)) {
    return 2;
  }
  return 1;
}

const customerRescheduleLockWindow = Duration(hours: 24);

/// Resolves a Europe/Madrid civil date and time to a real UTC instant.
///
/// Non-existent DST wall times are invalid. Repeated wall times resolve to
/// their earliest real instant, matching the production backend.
DateTime? madridCivilSlotToUtc({required String date, required String time}) {
  final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
  final timeMatch = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(time);
  if (dateMatch == null || timeMatch == null) return null;

  final year = int.parse(dateMatch.group(1)!);
  final month = int.parse(dateMatch.group(2)!);
  final day = int.parse(dateMatch.group(3)!);
  final hour = int.parse(timeMatch.group(1)!);
  final minute = int.parse(timeMatch.group(2)!);
  if (month < 1 || month > 12 || hour > 23 || minute > 59) return null;

  final civilAsUtc = DateTime.utc(year, month, day, hour, minute);
  if (civilAsUtc.year != year ||
      civilAsUtc.month != month ||
      civilAsUtc.day != day) {
    return null;
  }

  final candidates = <DateTime>[];
  for (final offsetHours in const [1, 2]) {
    final candidate = civilAsUtc.subtract(Duration(hours: offsetHours));
    final madrid = candidate.add(
      Duration(hours: madridUtcOffsetHoursAt(candidate)),
    );
    if (madrid.year == year &&
        madrid.month == month &&
        madrid.day == day &&
        madrid.hour == hour &&
        madrid.minute == minute) {
      candidates.add(candidate);
    }
  }
  candidates.sort();
  return candidates.firstOrNull;
}

bool isMadridSlotFuture({
  required String date,
  required String time,
  required DateTime now,
}) {
  final instant = madridCivilSlotToUtc(date: date, time: time);
  return instant?.isAfter(now.toUtc()) ?? false;
}

/// Inclusive real-time lock. Invalid slots fail closed.
bool isInsideCustomerRescheduleLockWindow({
  required String date,
  required String time,
  required DateTime now,
}) {
  final instant = madridCivilSlotToUtc(date: date, time: time);
  if (instant == null) return true;
  return instant.difference(now.toUtc()) <= customerRescheduleLockWindow;
}

String getMadridDateKey(DateTime now) {
  final utc = now.toUtc();
  final madrid = utc.add(Duration(hours: madridUtcOffsetHoursAt(utc)));
  return _dateKey(madrid.year, madrid.month, madrid.day);
}

bool isDateKeyTodayInMadrid(String dateKey, DateTime now) {
  return dateKey == getMadridDateKey(now);
}

DateTime nextMadridMidnightUtc(DateTime now) {
  final todayKey = getMadridDateKey(now);
  final parts = todayKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  final day = int.parse(parts[2]);
  final nextCivil = DateTime.utc(year, month, day).add(const Duration(days: 1));
  return _madridLocalToUtc(
    year: nextCivil.year,
    month: nextCivil.month,
    day: nextCivil.day,
  );
}

DateTime _madridLocalToUtc({
  required int year,
  required int month,
  required int day,
  int hour = 0,
  int minute = 0,
}) {
  final localAsUtcNumbers = DateTime.utc(year, month, day, hour, minute);
  final cetGuess = localAsUtcNumbers.subtract(const Duration(hours: 1));
  if (madridUtcOffsetHoursAt(cetGuess) == 1) {
    return cetGuess;
  }
  return localAsUtcNumbers.subtract(const Duration(hours: 2));
}

DateTime _lastSundayUtc(int year, int month, {required int hour}) {
  final firstOfNext = month == 12
      ? DateTime.utc(year + 1, 1, 1)
      : DateTime.utc(year, month + 1, 1);
  var cursor = firstOfNext.subtract(const Duration(days: 1));
  while (cursor.weekday != DateTime.sunday) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return DateTime.utc(cursor.year, cursor.month, cursor.day, hour);
}

String _dateKey(int year, int month, int day) {
  final monthText = month.toString().padLeft(2, '0');
  final dayText = day.toString().padLeft(2, '0');
  return '$year-$monthText-$dayText';
}
