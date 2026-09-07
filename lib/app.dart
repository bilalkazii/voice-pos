import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Root application widget for Voice POS.
///
/// Riverpod is enabled via the [ProviderScope] here. Widget tests can wrap
/// this widget in an outer `ProviderScope(overrides: [...])` — overrides
/// (e.g. an in-memory test database) are inherited by this inner scope.
class VoicePosApp extends StatelessWidget {
  const VoicePosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp.router(
        title: 'Voice POS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRouter.create(),
      ),
    );
  }
}
