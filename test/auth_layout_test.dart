import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/auth/presentation/auth_screen.dart';
import 'package:app_focus_club/features/auth/presentation/reset_password_screen.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/layout_harness.dart';

void main() {
  testWidgets('login layout stays stable at 320px', (tester) async {
    setLogicalViewport(tester, kViewportSe);
    await tester.pumpWidget(_AuthHarness(child: const AuthScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Portal del Cliente'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expectNoLayoutException(tester);

    await tester.ensureVisible(find.text('Entrar'));
    expect(find.text('Continuar con Google'), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets('register layout stays stable at 320px with large text', (
    tester,
  ) async {
    setLogicalViewport(tester, kViewportSe);
    await tester.pumpWidget(
      _AuthHarness(largeText: true, child: const AuthScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Registrarse'));
    await tester.pumpAndSettle();
    expectNoLayoutException(tester);

    await tester.scrollUntilVisible(
      find.text('Crear Cuenta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Crear Cuenta'), findsOneWidget);
    expect(find.text('Acepto la Politica de Privacidad'), findsOneWidget);
    expectNoLayoutException(tester);
  });

  testWidgets('reset password layout stays stable at 320px', (tester) async {
    setLogicalViewport(tester, kViewportSe);
    await tester.pumpWidget(_AuthHarness(child: const ResetPasswordScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar Contrasena'), findsOneWidget);
    expect(find.text('Enviar enlace'), findsOneWidget);
    expectNoLayoutException(tester);
  });
}

class _AuthHarness extends StatelessWidget {
  const _AuthHarness({required this.child, this.largeText = false});

  final Widget child;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: _SignedOutAuthRepository(),
      child: AppTextSizeScope(
        textSize: largeText ? AppTextSize.large : AppTextSize.defaultSize,
        onChanged: (_) {},
        child: MaterialApp(
          builder: (context, appChild) => AppTextSizing.applyGlobally(
            context,
            child: appChild ?? const SizedBox.shrink(),
          ),
          home: child,
        ),
      ),
    );
  }
}

class _SignedOutAuthRepository implements AuthRepository {
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
  }) async {}

  @override
  Future<void> resendEmailVerification({
    required String email,
    required String password,
  }) async {}

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
