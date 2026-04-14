import 'package:app_focus_club/app/app.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders splash and moves to auth', (tester) async {
    _setTestViewport(tester);
    await tester.pumpWidget(
      FocusClubApp(
        authRepository: _FakeAuthRepository(),
        portalRepository: _fakePortalRepository(),
      ),
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
    expect(find.text('Citas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
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

  testWidgets('google button opens complete profile flow and dashboard', (
    tester,
  ) async {
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

    await tester.tap(find.text('Citas').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text('Lunes, 20 abr - 09:30 - 10:15 - 45 min'),
    );
    await tester.tap(find.text('Lunes, 20 abr - 09:30 - 10:15 - 45 min'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de la Cita'), findsOneWidget);
    expect(find.text('FC-1047'), findsOneWidget);
  });

  testWidgets('booking request shows real availability and blocks submit', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('Reservar Sesion').first);
    await tester.pumpAndSettle();

    expect(find.text('Reservar Sesion'), findsOneWidget);
    expect(find.textContaining('requestAppointment'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('abr 2026'), findsOneWidget);
  });

  testWidgets('dashboard switches between appointment and pass history', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    await tester.scrollUntilVisible(find.text('Historial Citas'), 400);
    expect(find.text('Historial Citas'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Historial Bonos'), 400);
    await tester.tap(find.text('Historial Bonos'));
    await tester.pumpAndSettle();

    expect(find.text('Agotado'), findsOneWidget);
    expect(find.text('Expirado'), findsOneWidget);
  });

  testWidgets('profile saves visual changes', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar cambios'));
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(find.text('Perfil actualizado correctamente.'), findsOneWidget);
  });

  testWidgets('profile logout returns to auth', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('Perfil').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cerrar sesion'));
    await tester.tap(find.text('Cerrar sesion'));
    await tester.pumpAndSettle();

    expect(find.text('Focus Club Vallecas'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}

Future<void> _pumpAuth(
  WidgetTester tester, {
  _FakeAuthRepository? authRepository,
}) async {
  _setTestViewport(tester);
  await tester.pumpWidget(
    FocusClubApp(
      authRepository: authRepository ?? _FakeAuthRepository(),
      portalRepository: _fakePortalRepository(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 950));
  await tester.pumpAndSettle();
}

PortalRepository _fakePortalRepository() {
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
    appointments: const [
      Appointment(
        id: 'FC-1042',
        userId: 'test-user',
        name: 'Laura Perez',
        email: 'cliente@email.com',
        phone: '+34612345678',
        serviceType: 'Bono Mensual de Entrenamiento',
        durationMinutes: 60,
        preferredSlots: [TimeSlot(date: '2026-04-17', time: '18:00')],
        reason: 'Trabajo de fuerza y movilidad de cadera.',
        status: AppointmentStatus.approved,
        createdAt: '2026-04-10T10:00:00.000Z',
        approvedSlot: TimeSlot(date: '2026-04-17', time: '18:00'),
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
        preferredSlots: [TimeSlot(date: '2026-04-20', time: '09:30')],
        reason: 'Preferencia por trabajo de tren superior.',
        status: AppointmentStatus.pending,
        createdAt: '2026-04-12T10:00:00.000Z',
      ),
    ],
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
    slotOccupancy: const [
      SlotOccupancy(
        id: '2026-04-30_19:30',
        date: '2026-04-30',
        time: '19:30',
        count: 1,
      ),
    ],
    siteConfig: const SiteConfig(
      startHour: 8,
      endHour: 20,
      slotInterval: 30,
      bonoExpirationMonths: 1,
      maintenanceMode: false,
      sessionDuration: 60,
    ),
  );
}

void _setTestViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDashboard(WidgetTester tester) async {
  await _pumpAuth(tester);
  await _login(tester);
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'cliente@email.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'Focus1234');
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
