import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/madrid_date.dart';
import 'package:app_focus_club/features/client/domain/portal_availability.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Europe/Madrid rescheduling time authority', () {
    test('resolves CET and CEST civil times to their real UTC instant', () {
      expect(
        madridCivilSlotToUtc(date: '2026-01-15', time: '10:00'),
        DateTime.utc(2026, 1, 15, 9),
      );
      expect(
        madridCivilSlotToUtc(date: '2026-07-15', time: '10:00'),
        DateTime.utc(2026, 7, 15, 8),
      );
    });

    test('rejects nonexistent spring time and chooses first repeated time', () {
      expect(madridCivilSlotToUtc(date: '2026-03-29', time: '02:30'), isNull);
      expect(
        madridCivilSlotToUtc(date: '2026-10-25', time: '02:30'),
        DateTime.utc(2026, 10, 25, 0, 30),
      );
    });

    test('24 hour lock is inclusive in CET and CEST', () {
      expect(
        isInsideCustomerRescheduleLockWindow(
          date: '2026-01-15',
          time: '10:00',
          now: DateTime.utc(2026, 1, 14, 9),
        ),
        isTrue,
      );
      expect(
        isInsideCustomerRescheduleLockWindow(
          date: '2026-01-15',
          time: '10:01',
          now: DateTime.utc(2026, 1, 14, 9),
        ),
        isFalse,
      );
      expect(
        isInsideCustomerRescheduleLockWindow(
          date: '2026-07-15',
          time: '10:00',
          now: DateTime.utc(2026, 7, 14, 8),
        ),
        isTrue,
      );
      expect(
        isInsideCustomerRescheduleLockWindow(
          date: '2026-07-15',
          time: '09:59',
          now: DateTime.utc(2026, 7, 14, 8),
        ),
        isTrue,
      );
    });

    test('result is unchanged for an offset-encoded now outside Madrid', () {
      final utcNow = DateTime.utc(2026, 7, 14, 8);
      final tokyoEncodedNow = DateTime.parse('2026-07-14T17:00:00+09:00');

      expect(tokyoEncodedNow, utcNow);
      expect(
        isMadridSlotFuture(
          date: '2026-07-15',
          time: '10:01',
          now: tokyoEncodedNow,
        ),
        isMadridSlotFuture(date: '2026-07-15', time: '10:01', now: utcNow),
      );
      expect(
        isInsideCustomerRescheduleLockWindow(
          date: '2026-07-15',
          time: '10:01',
          now: tokyoEncodedNow,
        ),
        isFalse,
      );
    });

    test('selects future active occurrences exclusively by Madrid instant', () {
      final appointments = [
        _appointment(id: 'past', date: '2026-07-14', time: '09:59'),
        _appointment(id: 'future', date: '2026-07-14', time: '10:01'),
        _appointment(
          id: 'cancelled',
          date: '2026-07-16',
          time: '10:00',
          status: AppointmentStatus.cancelled,
        ),
      ];

      expect(
        futureActiveOccurrencesForSeries(
          seriesId: 'series-1',
          appointments: appointments,
          now: DateTime.utc(2026, 7, 14, 8),
        ).map((item) => item.id),
        ['future'],
      );
    });

    test(
      'series is locked when any replaceable future occurrence is <=24h',
      () {
        final now = DateTime.utc(2026, 7, 14, 8);
        final appointments = [
          _appointment(id: 'later', date: '2026-07-16', time: '10:00'),
          _appointment(id: 'locked', date: '2026-07-15', time: '10:00'),
          _appointment(
            id: 'cancelled',
            date: '2026-07-15',
            time: '09:00',
            status: AppointmentStatus.cancelled,
          ),
        ];

        expect(
          canCustomerReplaceRecurringSeries(
            seriesId: 'series-1',
            appointments: appointments,
            now: now,
          ),
          isFalse,
        );
        expect(
          canCustomerRescheduleAppointment(appointments.first, now),
          isTrue,
        );
      },
    );
  });

  group('backend-compatible occupancy parity', () {
    const config = SiteConfig(
      startHour: 8,
      endHour: 20,
      slotInterval: 15,
      bonoExpirationMonths: 1,
      maintenanceMode: false,
      maxCapacity: 4,
    );
    const slot = TimeSlot(date: '2026-09-30', time: '11:15');

    test('keys include 15 minute blocks and deduplicated legacy floors', () {
      expect(availabilityKeysForSlot(slot, 60), {
        '2026-09-30_11:00',
        '2026-09-30_11:15',
        '2026-09-30_11:30',
        '2026-09-30_11:45',
        '2026-09-30_12:00',
      });
    });

    test('approved credits use every exact key once; pending credits none', () {
      final approved = _appointment(
        id: 'approved',
        date: slot.date,
        time: slot.time,
        status: AppointmentStatus.approved,
        durationMinutes: 60,
      );
      final credits = buildOccupancyCreditsByKey([
        approved,
        _appointment(
          id: 'pending',
          date: slot.date,
          time: slot.time,
          durationMinutes: 60,
        ),
      ]);

      expect(credits.keys.toSet(), availabilityKeysForSlot(slot, 60));
      expect(credits.values, everyElement(1));
    });

    test('most restrictive key drives 30, 45 and 60 minute occupancy', () {
      for (final duration in [30, 45, 60]) {
        final keys = availabilityKeysForSlot(slot, duration).toList();
        final occupancy = [
          SlotOccupancy(
            id: keys.last,
            date: slot.date,
            time: keys.last.split('_').last,
            count: duration == 30
                ? 2
                : duration == 45
                ? 3
                : 4,
          ),
        ];
        expect(
          maxEffectiveOccupancyForDuration(
            start: slot,
            durationMinutes: duration,
            occupancy: occupancy,
          ),
          duration == 30
              ? 2
              : duration == 45
              ? 3
              : 4,
        );
      }
    });

    test(
      'credit reduces effective occupancy and legacy floor can stay full',
      () {
        final credits = buildOccupancyCreditsByKey([
          _appointment(
            id: 'source',
            date: slot.date,
            time: slot.time,
            status: AppointmentStatus.approved,
            durationMinutes: 60,
          ),
        ]);
        final occupancy = [
          const SlotOccupancy(
            id: '2026-09-30_11:15',
            date: '2026-09-30',
            time: '11:15',
            count: 4,
          ),
          const SlotOccupancy(
            id: '2026-09-30_11:00',
            date: '2026-09-30',
            time: '11:00',
            count: 5,
          ),
        ];

        expect(
          maxEffectiveOccupancyForDuration(
            start: slot,
            durationMinutes: 60,
            occupancy: occupancy,
            occupancyCreditsByKey: credits,
          ),
          4,
        );
        expect(
          bookingSlotState(
            slot: slot,
            durationMinutes: 60,
            siteConfig: config,
            blockedSlots: const [],
            occupancy: occupancy,
            appointments: const [],
            occupancyCreditsByKey: credits,
            now: DateTime.utc(2026, 9, 20),
          ).label,
          'Completo',
        );
      },
    );

    test('dynamic capacity produces exact labels and semantic states', () {
      BookingSlotState stateAt(int occupied) => bookingSlotState(
        slot: slot,
        durationMinutes: 30,
        siteConfig: config,
        blockedSlots: const [],
        occupancy: [
          SlotOccupancy(
            id: slot.key,
            date: slot.date,
            time: slot.time,
            count: occupied,
          ),
        ],
        appointments: const [],
        now: DateTime.utc(2026, 9, 20),
      );

      expect(stateAt(0).label, 'Disponible');
      expect(stateAt(1).label, '3 plazas');
      expect(stateAt(2).label, '2 plazas');
      expect(stateAt(3).label, 'Casi lleno · 1 plaza');
      expect(stateAt(4).label, 'Completo');
    });

    test('blocked wins over conflict and conflict wins over full', () {
      final conflict = _appointment(
        id: 'conflict',
        date: slot.date,
        time: slot.time,
      );
      final full = [
        const SlotOccupancy(
          id: '2026-09-30_11:15',
          date: '2026-09-30',
          time: '11:15',
          count: 4,
        ),
      ];
      final blocked = bookingSlotState(
        slot: slot,
        durationMinutes: 30,
        siteConfig: config,
        blockedSlots: const [
          BlockedSlot(id: 'blocked', date: '2026-09-30', time: '11:00'),
        ],
        occupancy: full,
        appointments: [conflict],
        now: DateTime.utc(2026, 9, 20),
      );
      final own = bookingSlotState(
        slot: slot,
        durationMinutes: 30,
        siteConfig: config,
        blockedSlots: const [],
        occupancy: full,
        appointments: [conflict],
        now: DateTime.utc(2026, 9, 20),
      );

      expect(blocked.label, 'Bloqueado');
      expect(own.label, 'Tu sesión');
    });
  });

  group('series replacement accounting', () {
    final now = DateTime.utc(2026, 9, 20, 8);

    List<Appointment> futureOccurrences(int count) => List.generate(
      count,
      (index) => _appointment(
        id: 'future-$index',
        date: '2026-09-${21 + index * 2}',
        time: '10:00',
      ),
    );

    test('active bono adds remaining minutes to the reserved 90', () {
      final policy = recurringSeriesReplacementBonoPolicy(
        bono: _replacementBono(status: BonoStatus.activo, remainingMinutes: 60),
        seriesId: 'series-1',
        appointments: futureOccurrences(2),
        now: now,
      );

      expect(policy.isAvailable, isTrue);
      expect(policy.availableMinutes, 150);
      expect(policy.expirationDate, '2026-10-31');
    });

    test('exhausted bono exposes only the reserved 90 minutes', () {
      final policy = recurringSeriesReplacementBonoPolicy(
        bono: _replacementBono(status: BonoStatus.agotado, remainingMinutes: 0),
        seriesId: 'series-1',
        appointments: futureOccurrences(2),
        now: now,
      );

      expect(policy.isAvailable, isTrue);
      expect(policy.availableMinutes, 90);
      expect(policy.expirationDate, '2026-10-31');
    });

    test('expired bono ignores remaining minutes and expiration cap', () {
      final policy = recurringSeriesReplacementBonoPolicy(
        bono: _replacementBono(
          status: BonoStatus.expirado,
          remainingMinutes: 60,
        ),
        seriesId: 'series-1',
        appointments: futureOccurrences(2),
        now: now,
      );

      expect(policy.isAvailable, isTrue);
      expect(policy.availableMinutes, 90);
      expect(policy.expirationDate, isNull);
    });

    test('stale active status uses the backend expiration instant', () {
      final utcNow = DateTime.utc(2026, 9, 20, 8);
      final tokyoEncodedNow = DateTime.parse('2026-09-20T17:00:00+09:00');

      for (final representedNow in [utcNow, tokyoEncodedNow]) {
        final policy = recurringSeriesReplacementBonoPolicy(
          bono: _replacementBono(
            status: BonoStatus.activo,
            remainingMinutes: 60,
            expirationDate: '2026-09-20T07:59:59Z',
          ),
          seriesId: 'series-1',
          appointments: futureOccurrences(2),
          now: representedNow,
        );

        expect(policy.availableMinutes, 90);
        expect(policy.expirationDate, isNull);
      }
    });

    test('expired bono can maintain or reduce but cannot expand', () {
      final policy = recurringSeriesReplacementBonoPolicy(
        bono: _replacementBono(
          status: BonoStatus.expirado,
          remainingMinutes: 60,
          expirationDate: '2026-09-19T00:00:00Z',
        ),
        seriesId: 'series-1',
        appointments: futureOccurrences(3),
        now: now,
      );
      final options = getRecurringEndDateOptions(
        startDate: '2026-09-21',
        intervalDays: 2,
        durationMinutes: 45,
        remainingMinutes: policy.availableMinutes,
        bonoExpirationDate: policy.expirationDate,
      );

      expect(options.map((option) => option.occurrenceCount), [2, 3]);
    });

    test('deleted or missing bono is unavailable for full replacement', () {
      final appointments = futureOccurrences(2);

      for (final bono in <Bono?>[
        null,
        _replacementBono(status: BonoStatus.eliminado, remainingMinutes: 60),
      ]) {
        final policy = recurringSeriesReplacementBonoPolicy(
          bono: bono,
          seriesId: 'series-1',
          appointments: appointments,
          now: now,
        );

        expect(policy.isAvailable, isFalse);
        expect(policy.availableMinutes, 0);
        expect(policy.expirationDate, isNull);
      }
    });

    test('temporal series eligibility remains independent from bono state', () {
      final appointments = [
        _appointment(id: 'future', date: '2026-09-22', time: '10:00'),
      ];

      expect(
        canCustomerReplaceRecurringSeries(
          seriesId: 'series-1',
          appointments: appointments,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('callable contracts and typed response', () {
    test('single payload and callable name are exact', () async {
      String? calledName;
      Map<String, Object?>? calledPayload;
      final gateway = PortalFunctionsGateway(
        invoker: (name, payload) async {
          calledName = name;
          calledPayload = payload;
          return null;
        },
      );
      const request = RecurringOccurrenceRescheduleRequest(
        appointmentId: 'appointment-1',
        preferredSlot: TimeSlot(date: '2026-09-30', time: '11:15'),
      );

      await gateway.rescheduleRecurringOccurrence(request);

      expect(portalFunctionsRegion, 'europe-west1');
      expect(calledName, 'rescheduleOwnRecurringAppointment');
      expect(calledPayload, {
        'appointmentId': 'appointment-1',
        'preferredSlot': {'date': '2026-09-30', 'time': '11:15'},
        'scope': 'single',
      });
    });

    test('series payload, callable and typed parsing are exact', () async {
      String? calledName;
      Map<String, Object?>? calledPayload;
      final gateway = PortalFunctionsGateway(
        invoker: (name, payload) async {
          calledName = name;
          calledPayload = payload;
          return {
            'success': true,
            'seriesId': 'series-1',
            'affectedAppointmentIds': ['a1', 'a2'],
            'reusedAppointmentIds': ['a1'],
            'createdAppointmentIds': ['a2'],
            'cancelledAppointmentIds': ['old'],
            'occurrenceCount': 2,
            'totalMinutes': 90,
            'status': 'pending',
          };
        },
      );
      const request = RecurringSeriesReplacementRequest(
        appointmentId: 'appointment-1',
        startSlot: TimeSlot(date: '2026-09-30', time: '11:15'),
        intervalDays: 3,
        endDate: '2026-10-09',
      );

      final result = await gateway.replaceRecurringSeriesSchedule(request);

      expect(calledName, replaceOwnRecurringSeriesScheduleCallable);
      expect(calledPayload, {
        'appointmentId': 'appointment-1',
        'startSlot': {'date': '2026-09-30', 'time': '11:15'},
        'intervalDays': 3,
        'endDate': '2026-10-09',
      });
      expect(
        replaceOwnRecurringSeriesScheduleCallable,
        'replaceOwnRecurringSeriesSchedule',
      );
      expect(result.seriesId, 'series-1');
      expect(result.affectedAppointmentIds, ['a1', 'a2']);
      expect(result.status, AppointmentStatus.pending);
      expect(
        () => RecurringSeriesReplacementResult.fromMap({
          'success': true,
          'seriesId': 'series-1',
        }),
        throwsFormatException,
      );
    });

    test('series gateway rejects a non-map response', () async {
      final gateway = PortalFunctionsGateway(
        invoker: (_, _) async => const ['invalid'],
      );

      await expectLater(
        gateway.replaceRecurringSeriesSchedule(
          const RecurringSeriesReplacementRequest(
            appointmentId: 'appointment-1',
            startSlot: TimeSlot(date: '2026-09-30', time: '11:15'),
            intervalDays: 3,
            endDate: '2026-10-09',
          ),
        ),
        throwsFormatException,
      );
    });
  });

  group('central rescheduling error mapper', () {
    test('uses different 24 hour messages for single and series', () {
      final error = _FunctionsError('one_day_change_not_allowed');

      expect(
        recurringRescheduleErrorMessage(
          error,
          context: CustomerRescheduleErrorContext.single,
        ),
        contains('Esta cita'),
      );
      expect(
        recurringRescheduleErrorMessage(
          error,
          context: CustomerRescheduleErrorContext.series,
        ),
        contains('Una de las sesiones'),
      );
    });

    test('maps every production reason to a specific message', () {
      for (final reason in const [
        'slot_blocked',
        'slot_full',
        'appointment_conflict',
        'outside_schedule',
        'slot_not_future',
        'invalid_occupancy',
        'recurring_occurrence_unavailable',
        'series_unavailable',
        'bono_unavailable',
        'insufficient_bono_minutes',
        'invalid_financial_reservation',
        'invalid_series_length',
      ]) {
        final message = recurringRescheduleErrorMessage(
          _FunctionsError(reason),
          context: CustomerRescheduleErrorContext.series,
        );
        expect(message, isNot(contains('No hemos podido modificar')));
      }
    });
  });
}

class _FunctionsError extends FirebaseFunctionsException {
  _FunctionsError(String reason)
    : super(
        code: 'failed-precondition',
        message: reason,
        details: {'reason': reason},
      );
}

Appointment _appointment({
  required String id,
  required String date,
  required String time,
  AppointmentStatus status = AppointmentStatus.pending,
  int durationMinutes = 45,
}) {
  final slot = TimeSlot(date: date, time: time);
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
    recurrenceSeriesId: 'series-1',
  );
}

Bono _replacementBono({
  required BonoStatus status,
  required int remainingMinutes,
  String expirationDate = '2026-10-31',
}) {
  return Bono(
    id: 'bono-1',
    userId: 'uid',
    tamano: 240,
    minutosTotales: 240,
    minutosRestantes: remainingMinutes,
    fechaAsignacion: '2026-09-01',
    fechaExpiracion: expirationDate,
    estado: status,
    historial: const [],
    asignadoPor: 'admin',
    createdAt: '2026-09-01T00:00:00Z',
  );
}
