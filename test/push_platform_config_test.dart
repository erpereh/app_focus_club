import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Native push configuration needed for production builds. The channel id is
/// shared with the backend (`ANDROID_NOTIFICATION_CHANNEL_ID` in
/// web_focus_club/functions/src/notifications/push.ts).
const _channelId = 'focus_club_default';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('Android creates the Focus Club channel and makes it the FCM default', () {
    final manifest = _read('android/app/src/main/AndroidManifest.xml');
    final strings = _read('android/app/src/main/res/values/strings.xml');
    final activity = _read(
      'android/app/src/main/kotlin/es/focusclub/clientes/app_focus_club/MainActivity.kt',
    );

    expect(
      manifest,
      contains(
        'android:name="com.google.firebase.messaging.default_notification_channel_id"',
      ),
    );
    expect(
      manifest,
      contains('android:value="@string/default_notification_channel_id"'),
    );
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(
      strings,
      contains(
        '<string name="default_notification_channel_id" translatable="false">$_channelId</string>',
      ),
    );
    expect(activity, contains('"$_channelId"'));
    expect(activity, contains('IMPORTANCE_HIGH'));
    expect(activity, contains('createNotificationChannel'));
  });

  test('iOS Release builds use the production APNs environment', () {
    final project = _read('ios/Runner.xcodeproj/project.pbxproj');
    final release = _read('ios/Runner/RunnerRelease.entitlements');
    final debug = _read('ios/Runner/Runner.entitlements');
    final infoPlist = _read('ios/Runner/Info.plist');

    expect(release, contains('<string>production</string>'));
    expect(debug, contains('<string>development</string>'));
    expect(infoPlist, contains('<string>remote-notification</string>'));

    // Each XCBuildConfiguration block ends with `name = <config>;`.
    final blocks = RegExp(
      r'buildSettings = \{([^}]*)\};\s*name = (\w+);',
    ).allMatches(project);
    final entitlementsByConfig = <String, Set<String>>{};
    for (final block in blocks) {
      final entitlement = RegExp(
        r'CODE_SIGN_ENTITLEMENTS = ([^;]+);',
      ).firstMatch(block.group(1)!);
      if (entitlement == null) continue;
      entitlementsByConfig
          .putIfAbsent(block.group(2)!, () => {})
          .add(entitlement.group(1)!);
    }

    expect(entitlementsByConfig['Release'], {
      'Runner/RunnerRelease.entitlements',
    });
    expect(entitlementsByConfig['Debug'], {'Runner/Runner.entitlements'});
    expect(entitlementsByConfig['Profile'], {'Runner/Runner.entitlements'});
  });
}
