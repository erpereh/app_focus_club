import 'package:app_focus_club/features/auth/application/auth_scope.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/application/portal_scope.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/presentation/client_shell_screen.dart';
import 'package:app_focus_club/features/support/application/support_scope.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:app_focus_club/features/support/domain/support_conversation.dart';
import 'package:app_focus_club/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('support message notification routes to the Chat tab', () {
    expect(
      AppRouter.dashboardTabForNotificationType('support_message'),
      AppRouter.dashboardTabChat,
    );
    expect(
      AppRouter.dashboardTabForNotificationType('appointment_status'),
      AppRouter.dashboardTabAppointments,
    );
  });

  testWidgets(
    'shell adds Chat between appointments and profile with unread badge',
    (tester) async {
      const conversation = SupportConversation(
        id: 'conversation-1',
        userId: 'user-1',
        userName: 'Laura',
        userEmail: 'laura@example.com',
        status: 'open',
        subject: 'Mi bono',
        lastMessage: 'Te respondemos pronto',
        lastMessageAt: null,
        lastMessageBy: 'admin-1',
        unreadAdminCount: 0,
        unreadCustomerCount: 2,
        createdAt: null,
        updatedAt: null,
      );
      await tester.pumpWidget(
        AuthScope(
          repository: _AuthRepository(),
          child: PortalScope(
            repository: FakePortalRepository(),
            child: SupportScope(
              repository: FakeSupportRepository(conversations: [conversation]),
              child: const MaterialApp(home: ClientShellScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Citas'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Mi bono'), findsOneWidget);

      await tester.tap(find.text('Mi bono'));
      await tester.pumpAndSettle();
      expect(find.text('2'), findsNothing);
    },
  );
}

class _AuthRepository implements AuthRepository {
  @override
  AuthSession? get currentSession => const AuthSession(
    uid: 'user-1',
    email: 'laura@example.com',
    isEmailVerified: true,
    canChangePassword: true,
  );

  @override
  Stream<AuthSession?> authStateChanges() => Stream.value(currentSession);

  @override
  Future<AuthGateResult> resolveAuthGate() async => AuthGateResult.signedIn;

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
    throw UnimplementedError();
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
