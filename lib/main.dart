import 'package:flutter/material.dart';

import 'app/app.dart';
import 'firebase/firebase_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.initializeIfConfigured();

  runApp(const FocusClubApp());
}
