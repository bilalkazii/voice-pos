import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/features/voice/domain/product_matcher.dart';

import 'fakes.dart';

void main() {
  const matcher = ProductMatcher();

  group('exact matching', () {
    test('exact unique name match', () {
      final products = [makeVoiceProduct(name: 'Pepsi')];
      final match = matcher.match('Pepsi', products);
      expect(match, isA<ProductMatchUnique>());
      expect((match as ProductMatchUnique).product.name, 'Pepsi');
    });

    test('case-insensitive match', () {
      final products = [makeVoiceProduct(name: 'Pepsi 500ml')];
      final match = matcher.match('PEPSI 500ml', products);
      expect(match, isA<ProductMatchUnique>());
    });

    test('whitespace-tolerant match', () {
      final products = [makeVoiceProduct(name: 'Pepsi 500ml')];
      final match = matcher.match('  pepsi   500ml  ', products);
      expect(match, isA<ProductMatchUnique>());
    });

    test('spacing-insensitive match (500 ml vs 500ml)', () {
      final products = [makeVoiceProduct(name: 'Pepsi 500ml')];
      final match = matcher.match('pepsi 500 ml', products);
      expect(match, isA<ProductMatchUnique>());
    });
  });

  group('SKU matching', () {
    test('exact SKU match', () {
      final products = [
        makeVoiceProduct(id: 1, name: 'Pepsi', sku: 'PEP-500'),
        makeVoiceProduct(id: 2, name: 'Coke', sku: 'COK-500'),
      ];
      final match = matcher.match('pep-500', products);
      expect(match, isA<ProductMatchUnique>());
      expect((match as ProductMatchUnique).product.id, 1);
    });
  });

  group('partial matching', () {
    test('single partial hit resolves', () {
      final products = [
        makeVoiceProduct(name: 'Pepsi 500ml'),
        makeVoiceProduct(id: 2, name: 'Maggi 70g'),
      ];
      final match = matcher.match('peps', products);
      expect(match, isA<ProductMatchUnique>());
    });
  });

  group('ambiguity', () {
    test('multiple partial hits require clarification', () {
      final products = [
        makeVoiceProduct(id: 1, name: 'Pepsi'),
        makeVoiceProduct(id: 2, name: 'Pepsi Zero'),
        makeVoiceProduct(id: 3, name: 'Pepsi Diet'),
      ];
      final match = matcher.match('Pepsi', products);
      expect(match, isA<ProductMatchAmbiguous>());
      final candidates = (match as ProductMatchAmbiguous).candidates;
      expect(candidates.map((p) => p.name).toSet(),
          {'Pepsi', 'Pepsi Zero', 'Pepsi Diet'});
    });

    test('lone exact match executes immediately', () {
      final products = [
        makeVoiceProduct(name: 'Pepsi'),
        makeVoiceProduct(id: 2, name: 'Maggi'),
      ];
      final match = matcher.match('Pepsi', products);
      expect(match, isA<ProductMatchUnique>());
    });

    test('exact match shadowed by longer names clarifies, exact first', () {
      final products = [
        makeVoiceProduct(id: 1, name: 'Pepsi Zero'),
        makeVoiceProduct(id: 2, name: 'Pepsi'),
        makeVoiceProduct(id: 3, name: 'Pepsi Diet'),
      ];
      final match = matcher.match('Pepsi', products);
      expect(match, isA<ProductMatchAmbiguous>());
      final candidates = (match as ProductMatchAmbiguous).candidates;
      expect(candidates.first.name, 'Pepsi');
      expect(candidates.map((p) => p.name).toSet(),
          {'Pepsi', 'Pepsi Zero', 'Pepsi Diet'});
    });

    test('never silently picks among ambiguous candidates', () {
      final products = [
        makeVoiceProduct(id: 1, name: 'Pepsi'),
        makeVoiceProduct(id: 2, name: 'Pepsi Zero'),
      ];
      // Even a full exact hit on one name still overlaps others via partial —
      // exact wins here, but a shared prefix stays ambiguous.
      final exact = matcher.match('Pepsi Zero', products);
      expect(exact, isA<ProductMatchUnique>());
      final shared = matcher.match('Pepsi', products);
      expect(shared, isA<ProductMatchAmbiguous>());
    });
  });

  group('no match', () {
    test('unknown name returns none', () {
      final products = [makeVoiceProduct(name: 'Pepsi')];
      expect(matcher.match('Sprite', products), isA<ProductMatchNone>());
    });

    test('empty query returns none', () {
      final products = [makeVoiceProduct(name: 'Pepsi')];
      expect(matcher.match('   ', products), isA<ProductMatchNone>());
    });
  });

  group('active only', () {
    test('inactive products are invisible when the caller filters', () {
      final products = [
        makeVoiceProduct(name: 'Pepsi', active: false),
        makeVoiceProduct(id: 2, name: 'Coke'),
      ];
      // The controller always passes active products; the matcher itself
      // treats whatever list it gets as the catalog.
      final match = matcher.match(
        'Pepsi',
        products.where((p) => p.isActive).toList(),
      );
      expect(match, isA<ProductMatchNone>());
    });
  });
}
