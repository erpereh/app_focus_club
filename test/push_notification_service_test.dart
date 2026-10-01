import 'dart:async';

import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/data/push_notification_service.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/client/domain/recurring_booking_availability.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'iOS denied permission does not request tokens or enable Firestore',
    () async {
      final messaging = _FakePushMessagingClient(
        authorizationStatus: AuthorizationStatus.denied,
        fcmToken: 'fcm-token',
      );
      final repository = _RecordingPortalRepository();
      final service = FirebasePushNotificationService(
        messaging: messaging,
        targetPlatform: TargetPlatform.iOS,
        delay: (_) async {},
        debugLog: (_) {},
      );

      await expectLater(
        service.enableForUser(uid: 'uid', repository: repository),
        throwsA(isA<PushNotificationPermissionDenied>()),
      );

      expect(messaging.requestPermissionCalls, 1);
      expect(messaging.apnsTokenCalls, 0);
      expect(messaging.getTokenCalls, 0);
      expect(repository.savedTokens, isEmpty);
      expect(repository.pushUpdates, isEmpty);
    },
  );

  test('iOS waits for APNs before requesting and saving FCM token', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      apnsTokens: [null, null, 'apns-token'],
      fcmToken: 'fcm-token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.iOS,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);

    expect(messaging.requestPermissionCalls, 1);
    expect(messaging.apnsTokenCalls, 3);
    expect(messaging.getTokenCalls, 1);
    expect(repository.savedTokens, [
      (uid: 'uid', token: 'fcm-token', platform: 'ios'),
    ]);
    expect(repository.pushUpdates, [(uid: 'uid', enabled: true)]);
  });

  test('iOS throws when APNs never becomes available', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      apnsTokens: List<String?>.filled(10, null),
      fcmToken: 'fcm-token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.iOS,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await expectLater(
      service.enableForUser(uid: 'uid', repository: repository),
      throwsA(isA<PushNotificationTokenUnavailable>()),
    );

    expect(messaging.apnsTokenCalls, 10);
    expect(messaging.getTokenCalls, 0);
    expect(repository.savedTokens, isEmpty);
    expect(repository.pushUpdates, isEmpty);
  });

  test('Android keeps direct FCM activation flow', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'android-fcm-token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);

    expect(messaging.requestPermissionCalls, 1);
    expect(messaging.apnsTokenCalls, 0);
    expect(messaging.getTokenCalls, 1);
    expect(repository.savedTokens, [
      (uid: 'uid', token: 'android-fcm-token', platform: 'android'),
    ]);
    expect(repository.pushUpdates, [(uid: 'uid', enabled: true)]);
  });

  test('disable does not request permissions or tokens', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'fcm-token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.iOS,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.disableForUser(uid: 'uid', repository: repository);

    expect(messaging.requestPermissionCalls, 0);
    expect(messaging.apnsTokenCalls, 0);
    expect(messaging.getTokenCalls, 0);
    expect(repository.savedTokens, isEmpty);
    expect(repository.pushUpdates, [(uid: 'uid', enabled: false)]);
  });

  test('token refresh saves the new token and removes the old one', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'old-token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);
    expect(service.currentToken, 'old-token');

    messaging.emitTokenRefresh('new-token');
    await pumpEventQueue();

    expect(repository.savedTokens.map((entry) => entry.token), [
      'old-token',
      'new-token',
    ]);
    expect(repository.deletedTokens, [(uid: 'uid', token: 'old-token')]);
    expect(service.currentToken, 'new-token');
  });

  test('token refresh is ignored while push is disabled', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);
    await service.disableForUser(uid: 'uid', repository: repository);
    messaging.emitTokenRefresh('new-token');
    await pumpEventQueue();

    expect(repository.savedTokens.map((entry) => entry.token), ['token']);
    expect(repository.deletedTokens, isEmpty);
  });

  test('configureForUser registers the token of an enabled user', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.configureForUser(
      uid: 'uid',
      enabled: true,
      repository: repository,
    );

    expect(messaging.requestPermissionCalls, 0);
    expect(repository.savedTokens.single.token, 'token');
    expect(service.currentToken, 'token');
  });

  test('unregisterCurrentDevice deletes the token doc and FCM token', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'token',
    );
    final repository = _RecordingPortalRepository();
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);
    await service.unregisterCurrentDevice(uid: 'uid', repository: repository);

    expect(repository.deletedTokens, [(uid: 'uid', token: 'token')]);
    expect(messaging.deleteTokenCalls, 1);
    expect(service.currentToken, isNull);
  });

  test(
    'unregisterCurrentDevice is a no-op without a registered token',
    () async {
      final messaging = _FakePushMessagingClient(
        authorizationStatus: AuthorizationStatus.authorized,
      );
      final repository = _RecordingPortalRepository();
      final service = FirebasePushNotificationService(
        messaging: messaging,
        targetPlatform: TargetPlatform.android,
        delay: (_) async {},
        debugLog: (_) {},
      );

      await service.unregisterCurrentDevice(uid: 'uid', repository: repository);

      expect(repository.deletedTokens, isEmpty);
      expect(messaging.deleteTokenCalls, 0);
    },
  );

  test('unregisterCurrentDevice never blocks logout on failures', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
      fcmToken: 'token',
      deleteTokenFailure: StateError('offline'),
    );
    final repository = _RecordingPortalRepository()
      ..deleteFailure = StateError('permission-denied');
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );

    await service.enableForUser(uid: 'uid', repository: repository);
    await expectLater(
      service.unregisterCurrentDevice(uid: 'uid', repository: repository),
      completes,
    );
  });

  test('foregroundMessages forwards pushes received in foreground', () async {
    final messaging = _FakePushMessagingClient(
      authorizationStatus: AuthorizationStatus.authorized,
    );
    final service = FirebasePushNotificationService(
      messaging: messaging,
      targetPlatform: TargetPlatform.android,
      delay: (_) async {},
      debugLog: (_) {},
    );
    final received = <RemoteMessage>[];
    final subscription = service.foregroundMessages.listen(received.add);

    messaging.emitMessage(
      const RemoteMessage(
        data: {
          'type': 'appointment_status',
          'event': 'appointment_confirmed',
          'route': 'appointment',
          'appointmentId': 'apt-1',
        },
      ),
    );
    await pumpEventQueue();

    expect(received.single.data['event'], 'appointment_confirmed');
    await subscription.cancel();
  });
}

