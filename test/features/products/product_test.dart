import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/products/domain/product.dart';

Product makeProduct({
  int id = 1,
  String name = 'Pepsi 500ml',
  String? sku = 'PEP-500',
  int price = 2000,
  int? cost,
  int stock = 10,
  int threshold = 5,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    sku: sku,
    sellingPricePaise: price,
    costPricePaise: cost,
    stockQty: stock,
    lowStockThreshold: threshold,
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('validation', () {
    test('accepts a valid product', () {
      expect(
        () => Product.validateFields(
          name: 'Pepsi',
          sku: 'PEP-500',
          sellingPricePaise: 2000,
          costPricePaise: 1500,
          stockQty: 10,
          lowStockThreshold: 5,
        ),
        returnsNormally,
      );
    });

    test('rejects empty name', () {
      expect(
        () => Product.validateFields(
          name: '   ',
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects overlong name', () {
      expect(
        () => Product.validateFields(
          name: 'x' * 101,
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative selling price', () {
      expect(
        () => Product.validateFields(
          name: 'Pepsi',
          sku: null,
          sellingPricePaise: -1,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative cost price', () {
      expect(
        () => Product.validateFields(
          name: 'Pepsi',
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: -1,
          stockQty: 0,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative stock', () {
      expect(
        () => Product.validateFields(
          name: 'Pepsi',
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: null,
          stockQty: -1,
          lowStockThreshold: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative threshold', () {
      expect(
        () => Product.validateFields(
          name: 'Pepsi',
          sku: null,
          sellingPricePaise: 2000,
          costPricePaise: null,
          stockQty: 0,
          lowStockThreshold: -1,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('isLowStock', () {
    test('below threshold is low', () {
      expect(makeProduct(stock: 3, threshold: 5).isLowStock, isTrue);
    });

    test('equal to threshold is low', () {
      expect(makeProduct(stock: 5, threshold: 5).isLowStock, isTrue);
    });

    test('above threshold is not low', () {
      expect(makeProduct(stock: 6, threshold: 5).isLowStock, isFalse);
    });
  });

  group('copyWith', () {
    test('updates selected fields only', () {
      final updated = makeProduct().copyWith(stockQty: 3, name: 'Coke');
      expect(updated.stockQty, 3);
      expect(updated.name, 'Coke');
      expect(updated.sellingPricePaise, 2000);
      expect(updated.id, 1);
    });
  });

  group('tryParsePriceToPaise (no floating point)', () {
    test('whole rupees', () {
      expect(Product.tryParsePriceToPaise('112'), 11200);
    });

    test('rupees with paise', () {
      expect(Product.tryParsePriceToPaise('112.00'), 11200);
    });

    test('single paise digit', () {
      expect(Product.tryParsePriceToPaise('112.5'), 11250);
    });

    test('sub-rupee price', () {
      expect(Product.tryParsePriceToPaise('0.99'), 99);
    });

    test('strips symbol, commas and spaces', () {
      expect(Product.tryParsePriceToPaise('₹1,050.25'), 105025);
    });

    test('rejects three decimals', () {
      expect(Product.tryParsePriceToPaise('12.345'), isNull);
    });

    test('rejects negatives and non-numeric', () {
      expect(Product.tryParsePriceToPaise('-5'), isNull);
      expect(Product.tryParsePriceToPaise('abc'), isNull);
      expect(Product.tryParsePriceToPaise(''), isNull);
    });
  });
}
