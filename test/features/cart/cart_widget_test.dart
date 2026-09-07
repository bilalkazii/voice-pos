import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/cart/presentation/cart_screen.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product_repository.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/voice/domain/speech_services.dart';
import 'package:voice_pos/features/voice/presentation/voice_providers.dart';

import '../../test_utils.dart';
import '../voice/fakes.dart';

Future<AppDatabase> seedDb({
  Future<void> Function(ProductRepository repo)? seed,
}) async {
  final db = openTestDb();
  if (seed != null) {
    await seed(DriftProductRepository(db.productDao));
  }
  return db;
}

Future<void> createViaRepo(
  ProductRepository repo, {
  required String name,
  String? sku,
  int price = 2000,
  int stock = 10,
}) {
  return repo.create(
    name: name,
    sku: sku,
    sellingPricePaise: price,
    costPricePaise: null,
    stockQty: stock,
    lowStockThreshold: 2,
  );
}

/// Pumps just the cart screen (no router). Voice speech service can be
/// overridden with a fake; defaults to the real service (never invoked
/// unless a test taps SPEAK).
Future<AppDatabase> pumpCartScreen(
  WidgetTester tester, {
  Future<void> Function(ProductRepository repo)? seed,
  SpeechToTextService? speech,
}) async {
  final db = await seedDb(seed: seed);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (speech != null) speechServiceProvider.overrideWithValue(speech),
      ],
      child: const MaterialApp(home: CartScreen()),
    ),
  );
  await pumpStreams(tester);
  return db;
}

Future<void> addViaPicker(WidgetTester tester, String productName) async {
  await tester.tap(find.text('Add Product'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  await tester.tap(find.text(productName));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('empty cart', () {
    testWidgets('shows friendly empty state', (tester) async {
      final db = await pumpCartScreen(tester);

      expect(find.text('Current Bill'), findsOneWidget);
      expect(find.text('No items yet.'), findsOneWidget);
      expect(
        find.text('Add products manually to start a sale.'),
        findsOneWidget,
      );
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₹0.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('checkout is disabled when empty', (tester) async {
      final db = await pumpCartScreen(tester);

      final checkout =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'CHECKOUT'));
      expect(checkout.onPressed, isNull);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('speak button runs the voice flow (empty transcript)', (tester) async {
      final db = await pumpCartScreen(
        tester,
        speech: FakeSpeechService(transcript: null),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'SPEAK'));
      await tester.pumpAndSettle();

      // No speech recognized -> concise error, cart untouched.
      expect(find.text("Didn't catch that. Try again."), findsOneWidget);
      expect(find.text('No items yet.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('add product', () {
    testWidgets('picker adds the product with quantity 1', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );

      await addViaPicker(tester, 'Pepsi');

      expect(find.text('Added Pepsi.'), findsOneWidget);
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('1 × ₹20.00'), findsOneWidget);
      expect(find.text('₹20.00'), findsWidgets);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('picker search filters products', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) async {
          await createViaRepo(repo, name: 'Pepsi');
          await createViaRepo(repo, name: 'Maggi', sku: null);
        },
      );

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('Maggi'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'maggi');
      await tester.pump(const Duration(milliseconds: 400));
      await pumpStreams(tester);

      expect(find.text('Maggi'), findsOneWidget);
      expect(find.text('Pepsi'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('out-of-stock product cannot be added', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', stock: 0),
      );

      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Out of stock'), findsWidgets);
      // Disabled row: tapping does nothing, cart stays empty.
      await tester.tap(find.text('Pepsi'), warnIfMissed: false);
      await tester.pump();
      expect(find.text('Added Pepsi.'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('quantity controls', () {
    testWidgets('plus increments and total updates', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');

      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();

      expect(find.text('2 × ₹20.00'), findsOneWidget);
      // Line total and cart total coincide for a single line.
      expect(find.text('₹40.00'), findsNWidgets(2));

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('plus stops at stock with an error message', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) =>
            createViaRepo(repo, name: 'Pepsi', price: 2000, stock: 1),
      );
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);

      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();

      expect(find.text('Only 1 × "Pepsi" available.'), findsOneWidget);
      expect(find.text('1 × ₹20.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('minus decrements', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();
      expect(find.text('2 × ₹20.00'), findsOneWidget);

      await tester.tap(find.byTooltip('Decrease quantity'));
      await tester.pump();
      expect(find.text('1 × ₹20.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('minus at 1 removes the line', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');

      await tester.tap(find.byTooltip('Decrease quantity'));
      await tester.pump();

      expect(find.text('Pepsi'), findsNothing);
      expect(find.text('No items yet.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('remove button drops the line', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');

      await tester.tap(find.byTooltip('Remove item'));
      await tester.pump();

      expect(find.text('Pepsi'), findsNothing);
      expect(find.text('No items yet.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('totals', () {
    testWidgets('total sums lines across products', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) async {
          await createViaRepo(repo, name: 'Pepsi', price: 4000);
          await createViaRepo(repo, name: 'Maggi', price: 3000, sku: null);
        },
      );

      await addViaPicker(tester, 'Pepsi');
      await tester.tap(find.byTooltip('Increase quantity'));
      await tester.pump();
      // Back to the picker for the second product.
      await tester.tap(find.byTooltip('Add product'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await tester.tap(find.text('Maggi'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Pepsi 40×2 + Maggi 30×1 = ₹110.00.
      expect(find.text('2 × ₹40.00'), findsOneWidget);
      expect(find.text('1 × ₹30.00'), findsOneWidget);
      expect(find.text('₹110.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('clear cart', () {
    testWidgets('confirm clears the bill', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');

      await tester.tap(find.byTooltip('Clear bill'));
      await tester.pumpAndSettle();
      expect(find.text('Clear current bill?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Pepsi'), findsNothing);
      expect(find.text('No items yet.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('cancel keeps the bill', (tester) async {
      final db = await pumpCartScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await addViaPicker(tester, 'Pepsi');

      await tester.tap(find.byTooltip('Clear bill'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Pepsi'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('checkout navigation', () {
    testWidgets('checkout enabled with items, opens review screen', (tester) async {
      final db = await seedDb(
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', price: 2000),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const VoicePosApp(),
        ),
      );
      await pumpStreams(tester);

      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);

      final checkout =
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'CHECKOUT'));
      expect(checkout.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'CHECKOUT'));
      await tester.pumpAndSettle();

      // Real Phase 4 review screen: items, CASH badge, explicit confirm.
      expect(find.text('Review Bill'), findsOneWidget);
      expect(find.text('CASH'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
        findsOneWidget,
      );
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('₹20.00'), findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Current Bill'), findsOneWidget);
      expect(find.text('Pepsi'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });
}
