import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/auth/presentation/auth_screen.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/layout_harness.dart';

void main() {
  testWidgets(
    'verification-email-failed switches to login and reuses resend action',
    (tester) async {
      setLogicalViewport(tester, const Size(400, 1400));
      final authRepository = _FakeAuthRepository(
        registerFailure: const AuthFailure('verification-email-failed'),
      );

      await tester.pumpWidget(_AuthHarness(repository: authRepository));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ana Lopez');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'nuevo@email.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), '612345678');
      await tester.enterText(find.byType(TextFormField).at(3), 'Focus1234');
      await tester.enterText(find.byType(TextFormField).at(4), 'Focus1234');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crear Cuenta'));
      await tester.tap(find.text('Crear Cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Crear Cuenta'), findsNothing);
      expect(find.text('Entrar'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller
            ?.text,
        'nuevo@email.com',
      );
      expect(
        find.text(
          'Tu cuenta se ha creado, pero no hemos podido enviar el email de verificación. Inicia sesión para volver a solicitarlo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reenviar email de verificacion'), findsOneWidget);

      await tester.ensureVisible(find.text('Reenviar email de verificacion'));
      await tester.tap(find.text('Reenviar email de verificacion'));
      await tester.pumpAndSettle();

      expect(authRepository.resendCalls, [('nuevo@email.com', 'Focus1234')]);
      expect(find.text('Email de verificacion reenviado.'), findsOneWidget);
    },
  );
}

class _AuthHarness extends StatelessWidget {
  const _AuthHarness({required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: repository,
      child: AppTextSizeScope(
        textSize: AppTextSize.defaultSize,
        onChanged: (_) {},
        child: MaterialApp(
          builder: (context, appChild) => AppTextSizing.applyGlobally(
            context,
            child: appChild ?? const SizedBox.shrink(),
          ),
          home: const AuthScreen(),
        ),
      ),
    );
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.registerFailure});

  final Object? registerFailure;
  final List<(String email, String password)> resendCalls = [];

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(null);

  @override
  AuthSession? get currentSession => null;

  @override
  Future<AuthGateResult> resolveAuthGate() async => AuthGateResult.signedOut;

  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final failure = registerFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> resendEmailVerification({
    required String email,
    required String password,
  }) async {
    resendCalls.add((email, password));
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<GoogleAuthResult> signInWithGoogle() async {
    throw UnsupportedError('Google sign-in is not used in this test.');
  }

  @override
  Future<void> signOut() async {}

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
