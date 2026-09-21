import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeSlotInterval', () {
    test('keeps supported intervals', () {
      expect(normalizeSlotInterval(15), 15);
      expect(normalizeSlotInterval(30), 30);
      expect(normalizeSlotInterval(45), 45);
      expect(normalizeSlotInterval(60), 60);
    });

    test('falls back to 30 for unsupported values', () {
      expect(normalizeSlotInterval(20), 30);
      expect(normalizeSlotInterval(0), 30);
      expect(normalizeSlotInterval(-15), 30);
      expect(normalizeSlotInterval(null), 30);
      expect(normalizeSlotInterval('nope'), 30);
    });

    test('accepts numeric strings the current parser supports', () {
      expect(normalizeSlotInterval('15'), 15);
      expect(normalizeSlotInterval('45'), 45);
    });
  });

  group('canonical occupancy blocks', () {
    test('covers the documented start and duration pairs', () {
      expect(getCanonicalSlotBlocks('10:00', 30), ['10:00', '10:15']);
      expect(getCanonicalSlotBlocks('10:15', 30), ['10:15', '10:30']);
      expect(getCanonicalSlotBlocks('10:30', 45), ['10:30', '10:45', '11:00']);
      expect(getCanonicalSlotBlocks('10:45', 60), [
        '10:45',
        '11:00',
        '11:15',
        '11:30',
      ]);
      expect(getCanonicalSlotBlocks('11:15', 60), [
        '11:15',
        '11:30',
        '11:45',
        '12:00',
      ]);
    });

    test('never generates a block before the real start', () {
      expect(getCanonicalSlotBlocks('11:15', 60), isNot(contains('11:00')));
      expect(getCanonicalSlotBlocks('16:15', 45), isNot(contains('16:00')));
      expect(getCanonicalSlotBlocks('15:30', 45), ['15:30', '15:45', '16:00']);
    });
  });

  group('client adjacent 45 minute sessions', () {
    const date = '2026-10-01';
    const first = TimeSlot(date: date, time: '15:30');
    const second = TimeSlot(date: date, time: '16:15');
    const overlapping = TimeSlot(date: date, time: '16:00');

    test('15:30+45 and 16:15+45 have no canonical intersection', () {
      expect(
        availabilityKeysForSlot(
          first,
          45,
        ).intersection(availabilityKeysForSlot(second, 45)),
        isEmpty,
      );
      expect(
        overlapsActiveAppointment(
          start: second,
          durationMinutes: 45,
          appointments: [
            _appointment(id: 'a', slot: first, durationMinutes: 45),
          ],
        ),
        isFalse,
      );
    });

    test('15:30+45 and 16:00+45 conflict on 16:00', () {
      expect(
        availabilityKeysForSlot(
          first,
          45,
        ).intersection(availabilityKeysForSlot(overlapping, 45)),
        {'${date}_16:00'},
      );
      expect(
        overlapsActiveAppointment(
          start: overlapping,
          durationMinutes: 45,
          appointments: [
            _appointment(id: 'a', slot: first, durationMinutes: 45),
          ],
        ),
        isTrue,
      );
    });

    test('adjacent sessions keep independent capacity', () {
      const occupancy = [
        SlotOccupancy(id: '${date}_15:30', date: date, time: '15:30', count: 1),
        SlotOccupancy(id: '${date}_15:45', date: date, time: '15:45', count: 1),
        SlotOccupancy(id: '${date}_16:00', date: date, time: '16:00', count: 1),
      ];

      expect(
        maxEffectiveOccupancyForDuration(
          start: first,
          durationMinutes: 45,
          occupancy: occupancy,
        ),
        1,
      );
      expect(
        maxEffectiveOccupancyForDuration(
          start: second,
          durationMinutes: 45,
          occupancy: occupancy,
        ),
        0,
      );
    });
  });

  group('blocked slots', () {
    const blocked = BlockedSlot(
      id: 'blocked',
      date: '2026-10-01',
      time: '16:15',
    );

    test('16:15 blocks 16:00+45 and 16:15+30 but not 16:30+30', () {
      expect(
        isDurationBlocked(
          start: const TimeSlot(date: '2026-10-01', time: '16:00'),
          durationMinutes: 45,
          blockedSlots: const [blocked],
        ),
        isTrue,
      );
      expect(
        isDurationBlocked(
          start: const TimeSlot(date: '2026-10-01', time: '16:15'),
          durationMinutes: 30,
          blockedSlots: const [blocked],
        ),
        isTrue,
      );
      expect(
        isDurationBlocked(
          start: const TimeSlot(date: '2026-10-01', time: '16:30'),
          durationMinutes: 30,
          blockedSlots: const [blocked],
        ),
        isFalse,
      );
    });
  });

  group('capacity', () {
    const start = TimeSlot(date: '2026-10-01', time: '16:15');
    const occupancy = [
      SlotOccupancy(
        id: '2026-10-01_16:15',
        date: '2026-10-01',
        time: '16:15',
        count: 1,
      ),
      SlotOccupancy(
        id: '2026-10-01_16:30',
        date: '2026-10-01',
        time: '16:30',
        count: 3,
      ),
      SlotOccupancy(
        id: '2026-10-01_16:45',
        date: '2026-10-01',
        time: '16:45',
        count: 2,
      ),
      SlotOccupancy(
        id: '2026-10-01_17:00',
        date: '2026-10-01',
        time: '17:00',
        count: 1,
      ),
    ];

    test('30, 45 and 60 minute sessions use every covered block', () {
      expect(availabilityKeysForSlot(start, 30), {
        '2026-10-01_16:15',
        '2026-10-01_16:30',
      });
      expect(availabilityKeysForSlot(start, 45), {
        '2026-10-01_16:15',
        '2026-10-01_16:30',
        '2026-10-01_16:45',
      });
      expect(availabilityKeysForSlot(start, 60), {
        '2026-10-01_16:15',
        '2026-10-01_16:30',
        '2026-10-01_16:45',
        '2026-10-01_17:00',
      });
    });

    test(
      'most restrictive covered block governs occupancy and maxCapacity',
      () {
        expect(
          maxEffectiveOccupancyForDuration(
            start: start,
            durationMinutes: 45,
            occupancy: occupancy,
          ),
          3,
        );
        expect(
          isDurationFull(
            start: start,
            durationMinutes: 45,
            occupancy: occupancy,
            maxCapacity: 3,
          ),
          isTrue,
        );
        expect(
          isDurationFull(
            start: start,
            durationMinutes: 45,
            occupancy: occupancy,
            maxCapacity: 4,
          ),
          isFalse,
        );
      },
    );

    test('approved credits only canonical blocks and pending credits none', () {
      final approved = _appointment(
        id: 'approved',
        slot: start,
        durationMinutes: 45,
        status: AppointmentStatus.approved,
      );
      final pending = _appointment(
        id: 'pending',
        slot: start,
        durationMinutes: 45,
      );

      expect(buildOccupancyCreditsByKey([pending]), isEmpty);
      expect(buildOccupancyCreditsByKey([approved]), {
        '2026-10-01_16:15': 1,
        '2026-10-01_16:30': 1,
        '2026-10-01_16:45': 1,
      });
      expect(
        maxEffectiveOccupancyForDuration(
          start: start,
          durationMinutes: 45,
          occupancy: occupancy,
          occupancyCreditsByKey: buildOccupancyCreditsByKey([approved]),
        ),
        2,
      );
    });
  });

  group('live siteConfig slotInterval', () {
    test('30 to 15 reveals :15 starts and 15 to 30 hides them again', () {
      SiteConfig configOf(int interval) => SiteConfig(
        startHour: 7,
        endHour: 9,
        slotInterval: interval,
        bonoExpirationMonths: 1,
        maintenanceMode: false,
      );

      expect(
        buildBookingSlotsForDate(
          date: '2026-10-01',
          siteConfig: configOf(30),
        ).map((slot) => slot.time),
        ['07:00', '07:30', '08:00', '08:30'],
      );
      expect(
        buildBookingSlotsForDate(
          date: '2026-10-01',
          siteConfig: configOf(15),
        ).map((slot) => slot.time),
        [
          '07:00',
          '07:15',
          '07:30',
          '07:45',
          '08:00',
          '08:15',
          '08:30',
          '08:45',
        ],
      );
    });

    test(
      'existing 16:15 appointment stays visible when the grid becomes 30',
      () {
        final appointment = _appointment(
          id: 'existing',
          slot: const TimeSlot(date: '2026-10-01', time: '16:15'),
          durationMinutes: 45,
        );
        const interval30 = SiteConfig(
          startHour: 8,
          endHour: 20,
          slotInterval: 30,
          bonoExpirationMonths: 1,
          maintenanceMode: false,
        );

        expect(appointment.schedulingSlot?.time, '16:15');
        expect(appointment.timeLabel, '16:15 - 17:00');
        expect(
          buildBookingSlotsForDate(
            date: '2026-10-01',
            siteConfig: interval30,
          ).map((slot) => slot.time),
          isNot(contains('16:15')),
        );
      },
    );

    testWidgets(
      'emitting a new SiteConfig does not mutate stored appointments, series or bono',
      (tester) async {
        final appointment = _appointment(
          id: 'existing',
          slot: const TimeSlot(date: '2026-10-02', time: '16:15'),
          durationMinutes: 45,
        );
        final series = RecurringAppointmentSeries(
          id: 'series-1',
          userId: 'uid',
          serviceType: 'Bono Mensual de Entrenamiento',
          durationMinutes: 45,
          startDate: '2026-10-02',
          startTime: '16:15',
          intervalDays: 3,
          endDate: '2026-10-11',
          occurrenceCount: 4,
          totalMinutes: 180,
          bonoId: 'bono-id',
          status: AppointmentStatus.pending,
          origin: RecurringSeriesOrigin.client,
          createdAt: '2026-09-01T10:00:00.000Z',
        );
        final bono = Bono(
          id: 'bono-id',
          userId: 'uid',
          tamano: 240,
          minutosTotales: 240,
          minutosRestantes: 180,
          fechaAsignacion: '2026-09-01T00:00:00.000Z',
          fechaExpiracion: '2026-10-31',
          estado: BonoStatus.activo,
          historial: const [],
          asignadoPor: 'admin',
          createdAt: '2026-09-01T00:00:00.000Z',
        );
        const first = SiteConfig(
          startHour: 8,
          endHour: 20,
          slotInterval: 15,
          bonoExpirationMonths: 1,
          maintenanceMode: false,
        );
        const next = SiteConfig(
          startHour: 8,
          endHour: 20,
          slotInterval: 30,
          bonoExpirationMonths: 1,
          maintenanceMode: false,
        );
        final repository = FakePortalRepository(
          appointments: [appointment],
          recurringSeries: [series],
          bonos: [bono],
          siteConfig: first,
        );
        final viewModel = ClientPortalViewModel(
          repository: repository,
          uid: 'uid',
          now: () => DateTime.utc(2026, 9, 20, 8),
        )..start();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(viewModel.state.siteConfig?.slotInterval, 15);

        repository.emitSiteConfig(next);
        await tester.pump();

        expect(viewModel.state.siteConfig?.slotInterval, 30);
        expect(
          viewModel.state.appointments.single.schedulingSlot?.time,
          '16:15',
        );
        expect(viewModel.state.appointments.single.durationMinutes, 45);
        expect(
          viewModel.state.recurringSeriesById['series-1']?.startTime,
          '16:15',
        );
        expect(viewModel.state.activeBono?.minutosRestantes, 180);
        viewModel.dispose();
      },
    );
  });
}

Appointment _appointment({
  required String id,
  required TimeSlot slot,
  required int durationMinutes,
  AppointmentStatus status = AppointmentStatus.pending,
}) {
  return Appointment(
    id: id,
    userId: 'uid',
    name: 'Cliente',
    email: 'cliente@example.com',
    phone: '+34612345678',
    serviceType: 'Bono Mensual de Entrenamiento',
    durationMinutes: durationMinutes,
    preferredSlots: [slot],
    reason: '',
    status: status,
    approvedSlot: status == AppointmentStatus.approved ? slot : null,
    createdAt: '2026-09-01T00:00:00Z',
  );
}
