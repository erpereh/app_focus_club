import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase/firebase_bootstrap.dart';
import 'firebase/push_messaging_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeIfConfigured();
  await PushMessagingBootstrap.configure();

  runApp(FocusClubApp());
}
