import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';

/// Entry point for Voice POS.
///
/// Locks portrait orientation (Android-first, one-handed cashier use)
/// then runs the app. No async service initialization in Phase 0.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const VoicePosApp());
}
