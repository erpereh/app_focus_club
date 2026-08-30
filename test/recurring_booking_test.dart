import 'package:app_focus_club/features/client/domain/recurring_booking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('civilDateFromExpiration', () {
    test('keeps a civil YYYY-MM-DD date', () {
      expect(civilDateFromExpiration('2026-10-31'), '2026-10-31');
    });

    test('extracts the civil date from a full ISO timestamp without shifting', () {
      expect(
        civilDateFromExpiration('2026-10-31T23:59:59.000Z'),
        '2026-10-31',
      );
    });

    test('rejects impossible calendar dates', () {
      expect(civilDateFromExpiration('2026-13-99'), isNull);
    });

    test('rejects arbitrary text', () {
      expect(civilDateFromExpiration('texto cualquiera'), isNull);
    });
  });

  group('generateRecurringOccurrenceDates', () {
    test('creates every-3-days dates from 10/09 through 19/09', () {
      expect(
        generateRecurringOccurrenceDates('2026-09-10', 3, '2026-09-19'),
        ['2026-09-10', '2026-09-13', '2026-09-16', '2026-09-19'],
      );
    });

    test('creates consecutive daily dates', () {
      expect(
        generateRecurringOccurrenceDates('2026-09-10', 1, '2026-09-12'),
        ['2026-09-10', '2026-09-11', '2026-09-12'],
      );
    });

    test('creates weekly dates with intervalDays 7', () {
      expect(
        generateRecurringOccurrenceDates('2026-09-07', 7, '2026-09-28'),
        ['2026-09-07', '2026-09-14', '2026-09-21', '2026-09-28'],
      );
    });

    test('throws when intervalDays is 0', () {
      expect(
        () => generateRecurringOccurrenceDates('2026-09-10', 0, '2026-09-19'),
        throwsArgumentError,
      );
    });
  });

  group('getRecurringEndDateOptions', () {
    test('offers Hasta 13/16/19 for 240 min every 3 days from 10/09', () {
      expect(
        getRecurringEndDateOptions(
          startDate: '2026-09-10',
          intervalDays: 3,
          durationMinutes: 60,
          remainingMinutes: 240,
        ),
        [
          const RecurringEndDateOption(
            endDate: '2026-09-13',
            occurrenceCount: 2,
            totalMinutes: 120,
          ),
          const RecurringEndDateOption(
            endDate: '2026-09-16',
            occurrenceCount: 3,
            totalMinutes: 180,
          ),
          const RecurringEndDateOption(
            endDate: '2026-09-19',
            occurrenceCount: 4,
            totalMinutes: 240,
          ),
        ],
      );
    });

    test('returns no recurring options when remaining minutes cover one session', () {
      expect(
        getRecurringEndDateOptions(
          startDate: '2026-09-10',
          intervalDays: 3,
          durationMinutes: 60,
          remainingMinutes: 60,
        ),
        isEmpty,
      );
    });

    test('caps Hasta at bono expiration including the same day', () {
      expect(
        getRecurringEndDateOptions(
          startDate: '2026-09-10',
          intervalDays: 3,
          durationMinutes: 60,
          remainingMinutes: 240,
          bonoExpirationDate: '2026-09-16',
        ),
        [
          const RecurringEndDateOption(
            endDate: '2026-09-13',
            occurrenceCount: 2,
            totalMinutes: 120,
          ),
          const RecurringEndDateOption(
            endDate: '2026-09-16',
            occurrenceCount: 3,
            totalMinutes: 180,
          ),
        ],
      );
    });

    test('caps Hasta at a maximum of 20 occurrences', () {
      final options = getRecurringEndDateOptions(
        startDate: '2026-09-10',
        intervalDays: 1,
        durationMinutes: 30,
        remainingMinutes: 30 * 50,
      );
      expect(options, hasLength(19));
      expect(options.last.occurrenceCount, 20);
      expect(options.last.endDate, '2026-09-29');
    });
  });

  group('sanitizeRecurringEndDate', () {
    test('keeps an endDate that is still a valid option', () {
      final options = getRecurringEndDateOptions(
        startDate: '2026-09-08',
        intervalDays: 7,
        durationMinutes: 30,
        remainingMinutes: 360,
        bonoExpirationDate: '2026-10-31',
      );
      expect(sanitizeRecurringEndDate('2026-09-29', options), '2026-09-29');
    });

    test('clears an obsolete endDate when intervalDays changes', () {
      final everyTenDays = getRecurringEndDateOptions(
        startDate: '2026-09-08',
        intervalDays: 10,
        durationMinutes: 30,
        remainingMinutes: 360,
        bonoExpirationDate: '2026-10-31',
      );
      expect(everyTenDays.any((option) => option.endDate == '2026-09-29'), isFalse);
      expect(sanitizeRecurringEndDate('2026-09-29', everyTenDays), isNull);
    });
  });

  group('getRecurringHastaViewModel', () {
    test('explains when no start date is selected', () {
      expect(
        getRecurringHastaViewModel(
          startDate: null,
          intervalDays: 3,
          durationMinutes: 60,
          remainingMinutes: 240,
        ).emptyReason,
        RecurringHastaEmptyReason.noStartDate,
      );
    });

    test('explains when minutes cannot cover two sessions', () {
      expect(
        getRecurringHastaViewModel(
          startDate: '2026-09-10',
          intervalDays: 3,
          durationMinutes: 60,
          remainingMinutes: 60,
        ).emptyReason,
        RecurringHastaEmptyReason.noValidEnd,
      );
    });
  });
}
