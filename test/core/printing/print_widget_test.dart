import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';

import '../../test_utils.dart';

Future<void> seedCatalog(DriftProductRepository repo) async {
  await repo.create(
    name: 'Pepsi 500ml',
    sku: 'PEP-500',
    sellingPricePaise: 4000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
}

/// Full app with an in-memory database.
Future<AppDatabase> pumpVoicePos(
  WidgetTester tester, {
  Future<void> Function(DriftProductRepository repo)? seed,
}) async {
  final db = openTestDb();
  if (seed != null) {
    await seed(DriftProductRepository(db.productDao));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
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

Future<void> sellOnePepsi(WidgetTester tester) async {
  await addViaPicker(tester, 'Pepsi 500ml');
  await expireSnackbars(tester);
  await tester.tap(find.widgetWithText(FilledButton, 'CHECKOUT'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  await tester.tap(
    find.widgetWithText(FilledButton, 'CONFIRM CASH PAYMENT'),
  );
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('receipt print affordance', () {
    testWidgets('print reports unavailable and leaves the sale intact',
        (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await sellOnePepsi(tester);

      expect(find.text('Receipt'), findsWidgets);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'PRINT RECEIPT'),
      );
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Honest unavailable state — never a fake success.
      expect(find.text('Printer not configured'), findsOneWidget);
      expect(find.text('Printed'), findsNothing);

      // The committed sale and its single inventory deduction are intact.
      expect(await db.saleDao.saleCount(), 1);
      final pepsi =
          (await DriftProductRepository(db.productDao).search('pepsi'))
              .first;
      expect(pepsi.stockQty, 9);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('print can be retried without duplicating anything',
        (tester) async {
      final db = await pumpVoicePos(tester, seed: seedCatalog);
      await sellOnePepsi(tester);

      for (var i = 0; i < 2; i++) {
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'PRINT RECEIPT'),
        );
        await tester.pumpAndSettle();
        await pumpStreams(tester);
      }

      // Both attempts reported unavailable; still exactly one sale.
      expect(find.text('Printer not configured'), findsOneWidget);
      expect(await db.saleDao.saleCount(), 1);

      await disposeAndCloseDb(tester, db);
    });
  });
}
