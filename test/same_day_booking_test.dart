import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/madrid_date.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking_availability.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
  bool blockSameDay = false,
  int notice = 0,
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
    blockSameDay: blockSameDay,
    now: now ?? _now,
  );
}

void main() {
  group('SiteConfig.blockSameDayBooking', () {
    test('missing or non-boolean values keep same-day booking allowed', () {
      const base = {
        'startHour': 8,
        'endHour': 20,
        'slotInterval': 30,
        'bonoExpirationMonths': 1,
      };
      expect(SiteConfig.fromMap(base).blockSameDayBooking, isFalse);
      expect(
        SiteConfig.fromMap({
          ...base,
          'blockSameDayBooking': 'true',
        }).blockSameDayBooking,
        isFalse,
      );
      expect(
        SiteConfig.fromMap({
          ...base,
          'blockSameDayBooking': true,
        }).blockSameDayBooking,
        isTrue,
      );
      expect(_config.blockSameDayBooking, isFalse);
    });
  });

  group('isSameDayBookingBlocked', () {
    test('blocks any time today only when enabled', () {
      expect(
        isSameDayBookingBlocked(date: '2026-10-05', now: _now, enabled: true),
        isTrue,
      );
      expect(
        isSameDayBookingBlocked(date: '2026-10-06', now: _now, enabled: true),
        isFalse,
      );
      expect(
        isSameDayBookingBlocked(date: '2026-10-05', now: _now, enabled: false),
        isFalse,
      );
    });

    test('midnight boundary follows the Madrid calendar day', () {
      // 23:59 Madrid (CEST) = 21:59Z.
      final beforeMidnight = DateTime.utc(2026, 10, 5, 21, 59);
      expect(
        isSameDayBookingBlocked(
          date: '2026-10-05',
          now: beforeMidnight,
          enabled: true,
        ),
        isTrue,
      );
      expect(
        isSameDayBookingBlocked(
          date: '2026-10-06',
          now: beforeMidnight,
          enabled: true,
        ),
        isFalse,
      );
      // 00:00 Madrid on the 6th = 22:00Z on the 5th.
      final atMidnight = DateTime.utc(2026, 10, 5, 22);
      expect(
        isSameDayBookingBlocked(
          date: '2026-10-06',
          now: atMidnight,
          enabled: true,
        ),
        isTrue,
      );
      // Winter (CET): 00:30 Madrid on 2 Nov = 23:30Z on 1 Nov.
      final winter = DateTime.utc(2026, 11, 1, 23, 30);
      expect(
        isSameDayBookingBlocked(date: '2026-11-02', now: winter, enabled: true),
        isTrue,
      );
    });
  });

  group('bookingSlotState', () {
    test('future slots today are "No disponible" with their own state', () {
      final tonight = _state('2026-10-05', '19:00', blockSameDay: true);
      expect(tonight.isEnabled, isFalse);
      expect(tonight.label, 'No disponible');
      expect(tonight.availability, BookingSlotAvailability.sameDayBlocked);
      expect(
        _state('2026-10-05', '09:00', blockSameDay: true).availability,
        BookingSlotAvailability.past,
        reason: 'past stays past',
      );
      expect(
        _state('2026-10-06', '08:00', blockSameDay: true).isEnabled,
        isTrue,
      );
      expect(
        _state('2026-10-05', '19:00').isEnabled,
        isTrue,
        reason: 'flag off',
      );
    });

    test('same-day and notice apply independently', () {
      expect(
        _state(
          '2026-10-05',
          '19:00',
          blockSameDay: true,
          notice: 1,
        ).availability,
        BookingSlotAvailability.sameDayBlocked,
      );
      expect(
        _state(
          '2026-10-06',
          '09:30',
          blockSameDay: true,
          notice: 24,
        ).availability,
        BookingSlotAvailability.noticeTooShort,
        reason: 'the notice keeps its own reason instead of "unavailable"',
      );
      expect(
        _state('2026-10-06', '10:00', blockSameDay: true, notice: 24).isEnabled,
        isTrue,
      );
    });
  });

  group('recurring preview', () {
    final options = getRecurringEndDateOptions(
      startDate: '2026-10-05',
      intervalDays: 7,
      durationMinutes: 60,
      remainingMinutes: 240,
    );

    List<RecurringHastaOptionStatus> evaluate({
      bool blockSameDay = false,
      int notice = 0,
    }) {
      return evaluateRecurringHastaOptions(
        startDate: '2026-10-05',
        startTime: '18:00',
        intervalDays: 7,
        durationMinutes: 60,
        options: options,
        occupancy: const {},
        blockedKeys: const {},
        appointments: const [],
        minNoticeHours: notice,
        blockSameDay: blockSameDay,
        siteConfig: _config,
        now: _now,
      );
    }

    test(
      'a series that starts today is rejected entirely, naming the date',
      () {
        final statuses = evaluate(blockSameDay: true);
        expect(statuses, isNotEmpty);
        for (final status in statuses) {
          expect(
            status.availability,
            RecurringHastaAvailability.sameDayBlocked,
          );
          expect(status.problemDate, '2026-10-05');
          expect(status.problemTime, '18:00');
          expect(status.message, contains('05/10'));
        }
      },
    );

    test('flag off keeps the legacy behaviour', () {
      expect(evaluate().every((status) => status.isAvailable), isTrue);
    });

    test('the notice is reported as noticeTooShort, not past', () {
      expect(
        evaluate(notice: 24).first.availability,
        RecurringHastaAvailability.noticeTooShort,
      );
    });
  });

  group('server errors', () {
    test('same_day_booking_disabled shows the server message (with date)', () {
      final error = FirebaseFunctionsException(
        code: 'failed-precondition',
        message:
            'La serie incluye una cita para hoy (05/10/2026 a las 18:00) y no se permiten reservas para el mismo dia.',
        details: const {
          'reason': 'same_day_booking_disabled',
          'date': '2026-10-05',
          'time': '18:00',
        },
      );
      expect(appointmentRequestErrorMessage(error), contains('05/10/2026'));
    });

    test('falls back to the generic same-day message', () {
      final error = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: '',
        details: const {'reason': 'same_day_booking_disabled'},
      );
      expect(
        appointmentRequestErrorMessage(error),
        sameDayBookingDisabledMessage,
      );
    });
  });
}
