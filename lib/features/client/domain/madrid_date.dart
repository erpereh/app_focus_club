int madridUtcOffsetHoursAt(DateTime instant) {
  final utc = instant.toUtc();
  final dstStart = _lastSundayUtc(utc.year, 3, hour: 1);
  final dstEnd = _lastSundayUtc(utc.year, 10, hour: 1);
  if (!utc.isBefore(dstStart) && utc.isBefore(dstEnd)) {
    return 2;
  }
  return 1;
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
