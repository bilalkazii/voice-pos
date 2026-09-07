import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';

/// Phase 1 database tests. Every test gets a fresh in-memory database;
/// file-backed persistence is covered by [file-backed persistence] below.
AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

Future<int> insertProduct(
  AppDatabase db, {
  required String name,
  String? sku,
  int price = 2000,
  int stock = 10,
  int threshold = 5,
  bool active = true,
}) {
  return db.productDao.create(
    ProductsCompanion.insert(
      name: name,
      sku: Value(sku),
      sellingPricePaise: price,
      stockQty: Value(stock),
      lowStockThreshold: Value(threshold),
      isActive: Value(active),
    ),
  );
}

void main() {
  group('database opens', () {
    test('schema version is 1 and products table exists', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(db.schemaVersion, 1);
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'products'",
      ).get();
      expect(tables, hasLength(1));
    });

    test('custom uniqueness indexes exist', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'products_%'",
      ).get();
      final names = indexes.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('products_name_active_unique'));
      expect(names, contains('products_sku_active_unique'));
    });
  });

  group('product creation and retrieval', () {
    test('create then getById roundtrip', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi 500ml', sku: 'PEP-500');
      final row = await db.productDao.getById(id);

      expect(row, isNotNull);
      expect(row!.name, 'Pepsi 500ml');
      expect(row.sku, 'PEP-500');
      expect(row.sellingPricePaise, 2000);
      expect(row.stockQty, 10);
      expect(row.lowStockThreshold, 5);
      expect(row.isActive, isTrue);
    });

    test('getById returns null for unknown id', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(await db.productDao.getById(999), isNull);
    });

    test('nullable fields default correctly', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Maggi');
      final row = await db.productDao.getById(id);

      expect(row!.sku, isNull);
      expect(row.costPricePaise, isNull);
    });
  });

  group('update', () {
    test('update changes fields and advances updatedAt', () async {
      final db = openTestDb();
      addTearDown(db.close);

      // Seed with explicitly old timestamps so the updatedAt change is
      // deterministic regardless of SQLite's timestamp resolution.
      final old = DateTime(2020, 1, 1);
      final id = await db.productDao.create(
        ProductsCompanion.insert(
          name: 'Pepsi',
          sellingPricePaise: 2000,
          createdAt: Value(old),
          updatedAt: Value(old),
        ),
      );

      await db.productDao.updateProduct(
        id,
        const ProductsCompanion(
          name: Value('Pepsi 500ml'),
          sellingPricePaise: Value(2500),
        ),
      );

      final row = await db.productDao.getById(id);
      expect(row!.name, 'Pepsi 500ml');
      expect(row.sellingPricePaise, 2500);
      expect(row.updatedAt.isAfter(old), isTrue);
    });
  });

  group('deactivate', () {
    test('deactivated row remains but leaves active queries', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi');
      await db.productDao.deactivate(id);

      final row = await db.productDao.getById(id);
      expect(row, isNotNull);
      expect(row!.isActive, isFalse);

      expect(await db.productDao.getAllActive(), isEmpty);
      await expectLater(db.productDao.watchAllActive(), emits(isEmpty));
    });
  });

  group('constraints', () {
    test('duplicate name differing only by case is rejected', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi');
      expect(
        () => insertProduct(db, name: 'PEPSI'),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => insertProduct(db, name: 'PePsI'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('same name allowed after deactivation', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi');
      await db.productDao.deactivate(id);
      final id2 = await insertProduct(db, name: 'PEPSI');

      expect(id2, isNot(id));
      final active = await db.productDao.getAllActive();
      expect(active.map((p) => p.name), ['PEPSI']);
    });

    test('duplicate SKU among active products is rejected', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi', sku: 'PEP-500');
      expect(
        () => insertProduct(db, name: 'Coke', sku: 'PEP-500'),
        throwsA(isA<SqliteException>()),
      );
    });

    test('null SKUs never conflict', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi');
      await insertProduct(db, name: 'Coke');
      expect((await db.productDao.getAllActive()).length, 2);
    });

    test('same SKU allowed after deactivation', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi', sku: 'PEP-500');
      await db.productDao.deactivate(id);
      await insertProduct(db, name: 'Pepsi New', sku: 'PEP-500');

      expect((await db.productDao.getAllActive()).length, 1);
    });

    test('negative stock is rejected by CHECK', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(
        () => insertProduct(db, name: 'Pepsi', stock: -1),
        throwsA(isA<SqliteException>()),
      );
    });

    test('negative price is rejected by CHECK', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(
        () => insertProduct(db, name: 'Pepsi', price: -100),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('search', () {
    test('finds by name substring case-insensitively', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi 500ml');
      await insertProduct(db, name: 'Coca Cola');

      final results = await db.productDao.search('pepSI');
      expect(results.map((p) => p.name), ['Pepsi 500ml']);
    });

    test('finds by SKU', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi', sku: 'PEP-500');
      await insertProduct(db, name: 'Coke');

      final results = await db.productDao.search('pep-5');
      expect(results.map((p) => p.name), ['Pepsi']);
    });

    test('excludes inactive products', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi');
      await db.productDao.deactivate(id);

      expect(await db.productDao.search('pepsi'), isEmpty);
    });

    test('no-result search returns empty list', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi');
      expect(await db.productDao.search('zzz-no-match'), isEmpty);
    });
  });

  group('low stock', () {
    test('below threshold is low stock', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi', stock: 3, threshold: 5);
      expect(
        (await db.productDao.getLowStock()).map((p) => p.name),
        ['Pepsi'],
      );
    });

    test('equal to threshold is low stock', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi', stock: 5, threshold: 5);
      expect((await db.productDao.getLowStock()).length, 1);
    });

    test('above threshold is not low stock', () async {
      final db = openTestDb();
      addTearDown(db.close);

      await insertProduct(db, name: 'Pepsi', stock: 6, threshold: 5);
      expect(await db.productDao.getLowStock(), isEmpty);
    });

    test('inactive products excluded from low stock', () async {
      final db = openTestDb();
      addTearDown(db.close);

      final id = await insertProduct(db, name: 'Pepsi', stock: 0);
      await db.productDao.deactivate(id);
      expect(await db.productDao.getLowStock(), isEmpty);
    });
  });

  group('file-backed persistence', () {
    test('data survives close and reopen', () async {
      final dir = await Directory.systemTemp.createTemp('voice_pos_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = '${dir.path}/voice_pos.sqlite';

      final db1 = AppDatabase(NativeDatabase.createInBackground(File(file)));
      final id = await insertProduct(db1, name: 'Pepsi');
      await db1.close();

      final db2 = AppDatabase(NativeDatabase.createInBackground(File(file)));
      addTearDown(db2.close);
      final row = await db2.productDao.getById(id);

      expect(row, isNotNull);
      expect(row!.name, 'Pepsi');
    });
  });
}
