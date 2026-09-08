import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/checkout/data/sale_repository_impl.dart';
import 'package:voice_pos/features/checkout/domain/payment_method.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';

AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Creates a product and a completed sale at a chosen time, with item
/// snapshots. Returns the sale id.
Future<int> seedSale(
  AppDatabase db, {
  required String transactionNumber,
  required DateTime createdAt,
  required String productName,
  required int unitPricePaise,
  required int quantity,
}) async {
  final productId = await db.productDao.create(
    ProductsCompanion.insert(name: productName, sellingPricePaise: unitPricePaise),
  );
  final lineTotal = unitPricePaise * quantity;
  final saleId = await db.saleDao.createSale(
    SalesCompanion.insert(
      transactionNumber: transactionNumber,
      paymentMethod: 'cash',
      subtotalPaise: lineTotal,
      totalPaise: lineTotal,
      createdAt: Value(createdAt),
    ),
  );
  await db.saleDao.createSaleItems([
    SaleItemsCompanion.insert(
      saleId: saleId,
      productId: productId,
      productName: productName,
      unitPricePaise: unitPricePaise,
      quantity: quantity,
      lineTotalPaise: lineTotal,
    ),
  ]);
  return saleId;
}

void main() {
  group('history queries (DAO + repository)', () {
    test('returns sales newest first with correct item counts', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-OLD',
          createdAt: DateTime(2020, 1, 1, 9),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 2);
      await seedSale(db,
          transactionNumber: 'VP-NEW',
          createdAt: DateTime(2026, 9, 7, 21),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 1);

      final sales = await repo.getSalesWithCount();
      expect(sales.map((s) => s.transactionNumber), ['VP-NEW', 'VP-OLD']);
      expect(sales.first.itemCount, 1);
      expect(sales.last.itemCount, 2);
    });

    test('newest-first ordering across sales on the same day', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-T1',
          createdAt: DateTime(2026, 9, 7, 9),
          productName: 'A',
          unitPricePaise: 100,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-T2',
          createdAt: DateTime(2026, 9, 7, 15),
          productName: 'B',
          unitPricePaise: 200,
          quantity: 1);

      final sales = await repo.getSalesWithCount();
      expect(sales.map((s) => s.transactionNumber), ['VP-T2', 'VP-T1']);
    });

    test('transaction-number search is case-insensitive and trimmed', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-ABC123',
          createdAt: DateTime(2026, 9, 7),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-XYZ',
          createdAt: DateTime(2026, 9, 7),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 1);

      final hit = await repo.getSalesWithCount(transactionSearch: '  vp-abc  ');
      expect(hit.map((s) => s.transactionNumber), ['VP-ABC123']);

      final empty = await repo.getSalesWithCount(transactionSearch: '   ');
      expect(empty.length, 2);

      final none = await repo.getSalesWithCount(transactionSearch: 'does-not-exist');
      expect(none, isEmpty);
    });

    test('date filter limits to sales on/after the boundary', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      final startOfToday = DateTime(2026, 9, 7, 0, 0);
      await seedSale(db,
          transactionNumber: 'VP-YESTERDAY',
          createdAt: DateTime(2026, 9, 6, 23, 59),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-TODAY-AM',
          createdAt: DateTime(2026, 9, 7, 8),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-TODAY-PM',
          createdAt: DateTime(2026, 9, 7, 20),
          productName: 'Coke',
          unitPricePaise: 2000,
          quantity: 1);

      final today = await repo.getSalesWithCount(after: startOfToday);
      expect(today.map((s) => s.transactionNumber),
          ['VP-TODAY-PM', 'VP-TODAY-AM']);

      // Today's summary from the list (count + total).
      final count = today.length;
      final total = today.fold(0, (sum, s) => sum + s.totalPaise);
      expect(count, 2);
      expect(total, 5000);
    });

    test('getSaleWithItems returns the committed sale with snapshots', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      final saleId = await seedSale(db,
          transactionNumber: 'VP-DETAIL',
          createdAt: DateTime(2026, 9, 7),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 3);

      final completed = await repo.getSaleWithItems(saleId);
      expect(completed, isNotNull);
      expect(completed!.sale.transactionNumber, 'VP-DETAIL');
      expect(completed.sale.paymentMethod, PaymentMethod.cash);
      expect(completed.items.length, 1);
      expect(completed.items.first.productName, 'Pepsi');
      expect(completed.items.first.unitPricePaise, 4000);
      expect(completed.items.first.quantity, 3);
      expect(completed.itemCount, 3);
    });

    test('history uses snapshots, not live product catalog', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);
      final productRepo = DriftProductRepository(db.productDao);

      final productId = (await productRepo.create(
        name: 'Pepsi',
        sku: 'PEP001',
        sellingPricePaise: 5000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      ))
          .id;
      final now = DateTime(2026, 9, 7);
      final saleId = await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-SNAP',
          paymentMethod: 'cash',
          subtotalPaise: 5000,
          totalPaise: 5000,
          createdAt: Value(now),
        ),
      );
      await db.saleDao.createSaleItems([
        SaleItemsCompanion.insert(
          saleId: saleId,
          productId: productId,
          productName: 'Pepsi',
          sku: const Value('PEP001'),
          unitPricePaise: 5000,
          quantity: 1,
          lineTotalPaise: 5000,
        ),
      ]);

      // Mutate the product after the sale.
      await productRepo.update(
        id: productId,
        name: 'Pepsi Max',
        sku: 'PEP002',
        sellingPricePaise: 7000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );

      final completed = await repo.getSaleWithItems(saleId);
      expect(completed!.items.first.productName, 'Pepsi');
      expect(completed.items.first.sku, 'PEP001');
      expect(completed.items.first.unitPricePaise, 5000);
      expect(completed.sale.totalPaise, 5000);
    });

    test('corrupt payment method maps to DatabaseFailure, not raw error',
        () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSaleRepository(db.saleDao);

      // Bypass the service to simulate externally corrupted data.
      final saleId = await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-CORRUPT',
          paymentMethod: 'bitcoin',
          subtotalPaise: 100,
          totalPaise: 100,
        ),
      );

      expect(
        () => repo.getSaleWithItems(saleId),
        throwsA(isA<DatabaseFailure>()),
      );
    });
  });
}
