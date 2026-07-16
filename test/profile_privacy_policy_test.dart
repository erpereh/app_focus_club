import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/application/portal_scope.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/profile_screen.dart';
import 'package:app_focus_club/theme/app_text_size.dart';
import 'package:app_focus_club/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

const _privacyPolicyUrl = 'https://focusclub.es/politica-de-privacidad';
const _privacyPolicyKey = Key('privacy-policy-link');

void main() {
  testWidgets('profile shows the compact Legal privacy policy row', (
    tester,
  ) async {
    await _pumpProfile(tester, urlLauncher: (_) async => true);

    await _scrollToPrivacyPolicy(tester);

    expect(find.text('Ajustes'), findsOneWidget);
    expect(find.text('Tamaño de texto'), findsOneWidget);
    expect(find.text('Legal'), findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    expect(find.text('Zona de peligro'), findsOneWidget);
  });

  testWidgets('privacy policy row launches the exact external URL', (
    tester,
  ) async {
    Uri? launchedUri;
    await _pumpProfile(
      tester,
      urlLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    await _scrollToPrivacyPolicy(tester);
    await tester.tap(find.byKey(_privacyPolicyKey));
    await tester.pump();

    expect(launchedUri, Uri.parse(_privacyPolicyUrl));
    expect(
      find.text('No se ha podido abrir la política de privacidad.'),
      findsNothing,
    );
  });

  testWidgets(
    'privacy policy row shows an error when launching returns false',
    (tester) async {
      await _pumpProfile(tester, urlLauncher: (_) async => false);

      await _scrollToPrivacyPolicy(tester);
      await tester.tap(find.byKey(_privacyPolicyKey));
      await tester.pump();

      expect(
        find.text('No se ha podido abrir la política de privacidad.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('privacy policy row shows an error when launching throws', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      urlLauncher: (_) => Future<bool>.error(Exception('launcher failed')),
    );

    await _scrollToPrivacyPolicy(tester);
    await tester.tap(find.byKey(_privacyPolicyKey));
    await tester.pump();

    expect(
      find.text('No se ha podido abrir la política de privacidad.'),
      findsOneWidget,
    );
  });

  testWidgets('privacy policy row supports large text on a narrow screen', (
    tester,
  ) async {
    await _pumpProfile(
      tester,
      urlLauncher: (_) async => true,
      viewportSize: const Size(320, 568),
      textSize: AppTextSize.large,
    );

    await _scrollToPrivacyPolicy(tester);

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(_privacyPolicyKey)).height,
      greaterThanOrEqualTo(48),
    );
    final semantics = tester.getSemantics(find.byKey(_privacyPolicyKey));
    final semanticsData = semantics.getSemanticsData();
    expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
    expect(semanticsData.flagsCollection.isLink, isTrue);
  });
}

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Future<bool> Function(Uri) urlLauncher,
  Size viewportSize = const Size(390, 844),
  AppTextSize textSize = AppTextSize.defaultSize,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    AuthScope(
      repository: _ProfileAuthRepository(),
      child: PortalScope(
        repository: FakePortalRepository(profile: _profile),
        child: MaterialApp(
          theme: AppTheme.dark,
          home: AppTextSizeScope(
            textSize: textSize,
            onChanged: (_) {},
            child: Builder(
              builder: (context) => AppTextSizing.applyGlobally(
                context,
                child: Scaffold(
                  body: ProfileScreen(
                    state: const ClientPortalState(profile: _profile),
                    urlLauncher: urlLauncher,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToPrivacyPolicy(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(_privacyPolicyKey),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

class _ProfileAuthRepository implements AuthRepository {
  @override
  AuthSession? get currentSession => const AuthSession(
    uid: 'test-user',
    email: 'cliente@email.com',
    isEmailVerified: true,
    canChangePassword: true,
  );

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(currentSession);

  @override
  Future<AuthGateResult> resolveAuthGate() async => AuthGateResult.signedIn;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {}

  @override
  Future<GoogleAuthResult> signInWithGoogle() async {
    throw UnimplementedError();
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

const _profile = UserProfile(
  uid: 'test-user',
  email: 'cliente@email.com',
  name: 'Laura Perez',
  phone: '+34612345678',
  role: 'user',
  isTrainer: false,
  createdAt: '2026-04-01T10:00:00.000Z',
);
