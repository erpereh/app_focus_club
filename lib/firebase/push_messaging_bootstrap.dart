import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';

/// Runs in a background isolate when a push arrives while the app is in the
/// background or terminated. The backend always sends a `notification` block,
/// so the OS shows it and the history is already in Firestore: nothing to
/// display or store here.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.initializeIfConfigured();
}

class PushMessagingBootstrap {
  const PushMessagingBootstrap._();

  static Future<void> configure() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // The in-app banner handles foreground pushes; showing the system
      // banner too would duplicate the notice.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: false,
            badge: true,
            sound: false,
          );
    }
  }
}
