import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart' hide Product;
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product.dart';
import 'package:voice_pos/features/products/presentation/product_form_screen.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';

import '../../test_utils.dart';

Future<AppDatabase> pumpApp(WidgetTester tester) async {
  final db = openTestDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  return db;
}

Future<void> seedPepsi(AppDatabase db) async {
  await DriftProductRepository(db.productDao).create(
    name: 'Pepsi',
    sku: 'PEP-500',
    sellingPricePaise: 4000,
    costPricePaise: null,
    stockQty: 10,
    lowStockThreshold: 2,
  );
}

Future<void> addViaPicker(WidgetTester tester, String name) async {
  await tester.tap(find.text('Add Product'));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

String thresholdFieldText(WidgetTester tester) {
  final fields = find.byType(TextFormField);
  expect(fields, findsNWidgets(6));
  return tester.widget<TextFormField>(fields.at(5)).controller!.text;
}

/// Host route beneath the product form: submitting the form pops back to
/// this instead of emptying the Navigator (which would crash the test).
class _FormHost extends StatefulWidget {
  const _FormHost({this.product});

  final Product? product;

  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(product: widget.product),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('host'));
  }
}

Future<void> pumpForm(
  WidgetTester tester,
  AppDatabase db, {
  Product? product,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: _FormHost(product: product)),
    ),
  );
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('receipt uses the configured store name', () {
    testWidgets('set name → sale → receipt shows it, then follows changes',
        (tester) async {
      final db = await pumpApp(tester);
      await seedPepsi(db);
      final settings = DriftSettingsRepository(db.settingsDao);
      await settings.saveStoreName('Bilal General Store');

      await addViaPicker(tester, 'Pepsi');
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

      await tester.tap(find.widgetWithText(OutlinedButton, 'VIEW RECEIPT'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      expect(find.text('Bilal General Store'), findsOneWidget);
      // Sale snapshots untouched by the settings layer.
      expect(find.text('Pepsi'), findsOneWidget);
      expect(find.text('1 × ₹40.00'), findsOneWidget);

      // Changing the setting updates subsequently rendered receipts live.
      await settings.saveStoreName('New Store Name');
      await tester.pump();
      await pumpStreams(tester);
      expect(find.text('New Store Name'), findsOneWidget);
      expect(find.text('Bilal General Store'), findsNothing);
      // Historical line items still intact.
      expect(find.text('Pepsi'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('default threshold applies to new products only', () {
    testWidgets('form uses configured default and creates with it',
        (tester) async {
      final db = openTestDb();
      final settings = DriftSettingsRepository(db.settingsDao);
      await settings.setDefaultLowStockThreshold(10);

      await pumpForm(tester, db);
      expect(thresholdFieldText(tester), '10');

      // Create through the real form submit path.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Pepsi');
      await tester.enterText(fields.at(2), '40.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await tester.pumpAndSettle();

      final repo = DriftProductRepository(db.productDao);
      final created = (await repo.search('pepsi')).single;
      expect(created.lowStockThreshold, 10);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('changing default leaves existing products untouched',
        (tester) async {
      final db = openTestDb();
      final settings = DriftSettingsRepository(db.settingsDao);
      final repo = DriftProductRepository(db.productDao);
      await settings.setDefaultLowStockThreshold(10);
      final created = await repo.create(
        name: 'Pepsi',
        sku: null,
        sellingPricePaise: 4000,
        costPricePaise: null,
        stockQty: 8,
        lowStockThreshold: 10,
      );

      await settings.setDefaultLowStockThreshold(3);
      expect(
        (await repo.getById(created.id))!.lowStockThreshold,
        10,
      );

      // …while a new form picks up the new default.
      await pumpForm(tester, db);
      expect(thresholdFieldText(tester), '3');

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('editing a product shows its own threshold, not the default',
        (tester) async {
      final db = openTestDb();
      final settings = DriftSettingsRepository(db.settingsDao);
      await settings.setDefaultLowStockThreshold(10);
      final repo = DriftProductRepository(db.productDao);
      final created = await repo.create(
        name: 'Pepsi',
        sku: null,
        sellingPricePaise: 4000,
        costPricePaise: null,
        stockQty: 8,
        lowStockThreshold: 2,
      );

      await pumpForm(tester, db, product: created);
      expect(thresholdFieldText(tester), '2');

      await disposeAndCloseDb(tester, db);
    });
  });
}
