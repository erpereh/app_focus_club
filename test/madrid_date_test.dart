import 'package:app_focus_club/features/client/domain/madrid_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('madridUtcOffsetHoursAt', () {
    test('uses CET UTC+1 in winter', () {
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 1, 15, 12)), 1);
    });

    test('uses CEST UTC+2 in summer', () {
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 7, 15, 12)), 2);
    });

    test('switches to CEST at the last Sunday of March 01:00 UTC', () {
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 3, 29, 0, 59)), 1);
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 3, 29, 1)), 2);
    });

    test('switches to CET at the last Sunday of October 01:00 UTC', () {
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 10, 25, 0, 59)), 2);
      expect(madridUtcOffsetHoursAt(DateTime.utc(2026, 10, 25, 1)), 1);
    });
  });

  group('getMadridDateKey', () {
    test('keeps the UTC calendar day in winter', () {
      expect(getMadridDateKey(DateTime.utc(2026, 1, 15, 12)), '2026-01-15');
    });

    test('keeps the UTC calendar day in summer', () {
      expect(getMadridDateKey(DateTime.utc(2026, 7, 15, 12)), '2026-07-15');
    });

    test('rolls to the next Madrid day while UTC is still yesterday', () {
      expect(getMadridDateKey(DateTime.utc(2026, 7, 15, 22, 30)), '2026-07-16');
    });

    test('normalizes a local DateTime through toUtc', () {
      final local = DateTime.utc(2026, 7, 15, 22, 30).toLocal();
      expect(getMadridDateKey(local), '2026-07-16');
    });
  });

  group('isDateKeyTodayInMadrid', () {
    final now = DateTime.utc(2026, 9, 2, 10);

    test('is true for the Madrid civil date', () {
      expect(isDateKeyTodayInMadrid('2026-09-02', now), isTrue);
    });

    test('is false for another civil date', () {
      expect(isDateKeyTodayInMadrid('2026-09-03', now), isFalse);
      expect(isDateKeyTodayInMadrid('2026-09-01', now), isFalse);
    });
  });

  group('nextMadridMidnightUtc', () {
    test('uses CEST when the next midnight is in summer', () {
      final now = DateTime.utc(2026, 7, 15, 21, 30);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 7, 15, 22));
    });

    test('uses CET when the next midnight is in winter', () {
      final now = DateTime.utc(2026, 1, 15, 22, 30);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 1, 15, 23));
    });

    test('DST start Saturday schedules Sunday 00:00 CET', () {
      final now = DateTime.utc(2026, 3, 28, 12);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 3, 28, 23));
    });

    test('DST start Sunday schedules Monday 00:00 CEST', () {
      final now = DateTime.utc(2026, 3, 29, 12);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 3, 29, 22));
    });

    test('DST end Saturday schedules Sunday 00:00 CEST', () {
      final now = DateTime.utc(2026, 10, 24, 12);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 10, 24, 22));
    });

    test('DST end Sunday schedules Monday 00:00 CET', () {
      final now = DateTime.utc(2026, 10, 25, 12);
      expect(nextMadridMidnightUtc(now), DateTime.utc(2026, 10, 25, 23));
    });
  });
}
