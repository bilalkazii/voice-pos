import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';
import 'package:voice_pos/features/settings/domain/app_settings.dart';

AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Builds a genuine v2 database file: products + sales + sale_items,
/// user_version 2, no app_settings. Drift must migrate it to v3 without
/// losing any row, and settings must start at stable defaults.
Future<String> buildV2DatabaseFile() async {
  final dir = await Directory.systemTemp.createTemp('voice_pos_v2_test');
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
  raw.execute('''
    CREATE TABLE sales (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      transaction_number TEXT NOT NULL UNIQUE,
      payment_method TEXT NOT NULL,
      subtotal_paise INTEGER NOT NULL,
      total_paise INTEGER NOT NULL,
      created_at INTEGER NOT NULL DEFAULT 1700000000,
      CHECK (total_paise >= 0)
    )
  ''');
  raw.execute('''
    CREATE TABLE sale_items (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL REFERENCES sales(id),
      product_id INTEGER NOT NULL REFERENCES products(id),
      product_name TEXT NOT NULL,
      sku TEXT NULL,
      unit_price_paise INTEGER NOT NULL,
      quantity INTEGER NOT NULL,
      line_total_paise INTEGER NOT NULL,
      CHECK (quantity >= 1)
    )
  ''');
  raw.execute(
    "INSERT INTO products (name, sku, selling_price_paise, stock_qty) "
    "VALUES ('Pepsi 500ml', 'PEP-500', 2000, 10)",
  );
  raw.execute(
    "INSERT INTO sales (transaction_number, payment_method, "
    "subtotal_paise, total_paise, created_at) "
    "VALUES ('VP-MIGRATION-1', 'cash', 4000, 4000, 1700000000)",
  );
  raw.execute(
    "INSERT INTO sale_items (sale_id, product_id, product_name, sku, "
    "unit_price_paise, quantity, line_total_paise) "
    "VALUES (1, 1, 'Pepsi 500ml', 'PEP-500', 2000, 2, 4000)",
  );
  raw.execute('PRAGMA user_version = 2');
  raw.close();
  return path;
}

