import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/appointment_calendar.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/appointment_detail_screen.dart';
import 'package:app_focus_club/features/client/presentation/appointments_calendar_view.dart';
import 'package:app_focus_club/features/client/presentation/appointments_screen.dart';
import 'package:app_focus_club/features/client/presentation/booking_screen.dart';
import 'package:app_focus_club/features/client/presentation/renewal_confirmation_screen.dart';
import 'package:app_focus_club/features/client/widgets/appointment_display.dart';
import 'package:app_focus_club/features/notifications/domain/notification_presentation.dart';
import 'package:app_focus_club/theme/app_theme.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 10 Sep 2026, 09:00 local test clock.
final _now = DateTime(2026, 9, 10, 9);

Map<String, Object?> _wire({
  String status = 'pending',
  String date = '2026-09-15',
  String time = '10:00',
  String duration = '60',
  Map<String, Object?> extra = const {},
}) {
  return {
    'userId': 'uid',
    'name': 'Cliente',
    'email': 'cliente@example.com',
    'phone': '+34600000000',
    'serviceType': 'Bono Mensual de Entrenamiento',
    'duration': duration,
    'preferredSlots': [
      {'date': date, 'time': time},
    ],
    'reason': '',
    'status': status,
    'createdAt': '2026-09-01T10:00:00.000Z',
    ...extra,
  };
}

Appointment _proposalAppointment({String id = 'proposal-1'}) {
  return Appointment.fromMap(
    id,
    _wire(
      extra: {
        'customerConfirmation': {
          'kind': 'proposal',
          'requestedAt': '2026-09-09T10:00:00.000Z',
          'response': null,
        },
        'proposal': {
          'status': 'pending',
          'originalSlot': {'date': '2026-09-15', 'time': '10:00'},
          'proposedSlot': {'date': '2026-09-16', 'time': '11:00'},
          'proposedTrainer': 'trainer-1',
          'proposedAt': '2026-09-09T10:00:00.000Z',
        },
      },
    ),
  );
}

Appointment _renewedAppointment(String id, String date) {
  return Appointment.fromMap(
    id,
    _wire(
      date: date,
      time: '18:00',
      extra: {
        'assignedTrainer': 'trainer-1',
        'customerConfirmation': {
          'kind': 'renewal',
          'renewalId': 'ren_1',
          'response': null,
        },
      },
    ),
  );
}

Bono _activeBono({int remaining = 240}) {
  return Bono(
    id: 'bono-id',
    userId: 'uid',
    tamano: 240,
    minutosTotales: 240,
    minutosRestantes: remaining,
    fechaAsignacion: '2026-09-01',
    fechaExpiracion: '2026-10-31',
    estado: BonoStatus.activo,
    historial: const [],
    asignadoPor: 'admin',
    createdAt: '2026-09-01T10:00:00.000Z',
  );
}

FakePortalRepository _repository({
  List<Appointment> appointments = const [],
  Bono? bono,
}) {
  return FakePortalRepository(
    appointments: appointments,
    bonos: [bono ?? _activeBono()],
    trainers: const [
      Trainer(
        id: 'trainer-1',
        uid: 't1',
        name: 'Ana',
        active: true,
        createdAt: '2026-01-01T00:00:00.000Z',
        specialties: [],
      ),
    ],
    siteConfig: const SiteConfig(
      startHour: 8,
      endHour: 20,
      slotInterval: 30,
      bonoExpirationMonths: 1,
      maintenanceMode: false,
    ),
  );
}

ClientPortalViewModel _viewModel(FakePortalRepository repository) {
  return ClientPortalViewModel(
    repository: repository,
    uid: 'uid',
    now: () => _now,
  )..start();
}

