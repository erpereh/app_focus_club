import 'package:app_focus_club/app/app.dart';
import 'package:app_focus_club/features/app_update/data/installed_app_build_reader.dart';
import 'package:app_focus_club/features/app_update/domain/app_update_decision.dart';
import 'package:app_focus_club/features/auth/data/auth_repository.dart';
import 'package:app_focus_club/features/client/data/portal_repository.dart';
import 'package:app_focus_club/features/client/domain/portal_models.dart';
import 'package:app_focus_club/features/support/data/support_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const storeUrl = 'https://example.com/focus-club-android';

  group('resolveAppUpdate', () {
    test('installed 6 / min 0 is allowed', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 0,
        minIosBuild: 9,
        androidStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
      expect(decision.isRequired, isFalse);
    });

    test('installed 6 / min 6 is allowed', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 6,
        minIosBuild: 9,
        androidStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
    });

    test('installed 6 / min 7 with store URL is required', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 7,
        minIosBuild: 0,
        androidStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.required);
      expect(decision.storeUrl, Uri.parse(storeUrl));
    });

    test('Android uses minAndroidBuild and ignores minIosBuild', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 0,
        minIosBuild: 9,
        androidStoreUrl: storeUrl,
        iosStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
    });

    test('iOS uses minIosBuild and ignores minAndroidBuild', () {
      final allowed = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.ios,
        minAndroidBuild: 9,
        minIosBuild: 0,
        androidStoreUrl: storeUrl,
        iosStoreUrl: storeUrl,
      );
      final required = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.ios,
        minAndroidBuild: 0,
        minIosBuild: 7,
        androidStoreUrl: storeUrl,
        iosStoreUrl: storeUrl,
      );

      expect(allowed.status, AppUpdateStatus.allowed);
      expect(required.status, AppUpdateStatus.required);
      expect(required.storeUrl, Uri.parse(storeUrl));
    });

    test('unknown installed build is allowed even if min is higher', () {
      final decision = resolveAppUpdate(
        installedBuild: null,
        platform: AppStorePlatform.android,
        minAndroidBuild: 7,
        minIosBuild: 7,
        androidStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
      expect(decision.unenforceableBecauseMissingStoreUrl, isFalse);
    });

    test('required update without store URL stays allowed', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 7,
        minIosBuild: 0,
      );

      expect(decision.status, AppUpdateStatus.allowed);
      expect(decision.unenforceableBecauseMissingStoreUrl, isTrue);
    });

    test('http store URL is not treated as a valid store link', () {
      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: 7,
        minIosBuild: 0,
        androidStoreUrl: 'http://example.com/android',
      );

      expect(decision.status, AppUpdateStatus.allowed);
      expect(decision.unenforceableBecauseMissingStoreUrl, isTrue);
    });

    test('other platforms are never blocked', () {
      final decision = resolveAppUpdate(
        installedBuild: 1,
        platform: AppStorePlatform.other,
        minAndroidBuild: 99,
        minIosBuild: 99,
        androidStoreUrl: storeUrl,
        iosStoreUrl: storeUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
    });
  });

  group('SiteConfig version fields', () {
    test('legacy site config without version fields stays allowed', () {
      final config = SiteConfig.fromMap({
        'startHour': 8,
        'endHour': 20,
        'slotInterval': 30,
        'bonoExpirationMonths': 1,
        'maintenanceMode': false,
      });

      expect(config.minAndroidBuild, 0);
      expect(config.minIosBuild, 0);
      expect(config.latestAndroidBuild, 0);
      expect(config.latestIosBuild, 0);
      expect(config.androidStoreUrl, isNull);
      expect(config.iosStoreUrl, isNull);

      final decision = resolveAppUpdate(
        installedBuild: 6,
        platform: AppStorePlatform.android,
        minAndroidBuild: config.minAndroidBuild,
        minIosBuild: config.minIosBuild,
        androidStoreUrl: config.androidStoreUrl,
        iosStoreUrl: config.iosStoreUrl,
      );

      expect(decision.status, AppUpdateStatus.allowed);
    });
  });

  group('VersionGate', () {
    testWidgets('blocks the app when the installed build is below min', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final openedUrls = <Uri>[];
      await tester.pumpWidget(
        FocusClubApp(
          authRepository: _SignedOutAuthRepository(),
          portalRepository: FakePortalRepository(
            siteConfig: const SiteConfig(
              startHour: 8,
              endHour: 20,
              slotInterval: 30,
              bonoExpirationMonths: 1,
              maintenanceMode: false,
              minAndroidBuild: 7,
              androidStoreUrl: storeUrl,
            ),
          ),
          supportRepository: FakeSupportRepository(),
          installedAppBuildReader: const _FakeInstalledAppBuildReader(6),
          appStorePlatform: AppStorePlatform.android,
          storeUrlLauncher: (uri) async {
            openedUrls.add(uri);
            return true;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();

      expect(find.text('Actualizacion necesaria'), findsOneWidget);
      expect(find.text('Actualizar ahora'), findsOneWidget);
      expect(find.text('Portal del Cliente'), findsNothing);
      expect(find.text('Iniciar Sesion'), findsNothing);

      await tester.tap(find.text('Actualizar ahora'));
      await tester.pumpAndSettle();

      expect(openedUrls, [Uri.parse(storeUrl)]);
    });

    testWidgets('does not block when PackageInfo cannot be read', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        FocusClubApp(
          authRepository: _SignedOutAuthRepository(),
          portalRepository: FakePortalRepository(
            siteConfig: const SiteConfig(
              startHour: 8,
              endHour: 20,
              slotInterval: 30,
              bonoExpirationMonths: 1,
              maintenanceMode: false,
              minAndroidBuild: 7,
              androidStoreUrl: storeUrl,
            ),
          ),
          supportRepository: FakeSupportRepository(),
          installedAppBuildReader: const _FakeInstalledAppBuildReader(null),
          appStorePlatform: AppStorePlatform.android,
        ),
      );
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pumpAndSettle();

      expect(find.text('Actualizacion necesaria'), findsNothing);
      expect(find.text('Iniciar Sesion'), findsOneWidget);
    });
  });
}

class _FakeInstalledAppBuildReader implements InstalledAppBuildReader {
  const _FakeInstalledAppBuildReader(this.buildNumber);

  final int? buildNumber;

  @override
  Future<int?> readBuildNumber() async => buildNumber;
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