void main() {
  group('v3 schema', () {
    test('schema version is 3 and app_settings table exists', () async {
      final db = openTestDb();
      addTearDown(db.close);

      expect(db.schemaVersion, 3);
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'app_settings'",
      ).get();
      expect(tables.map((r) => r.read<String>('name')), ['app_settings']);
    });

    test('store name round-trips', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      expect((await repo.load()).storeName, 'My Store');
      await repo.saveStoreName('  Bilal General Store  ');
      expect((await repo.load()).storeName, 'Bilal General Store');
    });

    test('voice feedback persists as boolean', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      expect((await repo.load()).voiceFeedbackEnabled, isTrue);
      await repo.setVoiceFeedbackEnabled(false);
      expect((await repo.load()).voiceFeedbackEnabled, isFalse);
      await repo.setVoiceFeedbackEnabled(true);
      expect((await repo.load()).voiceFeedbackEnabled, isTrue);
    });

    test('default threshold persists; invalid stored values fall back',
        () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      expect((await repo.load()).defaultLowStockThreshold, 5);
      await repo.setDefaultLowStockThreshold(10);
      expect((await repo.load()).defaultLowStockThreshold, 10);

      // Corrupt/negative stored values degrade to the default, never crash.
      await db.settingsDao.setValue(
        DriftSettingsRepository.keyDefaultThreshold,
        'not-a-number',
      );
      expect((await repo.load()).defaultLowStockThreshold, 5);
      await db.settingsDao.setValue(
        DriftSettingsRepository.keyDefaultThreshold,
        '-3',
      );
      expect((await repo.load()).defaultLowStockThreshold, 5);
    });

    test('printer selection persists; blank clears to unconfigured', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      var loaded = await repo.load();
      expect(loaded.selectedPrinterId, isNull);
      expect(loaded.hasPrinterConfigured, isFalse);

      await repo.setPrinterSelection(id: 'AA:BB', name: 'Thermal-58');
      loaded = await repo.load();
      expect(loaded.selectedPrinterId, 'AA:BB');
      expect(loaded.selectedPrinterName, 'Thermal-58');
      expect(loaded.hasPrinterConfigured, isTrue);

      await repo.setPrinterSelection(id: '  ', name: null);
      loaded = await repo.load();
      expect(loaded.selectedPrinterId, isNull);
      expect(loaded.hasPrinterConfigured, isFalse);
    });

    test('partial updates never disturb unrelated settings', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      await repo.saveStoreName('Shop A');
      await repo.setVoiceFeedbackEnabled(false);
      await repo.setDefaultLowStockThreshold(7);

      final loaded = await repo.load();
      expect(loaded.storeName, 'Shop A');
      expect(loaded.voiceFeedbackEnabled, isFalse);
      expect(loaded.defaultLowStockThreshold, 7);
    });

    test('watch emits on every persisted change', () async {
      final db = openTestDb();
      addTearDown(db.close);
      final repo = DriftSettingsRepository(db.settingsDao);

      final emissions = <AppSettings>[];
      final sub = repo.watch().listen(emissions.add);
      addTearDown(sub.cancel);

      await repo.saveStoreName('Shop B');
      await repo.setVoiceFeedbackEnabled(false);
      // Allow the stream microtasks to flush.
      await Future<void>.delayed(Duration.zero);

      expect(emissions, isNotEmpty);
      expect(emissions.last.storeName, 'Shop B');
      expect(emissions.last.voiceFeedbackEnabled, isFalse);
    });

    test('settings survive database close and reopen', () async {
      final dir = await Directory.systemTemp.createTemp('voice_pos_reopen');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/voice_pos.sqlite';

      final db1 = AppDatabase(NativeDatabase.createInBackground(File(path)));
      final repo1 = DriftSettingsRepository(db1.settingsDao);
      await repo1.saveStoreName('Persistent Shop');
      await repo1.setVoiceFeedbackEnabled(false);
      await repo1.setDefaultLowStockThreshold(9);
      await db1.close();

      final db2 = AppDatabase(NativeDatabase.createInBackground(File(path)));
      addTearDown(db2.close);
      final loaded = await DriftSettingsRepository(db2.settingsDao).load();
      expect(loaded.storeName, 'Persistent Shop');
      expect(loaded.voiceFeedbackEnabled, isFalse);
      expect(loaded.defaultLowStockThreshold, 9);
    });
  });

  group('v2 to v3 migration', () {
    test('products, sales, and items survive; settings start at defaults',
        () async {
      final path = await buildV2DatabaseFile();

      final db = AppDatabase(NativeDatabase.createInBackground(File(path)));
      addTearDown(db.close);

      final version =
          await db.customSelect('PRAGMA user_version').getSingle();
      expect(version.read<int>('user_version'), 3);

      final product = await db.productDao.getById(1);
      expect(product, isNotNull);
      expect(product!.name, 'Pepsi 500ml');
      expect(product.stockQty, 10);

      final sale = await db.saleDao.getSaleById(1);
      expect(sale, isNotNull);
      expect(sale!.transactionNumber, 'VP-MIGRATION-1');
      expect(sale.totalPaise, 4000);

      final items = await db.saleDao.getItemsForSale(1);
      expect(items.length, 1);
      expect(items.first.productName, 'Pepsi 500ml');
      expect(items.first.quantity, 2);

      final settings =
          await DriftSettingsRepository(db.settingsDao).load();
      expect(settings, AppSettings.defaults);

      // And settings are writable immediately after migration.
      final repo = DriftSettingsRepository(db.settingsDao);
      await repo.saveStoreName('Migrated Shop');
      expect((await repo.load()).storeName, 'Migrated Shop');
    });
  });
}
