import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';

import 'test_utils.dart';

/// Boots the full app with an in-memory database override (the real
/// documents-directory database needs platform channels unavailable here).
Future<AppDatabase> pumpApp(WidgetTester tester) async {
  final db = AppDatabase(NativeDatabase.memory());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  return db;
}

void main() {
  testWidgets('VoicePosApp boots to cart placeholder with bottom nav',
      (tester) async {
    final db = await pumpApp(tester);

    // Default route is the cart / current-bill placeholder (Phase 2).
    expect(find.text('Current Bill'), findsWidgets);
    expect(find.text('Cart arrives in Phase 1.'), findsOneWidget);

    // Bottom navigation shell with the five destinations.
    for (final label in ['Bill', 'Products', 'History', 'Reports', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }

    // Products is now the real Phase 1 screen (empty database).
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();
    await pumpStreams(tester);
    expect(find.text('Search products or SKU'), findsOneWidget);
    expect(find.text('No products yet.'), findsOneWidget);

    // Remaining placeholders are untouched.
    await tester.tap(find.text('History').first);
    await tester.pumpAndSettle();
    expect(find.text('Sales history arrives in a later phase.'), findsOneWidget);

    await tester.tap(find.text('Reports').first);
    await tester.pumpAndSettle();
    expect(find.text('Reports arrive in a later phase.'), findsOneWidget);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('Settings arrive in a later phase.'), findsOneWidget);

    // Back to the cart default.
    await tester.tap(find.text('Bill').first);
    await tester.pumpAndSettle();
    expect(find.text('Cart arrives in Phase 1.'), findsOneWidget);

    await disposeAndCloseDb(tester, db);
  });

  testWidgets('MaterialApp has Voice POS title and light theme', (tester) async {
    final db = await pumpApp(tester);

    final materialApp =
        tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(materialApp.title, 'Voice POS');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);

    await disposeAndCloseDb(tester, db);
  });
}