class _FakePushMessagingClient implements PushMessagingClient {
  _FakePushMessagingClient({
    required this.authorizationStatus,
    this.apnsTokens = const [],
    this.fcmToken,
    this.deleteTokenFailure,
  });

  final AuthorizationStatus authorizationStatus;
  final List<String?> apnsTokens;
  final String? fcmToken;
  final Object? deleteTokenFailure;
  final _tokenRefreshController = StreamController<String>.broadcast();
  final _messageController = StreamController<RemoteMessage>.broadcast();
  int requestPermissionCalls = 0;
  int apnsTokenCalls = 0;
  int getTokenCalls = 0;
  int deleteTokenCalls = 0;

  void emitTokenRefresh(String token) => _tokenRefreshController.add(token);
  void emitMessage(RemoteMessage message) => _messageController.add(message);

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Stream<RemoteMessage> get onMessage => _messageController.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalls += 1;
    if (deleteTokenFailure != null) throw deleteTokenFailure!;
  }

  @override
  Future<String?> getAPNSToken() async {
    final index = apnsTokenCalls;
    apnsTokenCalls += 1;
    if (index >= apnsTokens.length) return null;
    return apnsTokens[index];
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    return fcmToken;
  }

  @override
  Future<NotificationSettings> requestPermission({
    required bool alert,
    required bool badge,
    required bool sound,
  }) async {
    requestPermissionCalls += 1;
    return _settings(authorizationStatus);
  }
}

