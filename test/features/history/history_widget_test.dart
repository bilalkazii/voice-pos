import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/cart/presentation/cart_providers.dart';
import 'package:voice_pos/features/checkout/presentation/checkout_providers.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/voice/presentation/voice_providers.dart';

import '../../test_utils.dart';
import '../voice/fakes.dart';

Future<AppDatabase> seedProduct(AppDatabase db) async {
  final repo = DriftProductRepository(db.productDao);
  await repo.create(
    name: 'Pepsi',
    sku: 'PEP-500',
    sellingPricePaise: 4000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
  return db;
}

Future<AppDatabase> seedSaleFromCheckout(
  AppDatabase db, {
  required String productName,
  required int price,
  required int quantity,
}) async {
  final repo = DriftProductRepository(db.productDao);
  final product = await repo.create(
    name: productName,
    sku: productName == 'Pepsi' ? 'PEP-500' : null,
    sellingPricePaise: price,
    costPricePaise: null,
    stockQty: 20,
    lowStockThreshold: 2,
  );
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  container.read(cartProvider.notifier).addProduct(product, quantity: quantity);
  await container.read(checkoutControllerProvider.notifier).confirmCashPayment();
  return db;
}

Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  AppDatabase? database,
  Future<AppDatabase> Function(AppDatabase db)? seed,
  FakeSpeechService? speech,
}) async {
  final db = database ?? openTestDb();
  if (seed != null) await seed(db);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (speech != null) speechServiceProvider.overrideWithValue(speech),
      ],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  return db;
}

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.text('History').first);
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('history list', () {
    testWidgets('renders sales newest first with details', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 2,
      );
      await seedSaleFromCheckout(db, productName: 'Maggi', price: 3000, quantity: 1);

      await pumpApp(tester, database: db);
      await openHistory(tester);

      expect(find.textContaining('VP-'), findsNWidgets(2));
      expect(find.textContaining('Cash'), findsNWidgets(2));
      expect(find.text('₹80.00'), findsOneWidget); // Pepsi 4000*2
      expect(find.text('₹30.00'), findsOneWidget); // Maggi
      expect(find.textContaining('2 items'), findsOneWidget);
      expect(find.textContaining('1 item'), findsOneWidget);
      expect(find.textContaining('Today'), findsWidgets);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('empty history shows the empty state', (tester) async {
      final db = await pumpApp(tester);
      await openHistory(tester);

      expect(find.text('No sales yet'), findsOneWidget);
      expect(find.text('Completed sales will appear here.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('today filter shows summary and today-only sales', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 2,
      );
      await pumpApp(tester, database: db);

      await tester.tap(find.text('History').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Switch to Today filter.
      await tester.tap(find.text('Today').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('₹80.00'), findsWidgets);
      expect(find.text('1 transaction'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('search filters by transaction number', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 1,
      );
      await seedSaleFromCheckout(db, productName: 'Maggi', price: 3000, quantity: 1);
      await pumpApp(tester, database: db);
      await openHistory(tester);

      expect(find.textContaining('VP-'), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 400));
      await pumpStreams(tester);

      expect(find.text('No transactions found'), findsOneWidget);
      expect(
        find.text('Try a different transaction number.'),
        findsOneWidget,
      );

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('search matches a transaction number case-insensitively', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 1,
      );
      await pumpApp(tester, database: db);
      await openHistory(tester);

      final txn = RegExp(r'VP-\d+-\d{4}').firstMatch(
        tester.widget<Text>(find.textContaining('VP-').first).data!,
      )!.group(0)!;

      await tester.enterText(find.byType(TextField), txn.toLowerCase());
      await tester.pump(const Duration(milliseconds: 400));
      await pumpStreams(tester);

      expect(find.textContaining('VP-'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('sale detail', () {
    testWidgets('tap opens detail with historical items and total', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 2,
      );
      await pumpApp(tester, database: db);
      await openHistory(tester);

      await tester.tap(find.textContaining('VP-').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Sale Detail'), findsOneWidget);
      expect(find.textContaining('VP-'), findsOneWidget);
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('2 × ₹40.00'), findsOneWidget);
      expect(find.text('₹80.00'), findsWidgets);
      expect(find.text('Cash'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('opens the existing receipt screen', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 1,
      );
      await pumpApp(tester, database: db);
      await openHistory(tester);

      await tester.tap(find.textContaining('VP-').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Receipt'), findsWidgets);
      expect(find.text('Paid by Cash'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('detail has no edit/delete/refund controls', (tester) async {
      final db = await seedSaleFromCheckout(
        openTestDb(),
        productName: 'Pepsi',
        price: 4000,
        quantity: 1,
      );
      await pumpApp(tester, database: db);
      await openHistory(tester);

      await tester.tap(find.textContaining('VP-').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Refund'), findsNothing);
      expect(find.text('Void'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('checkout → history integration', () {
    testWidgets('a new sale appears in history after checkout', (tester) async {
      final db = await seedProduct(openTestDb());
      final speech = FakeSpeechService();
      await pumpApp(tester, database: db, speech: speech);

      // Add to cart via the picker and complete checkout.
      await tester.tap(find.text('Add Product'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await tester.tap(find.text('Pepsi'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await expireSnackbars(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'CHECKOUT'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Payment Complete!'), findsOneWidget);

      // NEW SALE returns to the empty bill, then open History.
      await tester.tap(find.widgetWithText(FilledButton, 'NEW SALE'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await openHistory(tester);

      expect(find.textContaining('VP-'), findsOneWidget);
      expect(find.textContaining('Cash'), findsOneWidget);
      expect(find.text('₹40.00'), findsWidgets);

      await disposeAndCloseDb(tester, db);
    });
  });
}
