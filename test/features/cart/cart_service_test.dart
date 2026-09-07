import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart' as db;
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/cart/domain/cart_service.dart';
import 'package:voice_pos/features/cart/domain/cart_state.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/products/domain/product.dart';

Product makeProduct({
  int id = 1,
  String name = 'Pepsi',
  int price = 4000,
  int stock = 10,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    sku: null,
    sellingPricePaise: price,
    costPricePaise: null,
    stockQty: stock,
    lowStockThreshold: 2,
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('empty cart', () {
    test('starts empty with zero totals', () {
      const cart = CartState();
      expect(cart.isEmpty, isTrue);
      expect(cart.itemCount, 0);
      expect(cart.subtotalPaise, 0);
      expect(cart.totalPaise, 0);
    });
  });

  group('addProduct', () {
    test('adds a product with quantity 1 by default', () {
      final cart = CartService.addProduct(const CartState(), makeProduct());

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 1);
      expect(cart.items.first.productName, 'Pepsi');
      expect(cart.items.first.unitPricePaise, 4000);
      expect(cart.itemCount, 1);
    });

    test('adding the same product increases quantity, no duplicate lines', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.addProduct(cart, makeProduct());
      cart = CartService.addProduct(cart, makeProduct(), quantity: 1);

      expect(cart.items.length, 1);
      expect(cart.items.first.quantity, 3);
    });

    test('multiple products create multiple lines', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.addProduct(
        cart,
        makeProduct(id: 2, name: 'Maggi', price: 3000),
      );

      expect(cart.items.length, 2);
      expect(cart.itemCount, 2);
    });

    test('rejects zero-stock product', () {
      expect(
        () => CartService.addProduct(
          const CartState(),
          makeProduct(stock: 0),
        ),
        throwsA(isA<OutOfStockFailure>()),
      );
    });

    test('rejects inactive product', () {
      expect(
        () => CartService.addProduct(
          const CartState(),
          makeProduct(active: false),
        ),
        throwsA(isA<ProductNotFoundFailure>()),
      );
    });

    test('rejects quantity above stock', () {
      expect(
        () => CartService.addProduct(
          const CartState(),
          makeProduct(stock: 2),
          quantity: 3,
        ),
        throwsA(isA<OutOfStockFailure>()),
      );
    });

    test('allows quantity exactly equal to stock', () {
      final cart = CartService.addProduct(
        const CartState(),
        makeProduct(stock: 2),
        quantity: 2,
      );
      expect(cart.items.first.quantity, 2);
    });

    test('rejects non-positive quantity', () {
      expect(
        () => CartService.addProduct(
          const CartState(),
          makeProduct(),
          quantity: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('quantity edits', () {
    test('increaseQuantity increments by 1', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.increaseQuantity(cart, 1);
      expect(cart.items.first.quantity, 2);
    });

    test('increaseQuantity stops at stock', () {
      var cart = CartService.addProduct(
        const CartState(),
        makeProduct(stock: 1),
      );
      expect(
        () => CartService.increaseQuantity(cart, 1),
        throwsA(isA<OutOfStockFailure>()),
      );
    });

    test('decreaseQuantity decrements by 1', () {
      var cart = CartService.addProduct(
        const CartState(),
        makeProduct(),
        quantity: 3,
      );
      cart = CartService.decreaseQuantity(cart, 1);
      expect(cart.items.first.quantity, 2);
    });

    test('decreaseQuantity at 1 removes the line', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.decreaseQuantity(cart, 1);
      expect(cart.isEmpty, isTrue);
    });

    test('setQuantity sets absolute quantity', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.setQuantity(cart, 1, 5);
      expect(cart.items.first.quantity, 5);
    });

    test('setQuantity to 0 removes the line', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.setQuantity(cart, 1, 0);
      expect(cart.isEmpty, isTrue);
    });

    test('setQuantity rejects negative', () {
      final cart = CartService.addProduct(const CartState(), makeProduct());
      expect(
        () => CartService.setQuantity(cart, 1, -1),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('setQuantity rejects above stock', () {
      final cart = CartService.addProduct(
        const CartState(),
        makeProduct(stock: 2),
      );
      expect(
        () => CartService.setQuantity(cart, 1, 3),
        throwsA(isA<OutOfStockFailure>()),
      );
    });

    test('edits on unknown product throw ProductNotFoundFailure', () {
      const cart = CartState();
      expect(
        () => CartService.increaseQuantity(cart, 9),
        throwsA(isA<ProductNotFoundFailure>()),
      );
      expect(
        () => CartService.decreaseQuantity(cart, 9),
        throwsA(isA<ProductNotFoundFailure>()),
      );
      expect(
        () => CartService.setQuantity(cart, 9, 2),
        throwsA(isA<ProductNotFoundFailure>()),
      );
      expect(
        () => CartService.removeProduct(cart, 9),
        throwsA(isA<ProductNotFoundFailure>()),
      );
    });
  });

  group('remove and clear', () {
    test('removeProduct drops the line', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.addProduct(
        cart,
        makeProduct(id: 2, name: 'Maggi', price: 3000),
      );
      cart = CartService.removeProduct(cart, 1);
      expect(cart.items.map((e) => e.productId), [2]);
    });

    test('clearCart empties everything', () {
      var cart = CartService.addProduct(const CartState(), makeProduct());
      cart = CartService.clearCart(cart);
      expect(cart.isEmpty, isTrue);
      expect(cart.totalPaise, 0);
    });
  });

  group('money (integer paise)', () {
    test('line total is unit × quantity', () {
      final cart = CartService.addProduct(
        const CartState(),
        makeProduct(price: 4000),
        quantity: 2,
      );
      expect(cart.items.first.lineTotalPaise, 8000);
    });

    test('total sums lines: Pepsi 40×2 + Maggi 30×1 = 11000', () {
      var cart = CartService.addProduct(
        const CartState(),
        makeProduct(name: 'Pepsi', price: 4000),
        quantity: 2,
      );
      cart = CartService.addProduct(
        cart,
        makeProduct(id: 2, name: 'Maggi', price: 3000),
      );
      expect(cart.subtotalPaise, 11000);
      expect(cart.totalPaise, 11000);
    });
  });

  group('snapshot behavior', () {
    test('price snapshot survives product mutation', () {
      var cart = CartService.addProduct(
        const CartState(),
        makeProduct(price: 4000),
      );
      // Product price changes afterwards — cart keeps the old price until
      // the cashier removes and re-adds.
      cart = CartService.increaseQuantity(cart, 1);
      expect(cart.items.first.unitPricePaise, 4000);

      cart = CartService.removeProduct(cart, 1);
      cart = CartService.addProduct(cart, makeProduct(price: 4500));
      expect(cart.items.first.unitPricePaise, 4500);
    });

    test('getItem and containsProduct', () {
      final cart = CartService.addProduct(const CartState(), makeProduct());
      expect(cart.containsProduct(1), isTrue);
      expect(cart.containsProduct(2), isFalse);
      expect(cart.getItem(1)!.productName, 'Pepsi');
      expect(cart.getItem(2), isNull);
    });
  });

  group('database untouched', () {
    test('cart operations never modify DB stock', () async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repo = DriftProductRepository(database.productDao);

      final product = await repo.create(
        name: 'Pepsi',
        sku: null,
        sellingPricePaise: 4000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );

      var cart = CartService.addProduct(const CartState(), product, quantity: 3);
      cart = CartService.increaseQuantity(cart, product.id);
      cart = CartService.decreaseQuantity(cart, product.id);
      cart = CartService.removeProduct(cart, product.id);
      cart = CartService.addProduct(cart, product);
      CartService.clearCart(cart);

      expect((await repo.getById(product.id))!.stockQty, 10);
    });
  });
}
