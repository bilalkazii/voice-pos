import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart' as db;
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product.dart';
import 'package:voice_pos/features/products/domain/product_repository.dart';

ProductRepository openTestRepo() {
  final database = db.AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  return DriftProductRepository(database.productDao);
}

Future<Product> seedPepsi(
  ProductRepository repo, {
  String name = 'Pepsi 500ml',
  String? sku = 'PEP-500',
  int price = 2000,
  int stock = 10,
  int threshold = 5,
}) {
  return repo.create(
    name: name,
    sku: sku,
    sellingPricePaise: price,
    costPricePaise: null,
    stockQty: stock,
    lowStockThreshold: threshold,
  );
}

void main() {
  group('create', () {
    test('creates a valid product with an id', () async {
      final repo = openTestRepo();
      final product = await seedPepsi(repo);

      expect(product.id, isNot(0));
      expect(product.name, 'Pepsi 500ml');
      expect(product.sku, 'PEP-500');
      expect(product.sellingPricePaise, 2000);
      expect(product.isActive, isTrue);
    });

    test('rejects empty name', () async {
      final repo = openTestRepo();
      expect(
        () => seedPepsi(repo, name: '  '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative price/cost/stock/threshold', () async {
      final repo = openTestRepo();
      expect(() => seedPepsi(repo, price: -1),
          throwsA(isA<ValidationFailure>()));
      expect(
        () => repo.create(
          name: 'Pepsi',
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: -5,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
      expect(() => seedPepsi(repo, stock: -1),
          throwsA(isA<ValidationFailure>()));
      expect(() => seedPepsi(repo, threshold: -1),
          throwsA(isA<ValidationFailure>()));
    });

    test('rejects duplicate name case-insensitively', () async {
      final repo = openTestRepo();
      await seedPepsi(repo, name: 'Pepsi');
      expect(
        () => seedPepsi(repo, name: 'pEpSi', sku: 'OTHER-1'),
        throwsA(
          isA<ValidationFailure>().having(
            (f) => f.message,
            'message',
            contains('already exists'),
          ),
        ),
      );
    });

    test('trims whitespace so padded duplicates are rejected', () async {
      final repo = openTestRepo();
      await seedPepsi(repo, name: 'Pepsi');
      expect(
        () => seedPepsi(repo, name: '  pepsi  '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects duplicate SKU', () async {
      final repo = openTestRepo();
      await seedPepsi(repo, sku: 'PEP-500');
      expect(
        () => seedPepsi(repo, name: 'Coke', sku: 'PEP-500'),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('read', () {
    test('getById returns the product', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo);
      final found = await repo.getById(created.id);

      expect(found, isNotNull);
      expect(found!.name, 'Pepsi 500ml');
    });

    test('getById returns null for unknown id', () async {
      final repo = openTestRepo();
      expect(await repo.getById(12345), isNull);
    });
  });

  group('search', () {
    test('finds by name case-insensitively', () async {
      final repo = openTestRepo();
      await seedPepsi(repo, name: 'Pepsi 500ml');
      await seedPepsi(repo, name: 'Coca Cola', sku: null);

      final results = await repo.search('PEPSI');
      expect(results.map((p) => p.name), ['Pepsi 500ml']);
    });

    test('finds by SKU', () async {
      final repo = openTestRepo();
      await seedPepsi(repo);
      await seedPepsi(repo, name: 'Coke', sku: 'COK-500');

      final results = await repo.search('pep-5');
      expect(results.map((p) => p.name), ['Pepsi 500ml']);
    });

    test('empty query returns empty list', () async {
      final repo = openTestRepo();
      await seedPepsi(repo);
      expect(await repo.search('   '), isEmpty);
    });

    test('no-result search returns empty list', () async {
      final repo = openTestRepo();
      await seedPepsi(repo);
      expect(await repo.search('zzz-no-match'), isEmpty);
    });

    test('inactive products excluded', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo);
      await repo.deactivate(created.id);
      expect(await repo.search('pepsi'), isEmpty);
    });
  });

  group('update', () {
    test('updates fields and advances updatedAt', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo);

      final updated = await repo.update(
        id: created.id,
        name: 'Pepsi 750ml',
        sku: 'PEP-750',
        sellingPricePaise: 3000,
        costPricePaise: 2200,
        stockQty: 20,
        lowStockThreshold: 4,
      );

      expect(updated.name, 'Pepsi 750ml');
      expect(updated.sellingPricePaise, 3000);
      expect(updated.stockQty, 20);
      expect(
        updated.updatedAt.isAfter(created.updatedAt) ||
            updated.updatedAt.isAtSameMomentAs(created.updatedAt),
        isTrue,
      );
    });

    test('rejects unknown id', () async {
      final repo = openTestRepo();
      expect(
        () => repo.update(
          id: 999,
          name: 'Ghost',
          sku: null,
          sellingPricePaise: 100,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ProductNotFoundFailure>()),
      );
    });

    test('rejects invalid values', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo);
      expect(
        () => repo.update(
          id: created.id,
          name: '',
          sku: null,
          sellingPricePaise: 100,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('deactivate', () {
    test('hides from watchAll but keeps the row', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo);
      await repo.deactivate(created.id);

      await expectLater(repo.watchAll(), emits(isEmpty));
      final stillThere = await repo.getById(created.id);
      expect(stillThere, isNotNull);
      expect(stillThere!.isActive, isFalse);
    });

    test('rejects unknown id', () async {
      final repo = openTestRepo();
      expect(
        () => repo.deactivate(999),
        throwsA(isA<ProductNotFoundFailure>()),
      );
    });
  });

  group('updateStock', () {
    test('sets absolute stock', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo, stock: 10);
      final updated = await repo.updateStock(created.id, 25);
      expect(updated.stockQty, 25);
    });

    test('rejects negative stock without touching the row', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo, stock: 10);
      expect(
        () => repo.updateStock(created.id, -1),
        throwsA(isA<ValidationFailure>()),
      );
      expect((await repo.getById(created.id))!.stockQty, 10);
    });
  });

  group('watchLowStock', () {
    test('below and equal threshold included, above excluded', () async {
      final repo = openTestRepo();
      await seedPepsi(repo, name: 'Low', stock: 3, threshold: 5);
      await seedPepsi(repo, name: 'Equal', sku: null, stock: 5, threshold: 5);
      await seedPepsi(repo, name: 'Fine', sku: null, stock: 6, threshold: 5);

      final low = await repo.watchLowStock().first;
      expect(low.map((p) => p.name).toSet(), {'Low', 'Equal'});
    });

    test('inactive products excluded', () async {
      final repo = openTestRepo();
      final created = await seedPepsi(repo, stock: 0);
      await repo.deactivate(created.id);

      expect(await repo.watchLowStock().first, isEmpty);
    });
  });
}
