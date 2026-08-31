import 'package:app_focus_club/app/app.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/layout_harness.dart';

void main() {
  testWidgets('renders splash and moves to auth', (tester) async {
    _setTestViewport(tester);
    await tester.pumpWidget(
      FocusClubApp(
        authRepository: _FakeAuthRepository(),
        portalRepository: _fakePortalRepository(),
        supportRepository: FakeSupportRepository(),
      ),
    );

    expect(
      find.image(const AssetImage('assets/images/focus_club_logo.jpeg')),
      findsOneWidget,
    );
    expect(find.text('Focus Club'), findsOneWidget);
    expect(find.text('Portal del Cliente'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.text('Focus Club Vallecas'), findsOneWidget);
    expect(find.text('Iniciar Sesion'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
  });

  testWidgets('login navigates to client dashboard', (tester) async {
    await _pumpAuth(tester);
    await _login(tester);

    expect(find.text('Laura Perez'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.byKey(const Key('nav-appointments')), findsOneWidget);
    expect(find.byKey(const Key('nav-profile')), findsOneWidget);
    expect(find.text('Reservar Sesion'), findsOneWidget);
  });

  testWidgets('login blocks unverified email and shows resend action', (
    tester,
  ) async {
    await _pumpAuth(
      tester,
      authRepository: _FakeAuthRepository(
        signInFailure: const AuthFailure('email-not-verified'),
      ),
    );

    await _login(tester);

    expect(
      find.text(
        'Tu email aun no esta verificado. Te hemos enviado un nuevo enlace.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reenviar email de verificacion'), findsOneWidget);
    expect(find.text('Laura Perez'), findsNothing);
  });

  testWidgets('switches between login and register', (tester) async {
    await _pumpAuth(tester);

    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsNothing);

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();

    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Crear Cuenta'), findsOneWidget);
  });

  testWidgets('navigates to reset password and shows success', (tester) async {
    await _pumpAuth(tester);

    await tester.tap(find.text('Has olvidado tu contrasena?'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar Contrasena'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'cliente@email.com',
    );
    await tester.tap(find.text('Enviar enlace'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enlace enviado. Revisa tu bandeja de entrada.'),
      findsOneWidget,
    );
  });

  testWidgets('hides google button only on iOS auth screen', (tester) async {
    await _withTargetPlatform(TargetPlatform.iOS, () async {
      await _pumpAuth(tester);

      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Has olvidado tu contrasena?'), findsOneWidget);
      expect(find.text('Registrarse'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsNothing);
      expect(find.text('o'), findsNothing);

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      expect(find.text('Crear Cuenta'), findsOneWidget);
      expect(find.text('Continuar con Google'), findsNothing);
    });
  });

  testWidgets('google button opens complete profile flow and dashboard', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      await _pumpAuth(tester);

      await tester.ensureVisible(find.text('Continuar con Google'));
      await tester.tap(find.text('Continuar con Google'));
      await tester.pumpAndSettle();

      expect(find.text('Completa tu Perfil'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(1), '612345678');
      await tester.tap(find.text('Guardar y Continuar'));
      await tester.pumpAndSettle();

      expect(find.text('Laura Perez'), findsOneWidget);
    });
  });

  testWidgets('register form validates main fields', (tester) async {
    await _pumpAuth(tester);

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Crear Cuenta'));
    await tester.tap(find.text('Crear Cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Introduce tu nombre completo.'), findsOneWidget);
    expect(find.text('Introduce tu email.'), findsOneWidget);
    expect(find.text('Introduce un telefono espanol valido.'), findsOneWidget);
    expect(
      find.text('La contrasena debe tener al menos 8 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('Debes aceptar la Politica de Privacidad.'),
      findsOneWidget,
    );
  });

  testWidgets('appointments tab opens appointment detail', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('nav-appointments')));
    await tester.pumpAndSettle();
    final pendingAppointment = find.textContaining('09:30 - 10:15 - 45 min');
    await tester.ensureVisible(pendingAppointment);
    await tester.tap(pendingAppointment);
    await tester.pumpAndSettle();

    expect(find.text('Detalle de la Cita'), findsOneWidget);
    expect(find.text('FC-1047'), findsOneWidget);
  });

  testWidgets('booking request uses createAppointment with selected slot', (
    tester,
  ) async {
    final bookingDate = _futureBookingDate();
    final bookingDateLabel = _calendarDateLabel(bookingDate);
    final expectedWireDate = _wireDate(bookingDate);
    final portalRepository = _fakePortalRepository();
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await tester.tap(find.text('Reservar Sesion').first);
    await tester.pumpAndSettle();

    expect(find.text('Reservar Sesion'), findsOneWidget);
    expect(find.textContaining('requestAppointment'), findsNothing);
    await _bookingContinueUntil(tester, find.text('30'));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    await _bookingContinueUntil(
      tester,
      find.text(_calendarHeaderLabel(_todayDate())),
    );
    expect(find.text(_calendarHeaderLabel(_todayDate())), findsOneWidget);

    await tester.tap(find.text(bookingDateLabel));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('08:00').first);
    await tester.pumpAndSettle();
    await _submitVisibleBooking(tester);

    expect(portalRepository.requests, hasLength(1));
    await tester.drag(find.byType(ListView), const Offset(0, 1000));
    await tester.pump();
    expect(find.text('Solicitud Enviada'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
    expect(portalRepository.requests.single.durationMinutes, 45);
    expect(portalRepository.requests.single.reason, '');
    expect(
      portalRepository.requests.single.preferredSlot.date,
      expectedWireDate,
    );
  });

  testWidgets('booking disables slots that do not fit selected duration', (
    tester,
  ) async {
    final bookingDateLabel = _calendarDateLabel(_futureBookingDate());
    final portalRepository = _fakePortalRepository(
      siteConfig: const SiteConfig(
        startHour: 8,
        endHour: 21,
        slotInterval: 30,
        bonoExpirationMonths: 1,
        maintenanceMode: false,
        sessionDuration: 60,
      ),
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await tester.tap(find.text('Reservar Sesion').first);
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('60'));
    await tester.tap(find.text('60'));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text(bookingDateLabel));
    await tester.tap(find.text(bookingDateLabel));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('20:30'), findsOneWidget);
    expect(find.text('No disponible'), findsWidgets);
    await tester.tap(find.text('20:30'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elegida:'), findsNothing);
    _assertBookingCannotAdvance(tester);
    expect(portalRepository.requests, isEmpty);
  });

  testWidgets('changing duration clears a slot that becomes invalid', (
    tester,
  ) async {
    final bookingDateLabel = _calendarDateLabel(_futureBookingDate());
    final portalRepository = _fakePortalRepository(
      siteConfig: const SiteConfig(
        startHour: 8,
        endHour: 21,
        slotInterval: 30,
        bonoExpirationMonths: 1,
        maintenanceMode: false,
        sessionDuration: 60,
      ),
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await tester.tap(find.text('Reservar Sesion').first);
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text('30'));
    await tester.tap(find.text('30'));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(tester, find.text(bookingDateLabel));
    await tester.tap(find.text(bookingDateLabel));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20:30'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elegida:'), findsOneWidget);

    await tester.tap(find.text('Atras'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45'));
    await tester.pumpAndSettle();
    await _bookingContinueUntil(
      tester,
      find.byKey(const Key('booking-slot-grid')),
    );

    expect(find.textContaining('Elegida:'), findsNothing);
  });

  testWidgets('booking blocks slots that invade an own appointment', (
    tester,
  ) async {
    final bookingDate = _futureBookingDate();
    final bookingWireDate = _wireDate(bookingDate);
    final portalRepository = _fakePortalRepository(
      appointments: [
        Appointment(
          id: 'own-appointment',
          userId: 'test-user',
          name: 'Laura Perez',
          email: 'cliente@email.com',
          phone: '+34612345678',
          serviceType: 'Bono Mensual de Entrenamiento',
          durationMinutes: 30,
          preferredSlots: [TimeSlot(date: bookingWireDate, time: '13:30')],
          reason: '',
          status: AppointmentStatus.pending,
          createdAt: '2026-04-12T10:00:00.000Z',
        ),
      ],
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await _openBookingOnDate(
      tester,
      dateLabel: _calendarDateLabel(bookingDate),
    );
    await _scrollToBookingSlot(tester, '13:00');

    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('Tu sesion'), findsWidgets);
    await tester.tap(find.text('13:00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elegida:'), findsNothing);
    _assertBookingCannotAdvance(tester);
    expect(portalRepository.requests, isEmpty);
  });

  testWidgets('booking blocks slots that invade a full occupancy sub-slot', (
    tester,
  ) async {
    final bookingDate = _futureBookingDate();
    final bookingWireDate = _wireDate(bookingDate);
    final portalRepository = _fakePortalRepository(
      slotOccupancy: [
        SlotOccupancy(
          id: '${bookingWireDate}_13:30',
          date: bookingWireDate,
          time: '13:30',
          count: 2,
        ),
      ],
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await _openBookingOnDate(
      tester,
      dateLabel: _calendarDateLabel(bookingDate),
    );
    await _scrollToBookingSlot(tester, '13:00');

    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('Completo'), findsWidgets);
    await tester.tap(find.text('13:00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elegida:'), findsNothing);
    expect(portalRepository.requests, isEmpty);
  });

  testWidgets('booking allows slots with one remaining place', (tester) async {
    final bookingDate = _futureBookingDate();
    final bookingWireDate = _wireDate(bookingDate);
    final portalRepository = _fakePortalRepository(
      slotOccupancy: [
        SlotOccupancy(
          id: '${bookingWireDate}_13:30',
          date: bookingWireDate,
          time: '13:30',
          count: 1,
        ),
      ],
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1600),
    );

    await _openBookingOnDate(
      tester,
      dateLabel: _calendarDateLabel(bookingDate),
    );
    await _scrollToBookingSlot(tester, '13:00');

    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('1 plaza'), findsWidgets);
    await tester.tap(find.text('13:00'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Elegida:'), findsOneWidget);
    await _submitVisibleBooking(tester);

    expect(portalRepository.requests, hasLength(1));
    expect(portalRepository.requests.single.preferredSlot.time, '13:00');
    expect(portalRepository.requests.single.durationMinutes, 45);
    await tester.pump(const Duration(milliseconds: 901));
    await tester.pumpAndSettle();
  });

  test('fake portal stores createAppointment payload', () async {
    final repository = FakePortalRepository();
    await repository.createAppointment(
      const AppointmentRequest(
        durationMinutes: 60,
        preferredSlot: TimeSlot(date: '2026-04-18', time: '10:00'),
        reason: 'Trabajo suave.',
      ),
    );

    expect(repository.requests, hasLength(1));
    expect(repository.requests.single.durationMinutes, 60);
    expect(repository.requests.single.preferredSlot.time, '10:00');
    expect(repository.requests.single.reason, 'Trabajo suave.');
  });

  test('recurring payload uses the backend client contract', () {
    const request = RecurringAppointmentRequest(
      durationMinutes: 60,
      preferredSlot: TimeSlot(date: '2026-09-10', time: '18:00'),
      intervalDays: 3,
      endDate: '2026-09-19',
      comment: 'Trabajo de fuerza.',
    );

    expect(request.toCallablePayload(), {
      'date': '2026-09-10',
      'time': '18:00',
      'durationMinutes': 60,
      'intervalDays': 3,
      'endDate': '2026-09-19',
      'comment': 'Trabajo de fuerza.',
    });
    expect(request.toCallablePayload().containsKey('startDate'), isFalse);
    expect(request.toCallablePayload().containsKey('startTime'), isFalse);
    expect(request.toCallablePayload().containsKey('serviceType'), isFalse);
    expect(request.toCallablePayload().containsKey('assignedTrainer'), isFalse);
    expect(request.toCallablePayload()['duration'], isNull);
    expect(request.toCallablePayload()['durationMinutes'], isA<int>());
  });

  test('createRecurringAppointments records a single request', () async {
    final repository = FakePortalRepository();
    await repository.createRecurringAppointments(
      const RecurringAppointmentRequest(
        durationMinutes: 60,
        preferredSlot: TimeSlot(date: '2026-09-10', time: '18:00'),
        intervalDays: 3,
        endDate: '2026-09-19',
        comment: '',
      ),
    );

    expect(repository.recurringRequests, hasLength(1));
    expect(repository.requests, isEmpty);
  });

  test(
    'view model keeps individual and recurring callables separate',
    () async {
      final repository = FakePortalRepository();
      final viewModel = ClientPortalViewModel(
        repository: repository,
        uid: 'uid',
      );

      await viewModel.createAppointment(
        durationMinutes: 45,
        preferredSlot: const TimeSlot(date: '2026-09-10', time: '10:00'),
        reason: '',
      );
      await viewModel.createRecurringAppointments(
        durationMinutes: 60,
        preferredSlot: const TimeSlot(date: '2026-09-10', time: '18:00'),
        intervalDays: 3,
        endDate: '2026-09-19',
        reason: 'Serie',
      );
      await viewModel.cancelRecurringAppointmentSeries('series-1');

      expect(repository.requests, hasLength(1));
      expect(repository.recurringRequests, hasLength(1));
      expect(repository.cancelledSeriesIds, ['series-1']);
      viewModel.dispose();
    },
  );

  test('recurring series by id are stored in portal state', () async {
    final series = RecurringAppointmentSeries(
      id: 'series-1',
      userId: 'uid',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 60,
      startDate: '2026-09-10',
      startTime: '18:00',
      intervalDays: 3,
      endDate: '2026-09-19',
      occurrenceCount: 4,
      totalMinutes: 240,
      bonoId: 'bono-1',
      status: AppointmentStatus.pending,
      origin: RecurringSeriesOrigin.client,
      createdAt: '2026-09-01T10:00:00.000Z',
    );
    final repository = FakePortalRepository(recurringSeries: [series]);
    final viewModel = ClientPortalViewModel(repository: repository, uid: 'uid')
      ..start();
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.state.recurringSeriesById['series-1']?.intervalDays, 3);
    expect(viewModel.state.recurringSeriesById['series-1']?.occurrenceCount, 4);
    viewModel.dispose();
  });

  test(
    'exhausted bono after a series does not hide pending appointments',
    () async {
      final pending = Appointment(
        id: 'pending-1',
        userId: 'uid',
        name: 'Cliente',
        email: 'cliente@example.com',
        phone: '+34600000000',
        serviceType: 'Bono Mensual de Entrenamiento',
        durationMinutes: 60,
        preferredSlots: const [TimeSlot(date: '2026-09-10', time: '18:00')],
        reason: '',
        status: AppointmentStatus.pending,
        createdAt: '2026-09-01T10:00:00.000Z',
        recurrenceSeriesId: 'series-1',
        recurrenceIndex: 0,
      );
      final spentBono = Bono(
        id: 'bono-1',
        userId: 'uid',
        tamano: 240,
        minutosTotales: 240,
        minutosRestantes: 0,
        fechaAsignacion: '2026-09-01',
        fechaExpiracion: '2026-10-31',
        estado: BonoStatus.agotado,
        historial: const [],
        asignadoPor: 'admin',
        createdAt: '2026-09-01T10:00:00.000Z',
      );
      final repository = FakePortalRepository(
        appointments: [pending],
        bonos: [spentBono],
      );
      final viewModel = ClientPortalViewModel(
        repository: repository,
        uid: 'uid',
      )..start();
      await Future<void>.delayed(Duration.zero);

      expect(viewModel.state.activeBono, isNull);
      expect(viewModel.state.error, isNull);
      expect(viewModel.state.appointments, hasLength(1));
      expect(viewModel.state.appointments.single.isRecurring, isTrue);
      await viewModel.cancelRecurringAppointmentSeries('series-1');
      expect(repository.cancelledSeriesIds, ['series-1']);
      viewModel.dispose();
    },
  );

  test('maps createAppointment errors to Spanish messages', () {
    expect(
      appointmentRequestErrorMessage(
        _FakeFunctionsException(
          code: 'failed-precondition',
          message: 'Slot is full.',
        ),
      ),
      'Esta franja esta completa.',
    );
    expect(
      appointmentRequestErrorMessage(
        _FakeFunctionsException(
          code: 'unauthenticated',
          message: 'Authentication is required.',
        ),
      ),
      'Tu sesion ha caducado. Vuelve a iniciar sesion.',
    );
    expect(
      appointmentRequestErrorMessage(
        _FakeFunctionsException(
          code: 'failed-precondition',
          message: 'Slot does not fit schedule.',
        ),
      ),
      'Esta franja no está disponible para esta duración o restricción.',
    );
    expect(
      appointmentRequestErrorMessage(
        _FakeFunctionsException(
          code: 'failed-precondition',
          message:
              'No hay suficientes minutos en el bono. La serie requiere 240 min y quedan 180 min.',
        ),
      ),
      'No hay suficientes minutos en el bono. La serie requiere 240 min y quedan 180 min.',
    );
    expect(
      recurringSeriesMutationErrorMessage(
        _FakeFunctionsException(
          code: 'failed-precondition',
          message: 'Esta serie ya no se puede cancelar.',
        ),
      ),
      'Esta serie ya no se puede cancelar.',
    );
  });

  test('maps deleteOwnAccount errors to Spanish messages', () {
    expect(
      deleteOwnAccountErrorMessage(
        _FakeFunctionsException(
          code: 'unauthenticated',
          message: 'Authentication is required.',
        ),
      ),
      'Tu sesion ha caducado. Vuelve a iniciar sesion.',
    );
    expect(
      deleteOwnAccountErrorMessage(
        _FakeFunctionsException(
          code: 'unavailable',
          message: 'Network unavailable.',
        ),
      ),
      'No hay conexion. Revisa la red e intentalo de nuevo.',
    );
  });

  testWidgets('dashboard switches between appointment and pass history', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('nav-appointments')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Historial de bonos'), 400);
    expect(find.text('Historial de bonos'), findsOneWidget);

    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Expirado'), findsOneWidget);
  });

  testWidgets('profile saves visual changes', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    expect(find.text('LP'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Notificaciones Push'), findsNothing);
    await tester.tap(find.text('Datos personales'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar foto'), findsOneWidget);
    expect(find.text('Eliminar foto'), findsOneWidget);
    expect(find.text('Nueva contrasena'), findsOneWidget);
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil actualizado correctamente.'), findsOneWidget);
  });

  testWidgets('profile changes text size globally for the current session', (
    tester,
  ) async {
    await _pumpDashboard(tester, viewportSize: const Size(390, 844));

    final passTime = find.byKey(const Key('pass-available-time'));
    final defaultScale = _effectiveFontSize(tester, passTime);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('text-size-large')),
      300,
      scrollable: _profileScrollable(),
    );
    await tester.ensureVisible(find.byKey(const Key('text-size-large')));
    await tester.pumpAndSettle();
    expect(find.text('Tamaño de texto'), findsOneWidget);
    await tester.tap(find.byKey(const Key('text-size-large')));
    await tester.pumpAndSettle();

    expect(
      _effectiveFontSize(tester, find.text('Tamaño de texto')),
      closeTo(defaultScale * 1.15, 0.001),
    );
    expect(
      _effectiveFontSize(tester, find.byKey(const Key('nav-chat'))),
      closeTo(defaultScale * 1.15, 0.001),
    );

    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(
      _effectiveFontSize(tester, passTime),
      closeTo(defaultScale * 1.15, 0.001),
    );

    await tester.tap(find.byKey(const Key('nav-chat')));
    await tester.pumpAndSettle();
    expect(
      _effectiveFontSize(tester, find.text('Nueva conversación').first),
      closeTo(defaultScale * 1.15, 0.001),
    );
  });

  testWidgets('large text stacks dashboard metrics on a narrow screen', (
    tester,
  ) async {
    await _pumpDashboard(tester, viewportSize: const Size(320, 568));

    tester
        .widget<AppTextSizeScope>(find.byType(AppTextSizeScope))
        .onChanged(AppTextSize.large);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('pass-available-time')), findsOneWidget);
    expect(find.text('Reservar Sesion', skipOffstage: false), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Actividad reciente'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Actividad reciente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home layout stays stable at 320px', (tester) async {
    await _pumpDashboard(tester, viewportSize: kViewportSe);

    expect(find.byKey(const Key('pass-available-time')), findsOneWidget);
    expect(find.text('Reservar Sesion', skipOffstage: false), findsWidgets);
    expect(find.text('PROXIMA CITA', skipOffstage: false), findsOneWidget);
    expect(find.byKey(const Key('nav-home')), findsOneWidget);
    expect(find.byKey(const Key('nav-appointments')), findsOneWidget);
    expect(find.byKey(const Key('nav-chat')), findsOneWidget);
    expect(find.byKey(const Key('nav-profile')), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets('profile logout returns to auth', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesion'));
    await tester.tap(find.text('Cerrar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Focus Club Vallecas'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('profile delete account requires exact email confirmation', (
    tester,
  ) async {
    await _pumpDashboard(tester, viewportSize: const Size(800, 1300));

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-account-button')),
      800,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Zona de peligro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar cuenta definitivamente'), findsOneWidget);
    expect(
      find.textContaining('Esta accion eliminara tu cuenta'),
      findsOneWidget,
    );
    final confirmButton = find.byKey(
      const Key('confirm-delete-account-button'),
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-account-email-field')),
      'otro@email.com',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('delete-account-email-field')),
      'cliente@email.com',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);
  });

  testWidgets('profile delete account confirms and returns to auth', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final portalRepository = _fakePortalRepository();
    await _pumpDashboard(
      tester,
      authRepository: authRepository,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1300),
    );

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-account-button')),
      800,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-account-email-field')),
      'cliente@email.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete-account-button')));
    await tester.pumpAndSettle();

    expect(portalRepository.deleteOwnAccountCalls, 1);
    expect(authRepository.currentSession, isNull);
    expect(find.text('Focus Club Vallecas'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('profile delete account error stays on profile', (tester) async {
    final portalRepository = _fakePortalRepository(
      deleteOwnAccountFailure: _FakeFunctionsException(
        code: 'unauthenticated',
        message: 'Authentication is required.',
      ),
    );
    await _pumpDashboard(
      tester,
      portalRepository: portalRepository,
      viewportSize: const Size(800, 1300),
    );

    await tester.tap(find.byKey(const Key('nav-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('delete-account-button')),
      800,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('delete-account-email-field')),
      'cliente@email.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-delete-account-button')));
    await tester.pumpAndSettle();

    expect(portalRepository.deleteOwnAccountCalls, 1);
    expect(find.text('Perfil'), findsWidgets);
    expect(
      find.text('Tu sesion ha caducado. Vuelve a iniciar sesion.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAuth(
  WidgetTester tester, {
  _FakeAuthRepository? authRepository,
  FakePortalRepository? portalRepository,
  Size viewportSize = const Size(800, 1000),
}) async {
  _setTestViewport(tester, viewportSize);
  await tester.pumpWidget(
    FocusClubApp(
      authRepository: authRepository ?? _FakeAuthRepository(),
      portalRepository: portalRepository ?? _fakePortalRepository(),
      supportRepository: FakeSupportRepository(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pumpAndSettle();
}

Future<void> _openBookingOnDate(
  WidgetTester tester, {
  required String dateLabel,
}) async {
  await tester.tap(find.text('Reservar Sesion').first);
  await tester.pumpAndSettle();
  await _bookingContinueUntil(tester, find.text(dateLabel));
  await tester.tap(find.text(dateLabel));
  await tester.pumpAndSettle();
}

Future<void> _scrollToBookingSlot(WidgetTester tester, String time) async {
  await tester.scrollUntilVisible(
    find.text(time),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

DateTime _todayDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _futureBookingDate() => _todayDate().add(const Duration(days: 1));

String _calendarHeaderLabel(DateTime date) {
  return '${_monthLabel(date.month)} ${date.year}';
}

String _calendarDateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  return '$day ${_monthLabel(date.month)}';
}

String _wireDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _monthLabel(int month) {
  return const [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ][month - 1];
}

Future<void> _bookingContinueUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 8; i++) {
    await tester.pumpAndSettle();
    if (finder.evaluate().isNotEmpty) return;
    final next = find.widgetWithText(FilledButton, 'Continuar');
    if (next.evaluate().isEmpty) return;
    if (tester.widget<FilledButton>(next).onPressed == null) return;
    await tester.ensureVisible(next);
    await tester.tap(next);
  }
}

void _assertBookingCannotAdvance(WidgetTester tester) {
  expect(find.text('Enviar Solicitud'), findsNothing);
  final continueButton = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Continuar'),
  );
  expect(continueButton.onPressed, isNull);
}

Future<void> _submitVisibleBooking(WidgetTester tester) async {
  await _bookingContinueUntil(tester, find.text('Enviar Solicitud'));
  await tester.ensureVisible(find.text('Enviar Solicitud'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Enviar Solicitud'));
  await tester.pump();
}

FakePortalRepository _fakePortalRepository({
  SiteConfig? siteConfig,
  List<Appointment>? appointments,
  List<SlotOccupancy>? slotOccupancy,
  Object? deleteOwnAccountFailure,
}) {
  return FakePortalRepository(
    profile: const UserProfile(
      uid: 'test-user',
      email: 'cliente@email.com',
      name: 'Laura Perez',
      phone: '+34612345678',
      role: 'user',
      isTrainer: false,
      createdAt: '2026-04-01T10:00:00.000Z',
    ),
    appointments: appointments ?? _defaultAppointments(),
    bonos: const [
      Bono(
        id: 'active-bono',
        userId: 'test-user',
        tamano: 360,
        minutosTotales: 360,
        minutosRestantes: 180,
        fechaAsignacion: '2026-04-01T00:00:00.000Z',
        fechaExpiracion: '2026-04-30T00:00:00.000Z',
        estado: BonoStatus.activo,
        historial: [],
        asignadoPor: 'admin@email.com',
        createdAt: '2026-04-01T00:00:00.000Z',
      ),
      Bono(
        id: 'spent-bono',
        userId: 'test-user',
        tamano: 360,
        minutosTotales: 360,
        minutosRestantes: 0,
        fechaAsignacion: '2026-03-01T00:00:00.000Z',
        fechaExpiracion: '2026-03-31T00:00:00.000Z',
        estado: BonoStatus.agotado,
        historial: [
          BonoHistorialEntry(
            fecha: '2026-03-12T18:00:00.000Z',
            tipo: 'descuento',
            minutos: 60,
            appointmentId: 'FC-1042',
          ),
        ],
        asignadoPor: 'admin@email.com',
        createdAt: '2026-03-01T00:00:00.000Z',
      ),
      Bono(
        id: 'expired-bono',
        userId: 'test-user',
        tamano: 240,
        minutosTotales: 240,
        minutosRestantes: 120,
        fechaAsignacion: '2026-02-01T00:00:00.000Z',
        fechaExpiracion: '2026-02-28T00:00:00.000Z',
        estado: BonoStatus.expirado,
        historial: [],
        asignadoPor: 'admin@email.com',
        createdAt: '2026-02-01T00:00:00.000Z',
      ),
    ],
    trainers: const [
      Trainer(
        id: 'trainer-marta',
        uid: 'trainer-user',
        name: 'Marta Sanchez',
        active: true,
        createdAt: '2026-04-01T00:00:00.000Z',
        specialties: [],
      ),
    ],
    slotOccupancy: slotOccupancy ?? _defaultSlotOccupancy,
    siteConfig:
        siteConfig ??
        const SiteConfig(
          startHour: 8,
          endHour: 20,
          slotInterval: 30,
          bonoExpirationMonths: 1,
          maintenanceMode: false,
          sessionDuration: 60,
        ),
    deleteOwnAccountFailure: deleteOwnAccountFailure,
  );
}

List<Appointment> _defaultAppointments() {
  final firstDate = _wireDate(_todayDate().add(const Duration(days: 3)));
  final secondDate = _wireDate(_todayDate().add(const Duration(days: 6)));
  return [
    Appointment(
      id: 'FC-1042',
      userId: 'test-user',
      name: 'Laura Perez',
      email: 'cliente@email.com',
      phone: '+34612345678',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 60,
      preferredSlots: [TimeSlot(date: firstDate, time: '18:00')],
      reason: 'Trabajo de fuerza y movilidad de cadera.',
      status: AppointmentStatus.approved,
      createdAt: '2026-04-10T10:00:00.000Z',
      approvedSlot: TimeSlot(date: firstDate, time: '18:00'),
      assignedTrainer: 'trainer-marta',
      sessionType: 'Entrenamiento personal',
      updatedAt: '2026-04-10T10:05:00.000Z',
    ),
    Appointment(
      id: 'FC-1047',
      userId: 'test-user',
      name: 'Laura Perez',
      email: 'cliente@email.com',
      phone: '+34612345678',
      serviceType: 'Bono Mensual de Entrenamiento',
      durationMinutes: 45,
      preferredSlots: [TimeSlot(date: secondDate, time: '09:30')],
      reason: 'Preferencia por trabajo de tren superior.',
      status: AppointmentStatus.pending,
      createdAt: '2026-04-12T10:00:00.000Z',
    ),
  ];
}

const _defaultSlotOccupancy = [
  SlotOccupancy(
    id: '2026-04-30_19:30',
    date: '2026-04-30',
    time: '19:30',
    count: 1,
  ),
];

void _setTestViewport(
  WidgetTester tester, [
  Size size = const Size(800, 1000),
]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _effectiveFontSize(WidgetTester tester, Finder finder) {
  return MediaQuery.textScalerOf(tester.element(finder)).scale(20);
}

Finder _profileScrollable() {
  return find
      .descendant(
        of: find.byType(ListView).last,
        matching: find.byType(Scrollable),
      )
      .first;
}

Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Future<void> _pumpDashboard(
  WidgetTester tester, {
  _FakeAuthRepository? authRepository,
  FakePortalRepository? portalRepository,
  Size viewportSize = const Size(800, 1000),
}) async {
  await _pumpAuth(
    tester,
    authRepository: authRepository,
    portalRepository: portalRepository,
    viewportSize: viewportSize,
  );
  await _login(tester);
}

class _FakeFunctionsException extends FirebaseFunctionsException {
  _FakeFunctionsException({required super.code, required super.message});
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'cliente@email.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'Focus1234');
  await tester.ensureVisible(find.text('Entrar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.signInFailure});

  final Object? signInFailure;
  AuthSession? _session;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(_session);

  @override
  Future<AuthGateResult> resolveAuthGate() async {
    return _session == null
        ? AuthGateResult.signedOut
        : AuthGateResult.signedIn;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final failure = signInFailure;
    if (failure != null) throw failure;

    _session = AuthSession(
      uid: 'test-user',
      email: email,
      displayName: 'Laura Perez',
      isEmailVerified: true,
      canChangePassword: true,
    );
  }

  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {}

  @override
  Future<GoogleAuthResult> signInWithGoogle() async {
    _session = const AuthSession(
      uid: 'google-user',
      email: 'google@email.com',
      displayName: 'Laura Perez',
      isEmailVerified: true,
      canChangePassword: false,
    );
    return GoogleAuthResult(
      status: GoogleAuthStatus.needsProfile,
      session: _session!,
    );
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> resendEmailVerification({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    _session = null;
  }

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> updateSafeProfileFields({
    required String uid,
    required String name,
    required String phone,
    String? photoUrl,
  }) async {}
}
