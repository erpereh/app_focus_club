import 'package:app_focus_club/features/client/domain/madrid_date.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _config = SiteConfig(
  startHour: 8,
  endHour: 20,
  slotInterval: 30,
  bonoExpirationMonths: 1,
  maintenanceMode: false,
  maxCapacity: 4,
);

// Monday 5 Oct 2026, 10:00 in Madrid (CEST, UTC+2).
final _now = DateTime.utc(2026, 10, 5, 8);

BookingSlotState _state(
  String date,
  String time, {
  required int notice,
  DateTime? now,
}) {
  return bookingSlotState(
    slot: TimeSlot(date: date, time: time),
    durationMinutes: 30,
    siteConfig: _config,
    blockedSlots: const [],
    occupancy: const [],
    appointments: const [],
    minNoticeHours: notice,
    now: now ?? _now,
  );
}

void main() {
  group('SiteConfig.minBookingNoticeHours', () {
    test('missing field means 0', () {
      final config = SiteConfig.fromMap(const {
        'startHour': 8,
        'endHour': 20,
        'slotInterval': 30,
        'bonoExpirationMonths': 1,
      });
      expect(config.minBookingNoticeHours, 0);
    });

    test('tolerant parsing', () {
      expect(parseBookingNoticeHours(null), 0);
      expect(parseBookingNoticeHours(-4), 0);
      expect(parseBookingNoticeHours('abc'), 0);
      expect(parseBookingNoticeHours('24'), 24);
      expect(parseBookingNoticeHours(12.8), 12);
      expect(parseBookingNoticeHours(99999), maxMinBookingNoticeHours);
    });
  });

  group('isInsideBookingNotice', () {
    test('0h allows any future slot', () {
      expect(
        isInsideBookingNotice(
          date: '2026-10-05',
          time: '10:30',
          now: _now,
          hours: 0,
        ),
        isFalse,
      );
    });

    test('24h blocks +23:59 and allows +24:00 or later', () {
      expect(
        isInsideBookingNotice(
          date: '2026-10-06',
          time: '09:59',
          now: _now,
          hours: 24,
        ),
        isTrue,
      );
      expect(
        isInsideBookingNotice(
          date: '2026-10-06',
          time: '10:00',
          now: _now,
          hours: 24,
        ),
        isFalse,
      );
      expect(
        isInsideBookingNotice(
          date: '2026-10-06',
          time: '12:00',
          now: _now,
          hours: 24,
        ),
        isFalse,
      );
    });

    test('day and month change', () {
      // 31 Oct 22:00 Madrid (CET) = 21:00Z; +24h = 1 Nov 22:00 Madrid.
      final now = DateTime.utc(2026, 10, 31, 21);
      expect(
        isInsideBookingNotice(
          date: '2026-11-01',
          time: '21:59',
          now: now,
          hours: 24,
        ),
        isTrue,
      );
      expect(
        isInsideBookingNotice(
          date: '2026-11-01',
          time: '22:00',
          now: now,
          hours: 24,
        ),
        isFalse,
      );
    });

    test('Madrid DST change uses real hours', () {
      // 24 Oct 12:00 Madrid (CEST) = 10:00Z; +24h = 25 Oct 10:00Z = 11:00 CET.
      final now = DateTime.utc(2026, 10, 24, 10);
      bool inside(String time) => isInsideBookingNotice(
        date: '2026-10-25',
        time: time,
        now: now,
        hours: 24,
      );
      expect(inside('10:30'), isTrue);
      expect(inside('10:59'), isTrue);
      expect(inside('11:00'), isFalse);
      expect(inside('12:00'), isFalse);
    });
  });

  group('bookingSlotState with notice', () {
    test('0h allows booking normally', () {
      expect(_state('2026-10-05', '11:00', notice: 0).isEnabled, isTrue);
    });

    test('24h greys out slots inside the notice as "No disponible"', () {
      final blocked = _state('2026-10-06', '09:30', notice: 24);
      expect(blocked.isEnabled, isFalse);
      expect(blocked.label, 'No disponible');
      expect(_state('2026-10-06', '10:00', notice: 24).isEnabled, isTrue);
    });

    test('DST: the 11:00 civil slot after the change is bookable', () {
      final now = DateTime.utc(2026, 10, 24, 10);
      expect(
        _state('2026-10-25', '10:30', notice: 24, now: now).isEnabled,
        isFalse,
      );
      expect(
        _state('2026-10-25', '11:00', notice: 24, now: now).isEnabled,
        isTrue,
      );
    });
  });

  group('effectiveBookingNoticeHours', () {
    test('new bookings use the configured value', () {
      expect(effectiveBookingNoticeHours(24, isModification: false), 24);
      expect(effectiveBookingNoticeHours(0, isModification: false), 0);
    });

    test('modifications respect max(24h, notice) on top of the fixed lock', () {
      expect(effectiveBookingNoticeHours(12, isModification: true), 0);
      expect(effectiveBookingNoticeHours(24, isModification: true), 0);
      expect(effectiveBookingNoticeHours(48, isModification: true), 48);
    });
  });
}
