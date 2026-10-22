import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [configProvider.overrideWithValue(config), sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const TuTurnoApp(),
    ),
  );
}