class _RecordingPortalRepository implements PortalRepository {
  final savedTokens = <({String uid, String token, String platform})>[];
  final pushUpdates = <({String uid, bool enabled})>[];
  final deletedTokens = <({String uid, String token})>[];
  Object? deleteFailure;

  @override
  Future<void> deleteFcmToken({
    required String uid,
    required String token,
  }) async {
    if (deleteFailure != null) throw deleteFailure!;
    deletedTokens.add((uid: uid, token: token));
  }

  @override
  Future<void> createAppointment(AppointmentRequest request) async {}

  @override
  Future<void> cancelOwnAppointment(String appointmentId) async {}

  @override
  Future<void> updateOwnAppointmentSlot({
    required String appointmentId,
    required TimeSlot preferredSlot,
  }) async {}

  @override
  Future<void> rescheduleOwnRecurringAppointment({
    required String appointmentId,
    required TimeSlot preferredSlot,
  }) async {}

  @override
  Future<RecurringSeriesReplacementResult> replaceOwnRecurringSeriesSchedule({
    required String appointmentId,
    required TimeSlot startSlot,
    required int intervalDays,
    required String endDate,
  }) async {
    return const RecurringSeriesReplacementResult(
      success: true,
      seriesId: 'series-id',
      affectedAppointmentIds: [],
      reusedAppointmentIds: [],
      createdAppointmentIds: [],
      cancelledAppointmentIds: [],
      occurrenceCount: 0,
      totalMinutes: 0,
      status: AppointmentStatus.pending,
    );
  }

  @override
  Future<void> createRecurringAppointments(
    RecurringAppointmentRequest request,
  ) async {}

  @override
  Future<void> cancelOwnRecurringAppointmentSeries(String seriesId) async {}

  @override
  Stream<List<RecurringAppointmentSeries>> watchRecurringSeriesByUser(
    String uid,
  ) => const Stream.empty();

  @override
  Future<RecurringAvailabilitySnapshot> getAvailabilityForDates(
    List<String> dates,
  ) async {
    return const RecurringAvailabilitySnapshot();
  }

  @override
  Future<void> deleteOwnAccount() async {}

  @override
  Future<void> saveFcmToken({
    required String uid,
    required String token,
    required String platform,
  }) async {
    savedTokens.add((uid: uid, token: token, platform: platform));
  }

  @override
  Future<void> setPushNotificationsEnabled({
    required String uid,
    required bool enabled,
  }) async {
    pushUpdates.add((uid: uid, enabled: enabled));
  }

  @override
  Stream<List<Trainer>> watchActiveTrainers() => const Stream.empty();

  @override
  Stream<List<Appointment>> watchAppointmentsByUser(String uid) =>
      const Stream.empty();

  @override
  Stream<List<BlockedSlot>> watchBlockedSlotsForRange({
    required String startDate,
    required String endDate,
  }) => const Stream.empty();

  @override
  Stream<List<Bono>> watchBonosByUser(String uid) => const Stream.empty();

  @override
  Stream<SiteConfig?> watchSiteConfig() => const Stream.empty();

  @override
  Stream<List<SlotOccupancy>> watchSlotOccupancyForRange({
    required String startDate,
    required String endDate,
  }) => const Stream.empty();

  @override
  Stream<UserProfile?> watchUserProfile(String uid) => const Stream.empty();
}

NotificationSettings _settings(AuthorizationStatus status) {
  return NotificationSettings(
    alert: AppleNotificationSetting.enabled,
    announcement: AppleNotificationSetting.disabled,
    authorizationStatus: status,
    badge: AppleNotificationSetting.enabled,
    carPlay: AppleNotificationSetting.disabled,
    lockScreen: AppleNotificationSetting.enabled,
    notificationCenter: AppleNotificationSetting.enabled,
    showPreviews: AppleShowPreviewSetting.always,
    timeSensitive: AppleNotificationSetting.disabled,
    criticalAlert: AppleNotificationSetting.disabled,
    sound: AppleNotificationSetting.enabled,
    providesAppNotificationSettings: AppleNotificationSetting.disabled,
  );
}
