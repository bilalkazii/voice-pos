import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/utils/money.dart';

void main() {
  group('Money.formatPaise', () {
    test('formats whole rupees with two decimals', () {
      expect(Money.formatPaise(11200), '₹112.00');
    });

    test('pads single-digit paise', () {
      expect(Money.formatPaise(105), '₹1.05');
    });

    test('formats zero', () {
      expect(Money.formatPaise(0), '₹0.00');
    });

    test('keeps sign for negative values', () {
      expect(Money.formatPaise(-500), '-₹5.00');
    });

    test('groups Indian digits (lakh)', () {
      expect(Money.formatPaise(1248000), '₹12,480.00');
    });
  });

  group('Money arithmetic (integer paise only)', () {
    test('adds paise', () {
      expect(Money.add(3000, 4200), 7200);
    });

    test('subtracts paise', () {
      expect(Money.subtract(5000, 2000), 3000);
    });

    test('multiplies unit price by quantity', () {
      expect(Money.multiply(2000, 2), 4000);
      expect(Money.multiply(1400, 3), 4200);
      expect(Money.multiply(2000, 0), 0);
    });

    test('multiply rejects negative quantity', () {
      expect(() => Money.multiply(2000, -1), throwsArgumentError);
    });

    test('sums line totals', () {
      expect(Money.sum([4000, 3000, 4200]), 11200);
      expect(Money.sum([]), 0);
    });

    test('cart-style total matches example bill', () {
      // Pepsi 2 x ₹20 + Lays 1 x ₹30 + Maggi 3 x ₹14 = ₹112.
      final total = Money.sum([
        Money.multiply(2000, 2),
        Money.multiply(3000, 1),
        Money.multiply(1400, 3),
      ]);
      expect(total, 11200);
      expect(Money.formatPaise(total), '₹112.00');
    });
  });
}
