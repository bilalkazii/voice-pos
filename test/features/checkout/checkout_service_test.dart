import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart'
    hide Product, Sale, SaleItem;
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/cart/domain/cart_service.dart';
import 'package:voice_pos/features/cart/domain/cart_state.dart';
import 'package:voice_pos/features/cart/presentation/cart_providers.dart';
import 'package:voice_pos/features/checkout/domain/checkout_service.dart';
import 'package:voice_pos/features/checkout/domain/payment_method.dart';
import 'package:voice_pos/features/checkout/presentation/checkout_providers.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product.dart';
import 'package:voice_pos/features/products/domain/product_repository.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';

/// Opens a memory database with a seeded catalog. Returns the db, the
/// repository, and the created domain products.
Future<({
  AppDatabase db,
  ProductRepository repo,
  Product pepsi,
  Product maggi,
})> openSeededDb({
  int pepsiStock = 10,
  int pepsiPrice = 4000,
  int maggiStock = 10,
  int maggiPrice = 3000,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final repo = DriftProductRepository(db.productDao);
  final pepsi = await repo.create(
    name: 'Pepsi',
    sku: 'PEP-500',
    sellingPricePaise: pepsiPrice,
    costPricePaise: null,
    stockQty: pepsiStock,
    lowStockThreshold: 2,
  );
  final maggi = await repo.create(
    name: 'Maggi',
    sku: null,
    sellingPricePaise: maggiPrice,
    costPricePaise: null,
    stockQty: maggiStock,
    lowStockThreshold: 2,
  );
  return (db: db, repo: repo, pepsi: pepsi, maggi: maggi);
}

CartState cartWith(CartState cart, Product product, {int quantity = 1}) {
  return CartService.addProduct(cart, product, quantity: quantity);
}

void main() {
  group('successful cash checkout', () {
    test('single-item sale creates sale + items and deducts stock', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);

      var cart = cartWith(const CartState(), seed.pepsi, quantity: 2);
      final completed = await service.completeCashSale(cart);

      expect(completed.sale.paymentMethod, PaymentMethod.cash);
      expect(completed.sale.transactionNumber, startsWith('VP-'));
      expect(completed.sale.subtotalPaise, 8000);
      expect(completed.sale.totalPaise, 8000);
      expect(completed.items.length, 1);
      expect(completed.items.first.productName, 'Pepsi');
      expect(completed.items.first.sku, 'PEP-500');
      expect(completed.items.first.unitPricePaise, 4000);
      expect(completed.items.first.quantity, 2);
      expect(completed.items.first.lineTotalPaise, 8000);
      expect(completed.itemCount, 2);

      // Inventory deducted exactly once.
      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 8);
    });

    test('multi-item sale has correct totals', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);

      var cart = cartWith(const CartState(), seed.pepsi, quantity: 2);
      cart = cartWith(cart, seed.maggi, quantity: 1);
      final completed = await service.completeCashSale(cart);

      // 4000*2 + 3000*1 = 11000 paise.
      expect(completed.sale.totalPaise, 11000);
      expect(completed.items.length, 2);
      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 8);
      expect((await seed.repo.getById(seed.maggi.id))!.stockQty, 9);
    });

    test('exact stock quantity succeeds and leaves zero', () async {
      final seed = await openSeededDb(pepsiStock: 3);
      final service = CheckoutService(seed.db);

      final cart = cartWith(const CartState(), seed.pepsi, quantity: 3);
      await service.completeCashSale(cart);

      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 0);
    });

    test('two sales get unique transaction numbers', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);

      final first = await service.completeCashSale(
        cartWith(const CartState(), seed.pepsi),
      );
      final second = await service.completeCashSale(
        cartWith(const CartState(), seed.maggi),
      );
      expect(first.sale.transactionNumber,
          isNot(second.sale.transactionNumber));
      expect(first.sale.id, isNot(second.sale.id));

      final byNumber = await seed.db.saleDao
          .getSaleByTransactionNumber(first.sale.transactionNumber);
      expect(byNumber, isNotNull);
      expect(byNumber!.id, first.sale.id);
    });

    test('transaction number format is stable', () {
      final number = CheckoutService.generateTransactionNumber(
        now: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        random: Random(42),
      );
      expect(number, startsWith('VP-1700000000000-'));
      expect(RegExp(r'^VP-\d+-\d{4}$').hasMatch(number), isTrue);
    });
  });

  group('rejections leave everything untouched', () {
    test('empty cart rejected with no sale', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);

      expect(
        () => service.completeCashSale(const CartState()),
        throwsA(isA<EmptyCartFailure>()),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
    });

    test('stale stock: cart qty exceeds current DB stock', () async {
      final seed = await openSeededDb(pepsiStock: 10);
      final service = CheckoutService(seed.db);
      final cart = cartWith(const CartState(), seed.pepsi, quantity: 2);

      // Another operation drains stock before checkout.
      await seed.repo.updateStock(seed.pepsi.id, 1);

      expect(
        () => service.completeCashSale(cart),
        throwsA(
          isA<OutOfStockFailure>().having(
            (f) => f.message,
            'message',
            contains('only has 1 left'),
          ),
        ),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 1);
    });

    test('zero stock fails without side effects', () async {
      final seed = await openSeededDb(pepsiStock: 5);
      final service = CheckoutService(seed.db);
      final cart = cartWith(const CartState(), seed.pepsi, quantity: 2);
      await seed.repo.updateStock(seed.pepsi.id, 0);

      expect(
        () => service.completeCashSale(cart),
        throwsA(isA<OutOfStockFailure>()),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
    });

    test('deactivated product fails cleanly', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);
      final cart = cartWith(const CartState(), seed.pepsi);
      await seed.repo.deactivate(seed.pepsi.id);

      expect(
        () => service.completeCashSale(cart),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 10);
    });

    test('missing product fails cleanly', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);
      // Cart line for a product id that does not exist.
      final ghost = seed.pepsi.copyWith(id: 99999);
      final cart = cartWith(const CartState(), ghost);

      expect(
        () => service.completeCashSale(cart),
        throwsA(isA<ProductNotFoundFailure>()),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
    });

    test('multi-item partial failure rolls back ALL changes', () async {
      final seed = await openSeededDb(pepsiStock: 10, maggiStock: 10);
      final service = CheckoutService(seed.db);
      var cart = cartWith(const CartState(), seed.pepsi, quantity: 2);
      cart = cartWith(cart, seed.maggi, quantity: 3);
      // Maggi drains after the cart snapshot was taken.
      await seed.repo.updateStock(seed.maggi.id, 1);

      expect(
        () => service.completeCashSale(cart),
        throwsA(isA<OutOfStockFailure>()),
      );
      // No sale, and Pepsi's deduction was rolled back too.
      expect(await seed.db.saleDao.saleCount(), 0);
      expect((await seed.repo.getById(seed.pepsi.id))!.stockQty, 10);
      expect((await seed.repo.getById(seed.maggi.id))!.stockQty, 1);
    });

    test('invalid cart quantity rejected', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);
      // Hand-built invalid line (CartService itself never produces these).
      final bad = seed.pepsi;
      final cart = CartState(items: [
        CartService.addProduct(const CartState(), bad).items.first
            .copyWith(quantity: 0),
      ]);

      expect(
        () => service.completeCashSale(cart),
        throwsA(isA<ValidationFailure>()),
      );
      expect(await seed.db.saleDao.saleCount(), 0);
    });
  });

  group('snapshots preserve history', () {
    test('price/name/SKU snapshots survive later product edits', () async {
      final seed = await openSeededDb();
      final service = CheckoutService(seed.db);
      final cart = cartWith(const CartState(), seed.pepsi, quantity: 2);

      // Product changes AFTER the customer saw the bill.
      await seed.repo.update(
        id: seed.pepsi.id,
        name: 'Pepsi New',
        sku: 'PEP-NEW',
        sellingPricePaise: 4500,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );

      final completed = await service.completeCashSale(cart);
      // Sale records what the bill showed, not the live product.
      expect(completed.sale.totalPaise, 8000);
      expect(completed.items.first.productName, 'Pepsi');
      expect(completed.items.first.sku, 'PEP-500');
      expect(completed.items.first.unitPricePaise, 4000);
      expect(completed.items.first.lineTotalPaise, 8000);
    });
  });

  group('checkout controller', () {
    Future<ProviderContainer> openControllerContainer({
      int pepsiStock = 10,
    }) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final repo = DriftProductRepository(db.productDao);
      final pepsi = await repo.create(
        name: 'Pepsi',
        sku: 'PEP-500',
        sellingPricePaise: 4000,
        costPricePaise: null,
        stockQty: pepsiStock,
        lowStockThreshold: 2,
      );
      container.read(cartProvider.notifier).addProduct(pepsi, quantity: 2);
      return container;
    }

    test('success clears cart exactly once', () async {
      final container = await openControllerContainer();
      final controller =
          container.read(checkoutControllerProvider.notifier);

      await controller.confirmCashPayment();

      final state = container.read(checkoutControllerProvider);
      expect(state.status, CheckoutStatus.success);
      expect(state.completedSale, isNotNull);
      expect(state.completedSale!.sale.totalPaise, 8000);
      expect(container.read(cartProvider).isEmpty, isTrue);
      expect(
        await container
            .read(saleRepositoryProvider)
            .saleCount(),
        1,
      );
    });

    test('second confirm after success cannot duplicate the sale', () async {
      final container = await openControllerContainer();
      final controller =
          container.read(checkoutControllerProvider.notifier);

      await controller.confirmCashPayment();
      await controller.confirmCashPayment();

      expect(
        await container.read(saleRepositoryProvider).saleCount(),
        1,
      );
      expect(
        container.read(checkoutControllerProvider).status,
        CheckoutStatus.success,
      );
    });

    test('failure keeps cart intact and allows retry', () async {
      final container = await openControllerContainer(pepsiStock: 2);
      // Drain stock below the cart quantity before confirming.
      final db = container.read(databaseProvider);
      final repo = DriftProductRepository(db.productDao);
      final pepsi = (await repo.search('pepsi')).first;
      await repo.updateStock(pepsi.id, 0);

      final controller =
          container.read(checkoutControllerProvider.notifier);
      await controller.confirmCashPayment();

      final failed = container.read(checkoutControllerProvider);
      expect(failed.status, CheckoutStatus.failure);
      expect(failed.message, isNotEmpty);
      expect(container.read(cartProvider).isNotEmpty, isTrue);
      expect(
        await container.read(saleRepositoryProvider).saleCount(),
        0,
      );

      // Restock and retry succeeds.
      await repo.updateStock(pepsi.id, 5);
      await controller.confirmCashPayment();
      expect(
        container.read(checkoutControllerProvider).status,
        CheckoutStatus.success,
      );
      expect(container.read(cartProvider).isEmpty, isTrue);
    });

    test('confirm on empty cart fails without touching the database',
        () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container
          .read(checkoutControllerProvider.notifier)
          .confirmCashPayment();

      expect(
        container.read(checkoutControllerProvider).status,
        CheckoutStatus.failure,
      );
      expect(
        await container.read(saleRepositoryProvider).saleCount(),
        0,
      );
    });
  });
}
