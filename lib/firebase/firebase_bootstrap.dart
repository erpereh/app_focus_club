import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static const projectId = 'focus-club-f73b8';
  static const storageBucket = 'focus-club-f73b8.firebasestorage.app';

  static Future<void> initializeIfConfigured() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
}
