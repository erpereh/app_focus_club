import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/notifications/domain/notification_models.dart';
import 'package:app_focus_club/features/support/domain/support_conversation.dart';

Appointment testAppointment({
  String id = 'apt-1',
  String userId = 'user-1',
  String serviceType = 'Entrenamiento personal',
  AppointmentStatus status = AppointmentStatus.approved,
}) {
  return Appointment(
    id: id,
    userId: userId,
    name: 'Laura',
    email: 'laura@example.com',
    phone: '+34612345678',
    serviceType: serviceType,
    durationMinutes: 60,
    preferredSlots: const [TimeSlot(date: '2099-01-15', time: '10:00')],
    reason: '',
    status: status,
    createdAt: '2026-09-01T10:00:00.000Z',
  );
}

const testConversation = SupportConversation(
  id: 'conv-1',
  userId: 'user-1',
  userName: 'Laura',
  userEmail: 'laura@example.com',
  status: 'open',
  subject: 'Duda sobre mi bono',
  lastMessage: 'Te respondemos pronto',
  lastMessageAt: null,
  lastMessageBy: 'admin-1',
  unreadAdminCount: 0,
  unreadCustomerCount: 0,
  createdAt: null,
  updatedAt: null,
);

AppNotification testNotification({
  required String id,
  String type = 'appointment_status',
  String event = 'appointment_confirmed',
  String title = 'Cita confirmada',
  String body = 'Tu cita del 15/01 a las 10:00 está confirmada.',
  DateTime? createdAt,
  bool read = false,
  NotificationRoute? route = NotificationRoute.appointment,
  Map<String, String> params = const {'appointmentId': 'apt-1'},
}) {
  return AppNotification(
    id: id,
    type: type,
    event: event,
    title: title,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 9, 30, 10),
    read: read,
    appointmentId: params['appointmentId'],
    bonoId: params['bonoId'],
    conversationId: params['conversationId'],
    seriesId: params['seriesId'],
    navigationRoute: route,
    navigationParams: params,
  );
}

class TestAuthRepository implements AuthRepository {
  TestAuthRepository({this.uid = 'user-1'});

  final String? uid;

  @override
  AuthSession? get currentSession => uid == null
      ? null
      : AuthSession(
          uid: uid!,
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
