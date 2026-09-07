import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/reports/data/report_repository_impl.dart';

AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Seeds a completed sale with item snapshots at an exact local time.
/// Pass [productId] to reuse an existing product (multiple sales of one
/// item) instead of creating an active duplicate name each time.
Future<int> seedSale(
  AppDatabase db, {
  required String transactionNumber,
  required DateTime createdAt,
  required String productName,
  required int unitPricePaise,
  required int quantity,
  String? sku,
  int? productId,
}) async {
  final pid = productId ?? await db.productDao.create(
        ProductsCompanion.insert(
          name: productName,
          sku: Value(sku),
          sellingPricePaise: unitPricePaise,
        ),
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
      productId: pid,
      productName: productName,
      sku: Value(sku),
      unitPricePaise: unitPricePaise,
      quantity: quantity,
      lineTotalPaise: lineTotal,
    ),
  ]);
  return saleId;
}

void main() {
  group('report summary', () {
    test('aggregates total and count for a range', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-S1',
          createdAt: DateTime(2026, 9, 7, 9),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 2);
      await seedSale(db,
          transactionNumber: 'VP-S2',
          createdAt: DateTime(2026, 9, 7, 15),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 1);

      final start = DateTime(2026, 9, 7, 0, 0);
      final end = DateTime(2026, 9, 8, 0, 0);
      final summary = await repo.getSummary(start: start, end: end);
      expect(summary.totalSalesPaise, 11000); // 8000 + 3000
      expect(summary.transactionCount, 2);
    });

    test('empty period returns zero, no divide-by-zero', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      final summary = await repo.getSummary(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(summary.totalSalesPaise, 0);
      expect(summary.transactionCount, 0);
      expect(summary.averageBillPaise, 0);
    });

    test('today boundary: sale at 00:00 today included, 23:59 yesterday excluded',
        () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-MIDNIGHT',
          createdAt: DateTime(2026, 9, 7, 0, 0, 0),
          productName: 'A',
          unitPricePaise: 1000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-YESTERDAY-END',
          createdAt: DateTime(2026, 9, 6, 23, 59, 59),
          productName: 'B',
          unitPricePaise: 5000,
          quantity: 1);

      final today = await repo.getSummary(
        start: DateTime(2026, 9, 7, 0, 0),
        end: DateTime(2026, 9, 8, 0, 0),
      );
      expect(today.transactionCount, 1);
      expect(today.totalSalesPaise, 1000);

      final yesterday = await repo.getSummary(
        start: DateTime(2026, 9, 6, 0, 0),
        end: DateTime(2026, 9, 7, 0, 0),
      );
      expect(yesterday.transactionCount, 1);
      expect(yesterday.totalSalesPaise, 5000);
    });

    test('last 7 days boundary inclusion/exclusion', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-INSIDE-1',
          createdAt: DateTime(2026, 9, 1, 0, 0),
          productName: 'A',
          unitPricePaise: 1000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-INSIDE-2',
          createdAt: DateTime(2026, 9, 7, 23, 59, 59),
          productName: 'B',
          unitPricePaise: 2000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-OUTSIDE',
          createdAt: DateTime(2026, 8, 31, 23, 59, 59),
          productName: 'C',
          unitPricePaise: 9999,
          quantity: 1);

      // 7-day window: 2026-09-01 00:00 inclusive .. 2026-09-08 00:00 exclusive
      final summary = await repo.getSummary(
        start: DateTime(2026, 9, 1, 0, 0),
        end: DateTime(2026, 9, 8, 0, 0),
      );
      expect(summary.transactionCount, 2);
      expect(summary.totalSalesPaise, 3000);
    });
  });

  group('top selling', () {
    test('aggregates quantity per product and orders by sold desc', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      // Reuse the same product id for the two Pepsi lines (active-name
      // uniqueness would reject a second 'Pepsi' product).
      final pepsi = await db.productDao.create(
        ProductsCompanion.insert(name: 'Pepsi', sellingPricePaise: 4000),
      );
      final maggi = await db.productDao.create(
        ProductsCompanion.insert(name: 'Maggi', sellingPricePaise: 3000),
      );
      await seedSale(db,
          transactionNumber: 'VP-T1',
          createdAt: DateTime(2026, 9, 7, 9),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 5,
          productId: pepsi);
      await seedSale(db,
          transactionNumber: 'VP-T2',
          createdAt: DateTime(2026, 9, 7, 10),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 3,
          productId: maggi);
      await seedSale(db,
          transactionNumber: 'VP-T3',
          createdAt: DateTime(2026, 9, 7, 11),
          productName: 'Pepsi',
          unitPricePaise: 4000,
          quantity: 2,
          productId: pepsi);

      final top = await repo.getTopSelling(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(top.length, 2);
      expect(top.first.productName, 'Pepsi');
      expect(top.first.quantitySold, 7);
      expect(top.last.productName, 'Maggi');
      expect(top.last.quantitySold, 3);
    });

    test('ties ordered deterministically by product name asc', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-T1',
          createdAt: DateTime(2026, 9, 7, 9),
          productName: 'Maggi',
          unitPricePaise: 3000,
          quantity: 3);
      await seedSale(db,
          transactionNumber: 'VP-T2',
          createdAt: DateTime(2026, 9, 7, 10),
          productName: 'Coke',
          unitPricePaise: 2000,
          quantity: 3);

      final top = await repo.getTopSelling(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(top.map((p) => p.productName), ['Coke', 'Maggi']);
    });

    test('respects the limit', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      for (var i = 0; i < 7; i++) {
        await seedSale(db,
            transactionNumber: 'VP-$i',
            createdAt: DateTime(2026, 9, 7, 9 + i),
            productName: 'P$i',
            unitPricePaise: 1000,
            quantity: 1);
      }
      final top = await repo.getTopSelling(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
        limit: 3,
      );
      expect(top.length, 3);
    });

    test('empty period returns no top sellers', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      final top = await repo.getTopSelling(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(top, isEmpty);
    });
  });

  group('historical snapshot reporting', () {
    test('uses sale_items.product_name, not the live Products name', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);
      final productRepo = DriftProductRepository(db.productDao);

      final product = await productRepo.create(
        name: 'Pepsi',
        sku: 'PEP001',
        sellingPricePaise: 5000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );
      final saleId = await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-SNAP',
          paymentMethod: 'cash',
          subtotalPaise: 10000,
          totalPaise: 10000,
          createdAt: Value(DateTime(2026, 9, 7, 10)),
        ),
      );
      await db.saleDao.createSaleItems([
        SaleItemsCompanion.insert(
          saleId: saleId,
          productId: product.id,
          productName: 'Pepsi',
          sku: const Value('PEP001'),
          unitPricePaise: 5000,
          quantity: 2,
          lineTotalPaise: 10000,
        ),
      ]);

      // Rename + reprice the product after the sale.
      await productRepo.update(
        id: product.id,
        name: 'Pepsi Max',
        sku: 'PEP002',
        sellingPricePaise: 7000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );

      final top = await repo.getTopSelling(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(top.single.productName, 'Pepsi'); // historical snapshot
      expect(top.single.quantitySold, 2);

      final summary = await repo.getSummary(
        start: DateTime(2026, 9, 7),
        end: DateTime(2026, 9, 8),
      );
      expect(summary.totalSalesPaise, 10000); // ₹50 × 2, not ₹70
    });
  });

  group('recent sales', () {
    test('returns newest first bounded', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftReportRepository(db.saleDao);

      await seedSale(db,
          transactionNumber: 'VP-R1',
          createdAt: DateTime(2026, 9, 7, 9),
          productName: 'A',
          unitPricePaise: 1000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-R2',
          createdAt: DateTime(2026, 9, 7, 15),
          productName: 'B',
          unitPricePaise: 2000,
          quantity: 1);
      await seedSale(db,
          transactionNumber: 'VP-R3',
          createdAt: DateTime(2026, 9, 7, 18),
          productName: 'C',
          unitPricePaise: 3000,
          quantity: 1);

      final recent = await repo.recentSales(limit: 2);
      expect(recent.map((s) => s.transactionNumber), ['VP-R3', 'VP-R2']);
    });
  });
}
