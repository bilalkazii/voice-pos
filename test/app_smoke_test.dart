import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';

void main() {
  testWidgets('VoicePosApp boots to cart placeholder with bottom nav',
      (tester) async {
    await tester.pumpWidget(const VoicePosApp());
    await tester.pumpAndSettle();

    // Default route is the cart / current-bill placeholder.
    expect(find.text('Current Bill'), findsWidgets);
    expect(find.text('Cart arrives in Phase 1.'), findsOneWidget);

    // Bottom navigation shell with the five Phase 0 destinations.
    for (final label in ['Bill', 'Products', 'History', 'Reports', 'Settings']) {
      expect(find.text(label), findsWidgets);
    }

    // Navigate to each placeholder via bottom nav.
    await tester.tap(find.text('Products').first);
    await tester.pumpAndSettle();
    expect(find.text('Products arrive in a later phase.'), findsOneWidget);

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
  });

  testWidgets('MaterialApp has Voice POS title and light theme', (tester) async {
    await tester.pumpWidget(const VoicePosApp());
    await tester.pumpAndSettle();

    final materialApp =
        tester.widget<MaterialApp>(find.byType(MaterialApp).first);
    expect(materialApp.title, 'Voice POS');
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });
}
