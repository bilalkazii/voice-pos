import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product_repository.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/products/presentation/products_screen.dart';

import '../../test_utils.dart';

/// Widget tests pump [ProductsScreen] with an in-memory database override.
/// Production wiring is untouched — overrides are inherited by the inner
/// ProviderScope in VoicePosApp.
Future<AppDatabase> pumpProductsScreen(
  WidgetTester tester, {
  Future<void> Function(ProductRepository repo)? seed,
}) async {
  final db = openTestDb();
  final repo = DriftProductRepository(db.productDao);
  if (seed != null) await seed(repo);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const MaterialApp(home: ProductsScreen()),
    ),
  );
  await pumpStreams(tester);
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
    lowStockThreshold: 5,
  );
}

void main() {
  group('product list', () {
    testWidgets('renders seeded products with price and stock', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi 500ml', sku: 'PEP-500'),
      );

      expect(find.text('Pepsi 500ml'), findsOneWidget);
      expect(find.textContaining('PEP-500'), findsOneWidget);
      expect(find.text('₹20.00'), findsOneWidget);
      expect(find.textContaining('Stock 10'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('shows empty state when no products', (tester) async {
      final db = await pumpProductsScreen(tester);

      expect(find.text('No products yet.'), findsOneWidget);
      expect(find.text('Add product'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('shows low-stock indicator and banner', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi', stock: 2),
      );

      expect(find.text('Low: 2 left'), findsOneWidget);
      expect(find.text('1 product is low on stock.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('search', () {
    testWidgets('filters the list', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) async {
          await createViaRepo(repo, name: 'Pepsi 500ml');
          await createViaRepo(repo, name: 'Coca Cola', sku: null);
        },
      );

      await tester.enterText(find.byType(TextField), 'coca');
      // Debounce is 300ms — advance past it, then flush the new query.
      await tester.pump(const Duration(milliseconds: 400));
      await pumpStreams(tester);

      expect(find.text('Coca Cola'), findsOneWidget);
      expect(find.text('Pepsi 500ml'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('no matches shows searching empty state', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi'),
      );

      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.pump(const Duration(milliseconds: 400));
      await pumpStreams(tester);

      expect(find.text('No matching products.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('add product flow', () {
    testWidgets('fills the form and the product appears', (tester) async {
      final db = await pumpProductsScreen(tester);

      await tester.tap(find.text('Add product'));
      await tester.pumpAndSettle();
      expect(find.text('Add Product'), findsWidgets);

      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(6));
      await tester.enterText(fields.at(0), 'Maggi 70g');
      await tester.enterText(fields.at(1), 'MAG-70');
      await tester.enterText(fields.at(2), '14.00');
      await tester.enterText(fields.at(4), '67');
      await tester.enterText(fields.at(5), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Maggi 70g'), findsOneWidget);
      expect(find.text('₹14.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('blank name shows a validation error', (tester) async {
      final db = await pumpProductsScreen(tester);

      await tester.tap(find.byTooltip('Add product'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await tester.pump();

      expect(find.text('Name is required.'), findsOneWidget);
      expect(find.text('No products yet.'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('invalid price shows a validation error', (tester) async {
      final db = await pumpProductsScreen(tester);

      await tester.tap(find.byTooltip('Add product'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Pepsi');
      await tester.enterText(fields.at(2), '12.345');
      await tester.tap(find.widgetWithText(FilledButton, 'Add Product'));
      await tester.pump();

      expect(
        find.text('Enter a valid price, e.g. 112.00.'),
        findsOneWidget,
      );

      await disposeAndCloseDb(tester, db);
    });
  });

  group('edit product flow', () {
    testWidgets('edits name and price', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi'),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Pepsi 750ml');
      await tester.enterText(fields.at(2), '30.00');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Pepsi 750ml'), findsOneWidget);
      expect(find.text('₹30.00'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });

  group('deactivate flow', () {
    testWidgets('confirms then removes the product', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi'),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();

      expect(find.text('Deactivate product?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Pepsi'), findsNothing);
      expect(find.text('Product deactivated.'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('cancel keeps the product', (tester) async {
      final db = await pumpProductsScreen(
        tester,
        seed: (repo) => createViaRepo(repo, name: 'Pepsi'),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Pepsi'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });
}
