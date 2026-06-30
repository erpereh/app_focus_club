import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/application/client_portal_view_model.dart';
import 'package:app_focus_club/features/client/application/portal_scope.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/data/push_notification_service.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/presentation/profile_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('iOS activation failure shows iPhone permissions message', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(
        _ProfileHarness(
          pushNotificationService: _FailingPushNotificationService(),
        ),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No hemos podido activar las notificaciones. Revisa los permisos del iPhone e intentalo de nuevo.',
        ),
        findsOneWidget,
      );
    });
  });
}

class _ProfileHarness extends StatelessWidget {
  const _ProfileHarness({required this.pushNotificationService});

  final FirebasePushNotificationService pushNotificationService;

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      repository: _ProfileAuthRepository(),
      child: PortalScope(
        repository: FakePortalRepository(profile: _profile),
        child: MaterialApp(
          home: Scaffold(
            body: ProfileScreen(
              state: const ClientPortalState(profile: _profile),
              pushNotificationService: pushNotificationService,
            ),
          ),
        ),
      ),
    );
  }
}

class _FailingPushNotificationService extends FirebasePushNotificationService {
  @override
  Future<void> enableForUser({
    required String uid,
    required PortalRepository repository,
  }) async {
    throw const PushNotificationTokenUnavailable();
  }
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

const _profile = UserProfile(
  uid: 'test-user',
  email: 'cliente@email.com',
  name: 'Laura Perez',
  phone: '+34612345678',
  role: 'user',
  isTrainer: false,
  createdAt: '2026-04-01T10:00:00.000Z',
);