void main() {
  group('models', () {
    test('legacy documents are training without pending confirmation', () {
      final legacy = Appointment.fromMap('a', _wire());
      expect(legacy.appointmentType, AppointmentType.training);
      expect(legacy.isNutrition, isFalse);
      expect(legacy.customerConfirmation, isNull);
      expect(legacy.openCustomerConfirmation, isNull);
      expect(legacy.toMap().containsKey('appointmentType'), isFalse);
    });

    test('nutrition and unknown statuses parse without breaking', () {
      final nutrition = Appointment.fromMap(
        'n',
        _wire(duration: '30', extra: {'appointmentType': 'nutrition'}),
      );
      expect(nutrition.isNutrition, isTrue);
      expect(nutrition.durationMinutes, nutritionDurationMinutes);
      final future = Appointment.fromMap('x', _wire(status: 'new_status'));
      expect(future.status, AppointmentStatus.pending);
    });

    test('an open proposal is shown at the proposed slot', () {
      final appointment = _proposalAppointment();
      expect(appointment.awaitsProposalAnswer, isTrue);
      expect(appointment.awaitsRenewalConfirmation, isFalse);
      expect(
        appointment.schedulingSlot,
        const TimeSlot(date: '2026-09-16', time: '11:00'),
      );
      expect(
        appointment.proposal!.originalSlot,
        const TimeSlot(date: '2026-09-15', time: '10:00'),
      );
    });

    test('answered or non-pending confirmations are no longer open', () {
      final answered = Appointment.fromMap(
        'r',
        _wire(
          status: 'approved',
          extra: {
            'customerConfirmation': {'kind': 'renewal', 'response': 'accepted'},
          },
        ),
      );
      expect(answered.openCustomerConfirmation, isNull);
      final superseded = Appointment.fromMap(
        's',
        _wire(
          extra: {
            'customerConfirmation': {'kind': 'proposal'},
            'proposal': {
              'status': 'superseded',
              'proposedSlot': {'date': '2026-09-16', 'time': '11:00'},
            },
          },
        ),
      );
      expect(superseded.openCustomerConfirmation, isNull);
    });

    test('request payload carries the appointment type', () {
      const request = AppointmentRequest(
        durationMinutes: 30,
        preferredSlot: TimeSlot(date: '2026-09-15', time: '10:00'),
        reason: '',
        appointmentType: AppointmentType.nutrition,
      );
      expect(request.toCallablePayload()['appointmentType'], 'nutrition');
      expect(request.toCallablePayload()['duration'], '30');
    });
  });

  group('display status', () {
    test('every state has its own label and colour', () {
      final proposal = _proposalAppointment();
      final renewal = _renewedAppointment('r1', '2026-09-17');
      expect(
        appointmentDisplayStatusOf(proposal, now: _now),
        AppointmentDisplayStatus.proposalPending,
      );
      expect(
        appointmentDisplayStatusLabel(proposal, now: _now),
        'Nueva hora propuesta',
      );
      expect(appointmentDisplayStatusColor(proposal, now: _now), AppTheme.info);
      expect(
        appointmentDisplayStatusLabel(renewal, now: _now),
        'Por confirmar',
      );
      expect(
        appointmentDisplayStatusLabel(
          Appointment.fromMap('p', _wire()),
          now: _now,
        ),
        'Pendiente',
      );
      expect(
        appointmentDisplayStatusLabel(
          Appointment.fromMap('c', _wire(status: 'cancelled')),
          now: _now,
        ),
        'Cancelada',
      );
      expect(
        appointmentDisplayStatusLabel(
          Appointment.fromMap('p', _wire(date: '2026-09-01')),
          now: _now,
        ),
        'No realizada',
      );
      expect(appointmentTypeLabel(AppointmentType.nutrition), 'Nutrición');
    });

    test('new notification events have their own visuals', () {
      expect(
        notificationVisualFor(
          event: 'appointment_proposed',
          type: 'appointment_status',
        ).label,
        'Nueva hora propuesta',
      );
      expect(
        notificationVisualFor(
          event: 'appointment_series_renewal_pending',
          type: 'appointment_status',
        ).label,
        'Citas renovadas por confirmar',
      );
    });
  });

  group('calendar helpers', () {
    test('month grid starts on Monday and navigates across years', () {
      const october = CalendarMonth(2026, 10);
      expect(october.label, 'Octubre 2026');
      // 1 Oct 2026 is a Thursday: three empty cells first.
      expect(october.gridDateKeys.take(4), [null, null, null, '2026-10-01']);
      expect(october.gridDateKeys.whereType<String>().length, 31);
      expect(const CalendarMonth(2026, 12).next, const CalendarMonth(2027, 1));
      expect(
        const CalendarMonth(2026, 1).previous,
        const CalendarMonth(2025, 12),
      );
      expect(const CalendarMonth(2028, 2).daysInMonth, 29);
    });

    test('appointments are grouped by day and sorted by time', () {
      final grouped = appointmentsByDateKey([
        Appointment.fromMap('late', _wire(time: '18:00')),
        Appointment.fromMap('early', _wire(time: '09:00')),
        _proposalAppointment(),
      ]);
      expect(grouped['2026-09-15']!.map((item) => item.id), ['early', 'late']);
      expect(grouped['2026-09-16']!.single.id, 'proposal-1');
    });
  });

  group('proposal answer', () {
    testWidgets('accepting sends the answer and shows confirmation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final appointment = _proposalAppointment();
      final repository = _repository(appointments: [appointment]);
      final viewModel = _viewModel(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('appointment-confirmation-card')),
        findsOneWidget,
      );
      expect(find.text('Solicitaste'), findsOneWidget);
      expect(find.text('Propuesta'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      // Modify/cancel are replaced by the answer buttons.
      expect(find.text('Modificar cita'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);

      await tester.tap(find.byKey(const Key('confirmation-accept')));
      await tester.pumpAndSettle();
      expect(
        repository.confirmationResponses.single.appointmentId,
        'proposal-1',
      );
      expect(
        repository.confirmationResponses.single.action,
        CustomerConfirmationAction.accept,
      );
      expect(find.text('Cita confirmada.'), findsOneWidget);
      viewModel.dispose();
    });

    testWidgets('declining asks first, then sends the decline', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final appointment = _proposalAppointment();
      final repository = _repository(appointments: [appointment]);
      final viewModel = _viewModel(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmation-decline')));
      await tester.pumpAndSettle();
      expect(find.text('¿Rechazar la hora propuesta?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Rechazar'));
      await tester.pumpAndSettle();
      expect(
        repository.confirmationResponses.single.action,
        CustomerConfirmationAction.decline,
      );
      viewModel.dispose();
    });

    testWidgets('a slot taken meanwhile shows a clear message', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final appointment = _proposalAppointment();
      final repository = _repository(appointments: [appointment]);
      repository.confirmationFailures['proposal-1'] =
          FirebaseFunctionsException(
            code: 'failed-precondition',
            message: 'La franja seleccionada está llena.',
            details: const {'reason': 'slot_full'},
          );
      final viewModel = _viewModel(repository);
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: appointment,
            viewModel: viewModel,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmation-accept')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Esta franja se ha completado'),
        findsOneWidget,
      );
      viewModel.dispose();
    });
  });

  group('renewed appointments', () {
    testWidgets(
      'banner opens the list and "Confirmar todas" reports failures',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final first = _renewedAppointment('r1', '2026-09-17');
        final second = _renewedAppointment('r2', '2026-09-24');
        final repository = _repository(appointments: [first, second]);
        repository.confirmationFailures['r2'] = FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'llena',
          details: const {'reason': 'slot_full'},
        );
        final viewModel = _viewModel(repository);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: viewModel,
                builder: (context, _) => AppointmentsScreen(
                  state: viewModel.state,
                  viewModel: viewModel,
                  onOpenBooking: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Tienes 2 citas renovadas por confirmar'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('pending-renewals-banner')));
        await tester.pumpAndSettle();
        expect(find.byType(RenewalConfirmationScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('renewal-confirm-all')));
        await tester.pumpAndSettle();
        expect(
          repository.confirmationResponses.map((item) => item.appointmentId),
          ['r1'],
        );
        expect(
          find.textContaining('Se han confirmado 1 de 2 citas'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Esta franja se ha completado'),
          findsOneWidget,
        );
        viewModel.dispose();
      },
    );
  });

  group('customer calendar', () {
    testWidgets(
      'shows only the given appointments by day and navigates months',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final opened = <String>[];
        final appointments = [
          Appointment.fromMap(
            'mine',
            _wire(date: '2026-09-15', extra: {'assignedTrainer': 'trainer-1'}),
          ),
          Appointment.fromMap(
            'nutri',
            _wire(
              date: '2026-09-15',
              time: '12:00',
              duration: '30',
              extra: {
                'appointmentType': 'nutrition',
                'serviceType': 'Consulta de nutrición',
              },
            ),
          ),
          _proposalAppointment(),
        ];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppointmentsCalendarView(
                appointments: appointments,
                now: _now,
                onOpenDetail: (appointment) => opened.add(appointment.id),
                trainerNameFor: (id) => id == 'trainer-1' ? 'Ana' : id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Septiembre 2026'), findsOneWidget);
        expect(find.text('Sin citas este día'), findsOneWidget);

        await tester.tap(find.byKey(const Key('calendar-day-2026-09-15')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('calendar-appointment-mine')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('calendar-appointment-nutri')),
          findsOneWidget,
        );
        expect(find.textContaining('Nutrición'), findsWidgets);
        expect(find.textContaining('Ana'), findsWidgets);

        await tester.tap(find.byKey(const Key('calendar-day-2026-09-16')));
        await tester.pumpAndSettle();
        expect(find.text('Nueva hora propuesta'), findsWidgets);
        await tester.tap(
          find.byKey(const Key('calendar-appointment-proposal-1')),
        );
        expect(opened, ['proposal-1']);

        await tester.tap(find.byKey(const Key('calendar-next-month')));
        await tester.pumpAndSettle();
        expect(find.text('Octubre 2026'), findsOneWidget);
        await tester.tap(find.byKey(const Key('calendar-previous-month')));
        await tester.tap(find.byKey(const Key('calendar-previous-month')));
        await tester.pumpAndSettle();
        expect(find.text('Agosto 2026'), findsOneWidget);
      },
    );
  });

  group('nutrition booking', () {
    testWidgets('skips duration, needs no minutes and sends nutrition', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // An active bono with no minutes left can still book nutrition.
      final repository = _repository(bono: _activeBono(remaining: 0));
      final viewModel = _viewModel(repository);
      await tester.pumpWidget(
        MaterialApp(home: BookingScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('booking-type-nutrition')),
      );
      await tester.tap(find.byKey(const Key('booking-type-nutrition')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
      // Straight to the schedule: no duration step.
      expect(find.text('10 sep'), findsWidgets);
      await tester.tap(find.text('10 sep').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('18:00').first);
      await tester.tap(find.text('18:00').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Consulta de nutrición'), findsWidgets);
      expect(find.text('30 min'), findsOneWidget);

      await tester.ensureVisible(find.text('Enviar Solicitud'));
      await tester.tap(find.text('Enviar Solicitud'));
      await tester.pump();
      final request = repository.requests.single;
      expect(request.appointmentType, AppointmentType.nutrition);
      expect(request.durationMinutes, 30);
      await tester.pump(const Duration(milliseconds: 901));
      await tester.pumpAndSettle();
      viewModel.dispose();
    });
  });
}
