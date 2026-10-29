import 'dart:async';

import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking_availability.dart';
import 'package:flutter_test/flutter_test.dart';

/// Aforo por fecha: `capacity_exceptions/{date}` replaces the global capacity
/// of that day. The server decides; the app shows the same value.
void main() {
  const siteConfig = SiteConfig(
    startHour: 8,
    endHour: 20,
    slotInterval: 30,
    bonoExpirationMonths: 1,
    maintenanceMode: false,
    maxCapacity: 4,
  );
  final now = DateTime.utc(2026, 9, 20, 8);

  List<SlotOccupancy> hourAt(String date, String hour, int count) => [
    for (final minutes in ['00', '15', '30', '45'])
      SlotOccupancy(
        id: '${date}_$hour:$minutes',
        date: date,
        time: '$hour:$minutes',
        count: count,
      ),
  ];

  group('CapacityException', () {
    test('parses valid documents and clamps them like the global value', () {
      final parsed = CapacityException.tryFromMap('2026-09-23', {
        'date': '2026-09-23',
        'maxCapacity': 2,
      });
      expect(parsed?.date, '2026-09-23');
      expect(parsed?.maxCapacity, 2);
      expect(
        CapacityException.tryFromMap('2026-09-23', {
          'maxCapacity': 40,
        })?.maxCapacity,
        10,
      );
      expect(
        CapacityException.tryFromMap('2026-09-23', {
          'maxCapacity': '3',
        })?.maxCapacity,
        3,
      );
    });

    test('ignores unusable documents instead of throwing', () {
      expect(CapacityException.tryFromMap('2026-09-23', {}), isNull);
      expect(
        CapacityException.tryFromMap('2026-09-23', {'maxCapacity': 'dos'}),
        isNull,
      );
      expect(CapacityException.tryFromMap('main', {'maxCapacity': 2}), isNull);
      expect(
        CapacityException.tryFromMap('2026-09-23', {'maxCapacity': double.nan}),
        isNull,
      );
    });

    test('a date without exception uses the global capacity', () {
      const byDate = {'2026-09-23': 2, '2026-09-24': 6};
      expect(effectiveMaxCapacity(siteConfig, byDate, '2026-09-23'), 2);
      expect(effectiveMaxCapacity(siteConfig, byDate, '2026-09-24'), 6);
      expect(effectiveMaxCapacity(siteConfig, byDate, '2026-09-25'), 4);
    });
  });

  group('slot grid', () {
    BookingSlotState stateAt(
      String date,
      List<SlotOccupancy> occupancy,
      Map<String, int> capacityByDate,
    ) {
      return bookingSlotState(
        slot: TimeSlot(date: date, time: '10:00'),
        durationMinutes: 60,
        siteConfig: siteConfig,
        blockedSlots: const [],
        occupancy: occupancy,
        appointments: const [],
        capacityByDate: capacityByDate,
        now: now,
      );
    }

    test('a reduced day is full at its own capacity', () {
      final reduced = stateAt('2026-09-23', hourAt('2026-09-23', '10', 2), {
        '2026-09-23': 2,
      });
      expect(reduced.availability, BookingSlotAvailability.full);
      expect(reduced.maxCapacity, 2);
      expect(reduced.label, 'Completo');

      final regular = stateAt('2026-09-24', hourAt('2026-09-24', '10', 2), {
        '2026-09-23': 2,
      });
      expect(regular.availability, BookingSlotAvailability.partial);
      expect(regular.label, '2 plazas');
    });

    test('a raised day keeps seats over the global capacity', () {
      final raised = stateAt('2026-09-23', hourAt('2026-09-23', '10', 5), {
        '2026-09-23': 6,
      });
      expect(raised.availability, BookingSlotAvailability.almostFull);
      expect(raised.remaining, 1);
      expect(raised.maxCapacity, 6);
    });

    test('without exceptions it behaves exactly as before', () {
      final state = stateAt('2026-09-23', hourAt('2026-09-23', '10', 4), {});
      expect(state.availability, BookingSlotAvailability.full);
      expect(state.maxCapacity, 4);
    });
  });

  test('recurring options stop at the occurrence of a reduced day', () {
    final options = getRecurringEndDateOptions(
      startDate: '2026-09-23',
      intervalDays: 2,
      durationMinutes: 60,
      remainingMinutes: 240,
    );
    List<RecurringHastaOptionStatus> evaluate(Map<String, int> byDate) =>
        evaluateRecurringHastaOptions(
          startDate: '2026-09-23',
          startTime: '11:00',
          intervalDays: 2,
          durationMinutes: 60,
          options: options,
          occupancy: const {'2026-09-27_11:00': 2},
          blockedKeys: const {},
          appointments: const [],
          siteConfig: siteConfig,
          capacityByDate: byDate,
          now: now,
        );

    expect(evaluate(const {}).every((item) => item.isAvailable), isTrue);
    final reduced = evaluate(const {'2026-09-27': 2});
    expect(reduced[0].availability, RecurringHastaAvailability.available);
    expect(reduced[1].availability, RecurringHastaAvailability.full);
    expect(reduced[1].problemDate, '2026-09-27');
  });

  group('view model', () {
    test('keeps the exceptions of the booking window live', () async {
      final repository = FakePortalRepository(
        siteConfig: siteConfig,
        capacityExceptions: const [
          CapacityException(date: '2026-09-23', maxCapacity: 2),
        ],
      );
      final viewModel = ClientPortalViewModel(
        repository: repository,
        uid: 'uid',
        now: () => now,
      )..start();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      expect(viewModel.state.capacityByDate, {'2026-09-23': 2});

      repository.emitCapacityExceptions(const [
        CapacityException(date: '2026-09-24', maxCapacity: 3),
      ]);
      await pumpEventQueue();
      expect(viewModel.state.capacityByDate, {'2026-09-24': 3});
    });

    test('a failure reading exceptions never breaks the portal', () async {
      final viewModel = ClientPortalViewModel(
        repository: _FailingCapacityRepository(siteConfig: siteConfig),
        uid: 'uid',
        now: () => now,
      )..start();
      addTearDown(viewModel.dispose);
      await pumpEventQueue();
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.capacityByDate, isEmpty);
      expect(viewModel.state.siteConfig?.maxCapacity, 4);
    });

    test(
      'recurring availability includes the exceptions of its dates',
      () async {
        final repository = FakePortalRepository(
          capacityExceptions: const [
            CapacityException(date: '2026-09-23', maxCapacity: 2),
            CapacityException(date: '2026-10-30', maxCapacity: 5),
          ],
        );
        final snapshot = await repository.getAvailabilityForDates([
          '2026-09-23',
          '2026-09-25',
        ]);
        expect(snapshot.capacityByDate, {'2026-09-23': 2});
      },
    );
  });
}

class _FailingCapacityRepository extends FakePortalRepository {
  _FailingCapacityRepository({super.siteConfig});

  @override
  Stream<List<CapacityException>> watchCapacityExceptionsForRange({
    required String startDate,
    required String endDate,
  }) => Stream.error(StateError('permission-denied'));
}
