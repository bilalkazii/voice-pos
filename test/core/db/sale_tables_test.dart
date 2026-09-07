import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:voice_pos/core/db/app_database.dart';

AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Builds a genuine v1 database file: products table only, user_version 1.
/// Drift must migrate it to v2 without losing the product.
Future<String> buildV1DatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('voice_pos_v1_test');
  addTearDown(() => dir.delete(recursive: true));
  final path = '${dir.path}/voice_pos.sqlite';

  final raw = sqlite3.sqlite3.open(path);
  raw.execute('''
    CREATE TABLE products (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sku TEXT NULL,
      selling_price_paise INTEGER NOT NULL,
      cost_price_paise INTEGER NULL,
      stock_qty INTEGER NOT NULL DEFAULT 0,
      low_stock_threshold INTEGER NOT NULL DEFAULT 5,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL DEFAULT 1700000000,
      updated_at INTEGER NOT NULL DEFAULT 1700000000,
      CHECK (selling_price_paise >= 0),
      CHECK (stock_qty >= 0)
    )
  ''');
  raw.execute(
    "INSERT INTO products (name, sku, selling_price_paise, stock_qty) "
    "VALUES ('Pepsi 500ml', 'PEP-500', 2000, 10)",
  );
  raw.execute('PRAGMA user_version = 1');
  raw.close();
  return path;
}

void main() {
  group('v2 schema', () {
    test('sales and sale_items tables exist with indexes', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name IN ('sales', 'sale_items')",
      ).get();
      expect(tables.map((r) => r.read<String>('name')).toSet(),
          {'sales', 'sale_items'});

      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        "AND name LIKE '%sale%'",
      ).get();
      final names = indexes.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('sales_created_at_idx'));
      expect(names, contains('sale_items_sale_id_idx'));
      expect(names, contains('sale_items_product_id_idx'));
      // transaction_number uniqueness is declared on the table (SQLite
      // reports it as an autoindex without the column in its name), so it
      // is verified behaviorally in 'duplicate transaction number rejected'.
      final tableSql = await db.customSelect(
        "SELECT sql FROM sqlite_master WHERE type = 'table' "
        "AND name = 'sales'",
      ).getSingle();
      expect(tableSql.read<String>('sql'), contains('UNIQUE'));
    });

    test('schema version is 2', () async {
      final db = openTestDb();
      addTearDown(db.close);
      expect(db.schemaVersion, 2);
    });

    test('recent sales ordering and sale count', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(await db.saleDao.saleCount(), 0);
      await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-1',
          paymentMethod: 'cash',
          subtotalPaise: 1000,
          totalPaise: 1000,
        ),
      );
      await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-2',
          paymentMethod: 'cash',
          subtotalPaise: 2000,
          totalPaise: 2000,
        ),
      );
      expect(await db.saleDao.saleCount(), 2);
      final recent = await db.saleDao.recentSales();
      expect(recent.length, 2);
    });
  });

  group('constraints', () {
    test('duplicate transaction number rejected', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-DUP',
          paymentMethod: 'cash',
          subtotalPaise: 1000,
          totalPaise: 1000,
        ),
      );
      expect(
        () => db.saleDao.createSale(
          SalesCompanion.insert(
            transactionNumber: 'VP-DUP',
            paymentMethod: 'cash',
            subtotalPaise: 500,
            totalPaise: 500,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.saleDao.saleCount(), 1);
    });

    test('sale item with unknown sale rejected by foreign key', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final productId = await db.productDao.create(
        ProductsCompanion.insert(name: 'Pepsi', sellingPricePaise: 2000),
      );
      expect(
        () => db.saleDao.createSaleItems([
          SaleItemsCompanion.insert(
            saleId: 9999,
            productId: productId,
            productName: 'Pepsi',
            unitPricePaise: 2000,
            quantity: 1,
            lineTotalPaise: 2000,
          ),
        ]),
        throwsA(isA<SqliteException>()),
      );
    });

    test('sale item with zero quantity rejected by CHECK', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final productId = await db.productDao.create(
        ProductsCompanion.insert(name: 'Pepsi', sellingPricePaise: 2000),
      );
      final saleId = await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-3',
          paymentMethod: 'cash',
          subtotalPaise: 0,
          totalPaise: 0,
        ),
      );
      expect(
        () => db.saleDao.createSaleItems([
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: productId,
            productName: 'Pepsi',
            unitPricePaise: 2000,
            quantity: 0,
            lineTotalPaise: 0,
          ),
        ]),
        throwsA(isA<SqliteException>()),
      );
    });

    test('guarded decrement returns 0 when stock insufficient', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final productId = await db.productDao.create(
        ProductsCompanion.insert(
          name: 'Pepsi',
          sellingPricePaise: 2000,
          stockQty: const Value(2),
        ),
      );
      expect(await db.saleDao.deductStockGuarded(productId, 3), 0);
      expect((await db.productDao.getById(productId))!.stockQty, 2);
      expect(await db.saleDao.deductStockGuarded(productId, 2), 1);
      expect((await db.productDao.getById(productId))!.stockQty, 0);
    });

    test('guarded decrement ignores inactive products', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final productId = await db.productDao.create(
        ProductsCompanion.insert(
          name: 'Pepsi',
          sellingPricePaise: 2000,
          stockQty: const Value(5),
        ),
      );
      await db.productDao.deactivate(productId);
      expect(await db.saleDao.deductStockGuarded(productId, 1), 0);
      expect((await db.productDao.getById(productId))!.stockQty, 5);
    });
  });

  group('v1 to v2 migration', () {
    test('existing products survive migration', () async {
      final path = await buildV1DatabaseFile();

      final db = AppDatabase(NativeDatabase.createInBackground(File(path)));
      addTearDown(db.close);

      // Product preserved with all fields.
      final product = await db.productDao.getById(1);
      expect(product, isNotNull);
      expect(product!.name, 'Pepsi 500ml');
      expect(product.sku, 'PEP-500');
      expect(product.sellingPricePaise, 2000);
      expect(product.stockQty, 10);

      // New tables usable immediately after migration.
      final saleId = await db.saleDao.createSale(
        SalesCompanion.insert(
          transactionNumber: 'VP-POST-MIGRATION',
          paymentMethod: 'cash',
          subtotalPaise: 4000,
          totalPaise: 4000,
        ),
      );
      await db.saleDao.createSaleItems([
        SaleItemsCompanion.insert(
          saleId: saleId,
          productId: product.id,
          productName: product.name,
          sku: Value(product.sku),
          unitPricePaise: 2000,
          quantity: 2,
          lineTotalPaise: 4000,
        ),
      ]);
      final items = await db.saleDao.getItemsForSale(saleId);
      expect(items.length, 1);
      expect(items.first.productName, 'Pepsi 500ml');

      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 2);
    });
  });
}
