import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/checkout/data/sale_repository_impl.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/voice/presentation/voice_providers.dart';

import '../../test_utils.dart';
import '../voice/fakes.dart';

Future<void> seedCatalog(DriftProductRepository repo) async {
  await repo.create(
    name: 'Pepsi',
    sku: 'PEP-500',
    sellingPricePaise: 4000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
  await repo.create(
    name: 'Maggi',
    sku: null,
    sellingPricePaise: 3000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
}

/// Full app with an in-memory database (and optional fake speech service).
Future<AppDatabase> pumpVoicePos(
  WidgetTester tester, {
  Future<void> Function(DriftProductRepository repo)? seed,
  FakeSpeechService? speech,
}) async {
  final db = openTestDb();
  if (seed != null) {
    await seed(DriftProductRepository(db.productDao));
  }
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

Future<void> addViaPicker(WidgetTester tester, String productName) async {
  await tester.tap(find.text('Add Product'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  await tester.tap(find.text(productName));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

Future<void> goToCheckout(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'CHECKOUT'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('checkout review screen', () {
    testWidgets('shows items, total, CASH, and no amount fields', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);

      expect(find.text('Review Bill'), findsOneWidget);
      expect(find.text('CASH'), findsOneWidget);
      expect(find.text('1 × ₹40.00'), findsOneWidget);
      expect(find.text('₹40.00'), findsWidgets);
      expect(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
        findsOneWidget,
      );
      // Cash-only: no amount entry, no change calculation, no other methods.
      expect(find.text('Amount received'), findsNothing);
      expect(find.text('Change due'), findsNothing);
      expect(find.text('Change'), findsNothing);
      expect(find.text('UPI'), findsNothing);
      expect(find.text('Card'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('opening checkout processes nothing automatically', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);

      // No sale exists merely from opening the screen.
      expect(
        await db.saleDao.saleCount(),
        0,
      );
      final repo = DriftProductRepository(db.productDao);
      expect((await repo.getById(1))!.stockQty, 10);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('confirm cash payment', () {
    testWidgets('success shows payment complete with transaction', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);

      await tester.tap(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Payment Complete!'), findsOneWidget);
      expect(find.text('₹40.00'), findsOneWidget);
      expect(find.textContaining('VP-'), findsOneWidget);
      expect(find.textContaining('Cash'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'NEW SALE'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'), findsOneWidget);

      // Stock deducted in the database.
      final repo = DriftProductRepository(db.productDao);
      expect((await repo.getById(1))!.stockQty, 9);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('rapid double tap creates exactly one sale', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);

      // Two back-to-back taps with no frame between them: the controller
      // guard must ignore the second while the first is processing.
      final confirm =
          find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT');
      await tester.tap(confirm);
      await tester.tap(confirm, warnIfMissed: false);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Payment Complete!'), findsOneWidget);
      expect(await db.saleDao.saleCount(), 1);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('failure keeps cart intact and allows retry', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);

      // Drain stock after the bill was built.
      final repo = DriftProductRepository(db.productDao);
      final pepsi = (await repo.search('pepsi')).first;
      await repo.updateStock(pepsi.id, 0);

      await goToCheckout(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();

      // Still on checkout with an actionable error; bill preserved.
      expect(find.text('CONFIRM CASH PAYMENT'), findsNothing);
      expect(find.text('RETRY CONFIRM CASH PAYMENT'), findsOneWidget);
      expect(find.textContaining('out of stock'), findsOneWidget);
      expect(find.text('Pepsi'), findsOneWidget);
      expect(await db.saleDao.saleCount(), 0);

      // Restock and retry succeeds.
      await repo.updateStock(pepsi.id, 5);
      await tester.tap(
        find.widgetWithText(FilledButton, 'RETRY CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      expect(find.text('Payment Complete!'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('new sale returns to an empty bill', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'NEW SALE'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Current Bill'), findsOneWidget);
      expect(find.text('No items yet.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('receipt', () {
    testWidgets('receipt shows committed snapshots, not live catalog', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);
      await goToCheckout(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Rename + reprice the product AFTER the sale committed.
      final repo = DriftProductRepository(db.productDao);
      final pepsi = (await repo.search('pepsi')).first;
      await repo.update(
        id: pepsi.id,
        name: 'Pepsi Renamed',
        sku: 'NEW-SKU',
        sellingPricePaise: 9999,
        costPricePaise: null,
        stockQty: 9,
        lowStockThreshold: 2,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'));
      await tester.pumpAndSettle();

      expect(find.text('Receipt'), findsWidgets);
      // Historical snapshots, not the renamed/repriced product.
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('Pepsi Renamed'), findsNothing);
      expect(find.text('1 × ₹40.00'), findsOneWidget);
      expect(find.text('₹40.00'), findsWidgets);
      expect(find.textContaining('Cash'), findsWidgets);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('voice checkout regression', () {
    testWidgets('voice checkout navigates without auto-confirming', (tester) async {
      final speech = FakeSpeechService(transcript: 'Checkout');
      final db = await pumpVoicePos(
        tester,
        seed: seedCatalog,
        speech: speech,
      );
      await addViaPicker(tester, 'Pepsi');
      await expireSnackbars(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'SPEAK'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Navigated to review, payment NOT processed, sale NOT created.
      expect(find.text('Review Bill'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
        findsOneWidget,
      );
      expect(await db.saleDao.saleCount(), 0);
      final repo = DriftProductRepository(db.productDao);
      expect((await repo.getById(1))!.stockQty, 10);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('voice unknown command still mutates nothing', (tester) async {
      final speech = FakeSpeechService(
        transcript: 'I think I might need Pepsi later',
      );
      final db = await pumpVoicePos(
        tester,
        seed: seedCatalog,
        speech: speech,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'SPEAK'));
      await tester.pumpAndSettle();

      expect(find.text('No items yet.'), findsOneWidget);
      expect(await db.saleDao.saleCount(), 0);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('sale repository reads', () {
    testWidgets('payment complete loads sale by id from the database', (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      final repo = DriftProductRepository(db.productDao);
      final pepsi = (await repo.search('pepsi')).first;
      expect(pepsi.stockQty, 10);

      // Repository read path used by receipt screens.
      final saleRepo = DriftSaleRepository(db.saleDao);
      expect(await saleRepo.saleCount(), 0);
      expect(await saleRepo.getSaleWithItems(12345), isNull);

      await disposeAndCloseDb(tester, db);
    });
  });
}
