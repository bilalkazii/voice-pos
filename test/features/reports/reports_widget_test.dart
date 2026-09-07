import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/cart/presentation/cart_providers.dart';
import 'package:voice_pos/features/checkout/presentation/checkout_providers.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';

import '../../test_utils.dart';

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

/// Completes a real cash sale through the checkout service on [db].
Future<void> completeSale(AppDatabase db, {int price = 4000, int quantity = 1}) async {
  final repo = DriftProductRepository(db.productDao);
  final product = (await repo.search('pepsi')).first;
  final container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);
  container.read(cartProvider.notifier).addProduct(product, quantity: quantity);
  await container.read(checkoutControllerProvider.notifier).confirmCashPayment();
}

Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  AppDatabase? database,
  Future<AppDatabase> Function(AppDatabase db)? seed,
}) async {
  final db = database ?? openTestDb();
  if (seed != null) await seed(db);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  return db;
}

Future<void> openReports(WidgetTester tester) async {
  await tester.tap(find.text('Reports').first);
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('reports dashboard', () {
    testWidgets('shows summary, top-selling, low-stock and recent transactions',
        (tester) async {
      final db = await seedProduct(openTestDb());
      await completeSale(db, price: 4000, quantity: 2); // ₹80, 2 Pepsi
      // Low stock: set Pepsi stock to 0.
      final repo = DriftProductRepository(db.productDao);
      final pepsi = (await repo.search('pepsi')).first;
      await repo.updateStock(pepsi.id, 0);

      await pumpApp(tester, database: db);
      await openReports(tester);

      // Summary card.
      expect(find.text('Today'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('₹80.00'), findsWidgets);
      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Avg Bill'), findsOneWidget);

      // Top selling.
      expect(find.text('Top Selling'), findsOneWidget);
      expect(find.text('Pepsi'), findsWidgets);
      expect(find.text('2 sold'), findsOneWidget);

      // Low stock.
      expect(find.text('Low Stock'), findsOneWidget);
      expect(find.text('0 left'), findsOneWidget);

      // Recent transactions.
      expect(find.text('Recent Transactions'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('empty store shows all empty states', (tester) async {
      final db = await pumpApp(tester, seed: seedProduct);
      await openReports(tester);

      expect(find.text('No sales yet'), findsNothing); // summary may show 0
      expect(find.text('No product sales in this period.'), findsOneWidget);
      expect(find.text('Stock levels look good.'), findsOneWidget);
      expect(find.text('No recent transactions.'), findsOneWidget);
      // Total and avg-bill both show ₹0.00 for an empty store.
      expect(find.text('₹0.00'), findsWidgets);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('date selector switches the range', (tester) async {
      final db = await seedProduct(openTestDb());
      await completeSale(db, price: 4000, quantity: 1);
      await pumpApp(tester, database: db);
      await openReports(tester);

      // Default Today shows the sale.
      expect(find.text('₹40.00'), findsWidgets);

      // Switch to Yesterday.
      await tester.tap(find.text('Today').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await tester.tap(find.text('Yesterday').last);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('₹0.00'), findsWidgets); // no sales yesterday
      expect(find.text('No product sales in this period.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('recent transaction opens Sale Detail then receipt',
        (tester) async {
      final db = await seedProduct(openTestDb());
      await completeSale(db, price: 4000, quantity: 1);
      await pumpApp(tester, database: db);
      await openReports(tester);

      // Scroll the recent-transaction row into view, then tap it.
      final txnFinder = find.textContaining('VP-').first;
      await tester.ensureVisible(txnFinder);
      await tester.pumpAndSettle();
      await tester.tap(txnFinder);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Sale Detail'), findsOneWidget);
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('1 × ₹40.00'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Receipt'), findsWidgets);
      expect(find.text('Paid by Cash'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('reactive update', () {
    testWidgets('a new cash sale updates reports without restart', (tester) async {
      final db = await seedProduct(openTestDb());
      await pumpApp(tester, database: db);
      await openReports(tester);

      // Initially zero.
      expect(find.text('₹0.00'), findsWidgets);
      expect(find.text('No product sales in this period.'), findsOneWidget);

      // Complete a sale through the app UI (no restart).
      await tester.tap(find.text('Bill').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);
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

      // Back to Reports (NEW SALE first).
      await tester.tap(find.widgetWithText(FilledButton, 'NEW SALE'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      await openReports(tester);

      // Now the summary reflects the sale.
      expect(find.text('₹40.00'), findsWidgets);
      expect(find.text('1 sold'), findsOneWidget);
      expect(find.textContaining('VP-'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });
}
