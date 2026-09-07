import '../../products/domain/product.dart';

/// Outcome of resolving spoken text against the active catalog.
sealed class ProductMatch {
  const ProductMatch();
}

/// Exactly one product matched — safe to execute.
class ProductMatchUnique extends ProductMatch {
  const ProductMatchUnique(this.product);

  final Product product;
}

/// Nothing matched — report "not found", never guess.
class ProductMatchNone extends ProductMatch {
  const ProductMatchNone();
}

/// Several products matched — ask the user, never pick silently.
class ProductMatchAmbiguous extends ProductMatch {
  const ProductMatchAmbiguous(this.candidates);

  final List<Product> candidates;
}

/// Deterministic matcher over an ACTIVE-products snapshot. Pure function —
/// no database access; the caller supplies the list (voice never touches
/// the DB directly).
///
/// Order of checks:
/// 1. Exact name, case-insensitive → unique.
/// 2. Exact SKU, case-insensitive → unique.
/// 3. Spacing-insensitive exact name ("500 ml" vs "500ml") → unique.
/// 4. Controlled partial: names CONTAINING the query (case-insensitive).
///    One hit → unique; several → ambiguous, shortest name first for a
///    stable, predictable candidate order; none → no match.
///
/// No fuzzy/phonetic/Levenshtein matching in V1 — predictable misses beat
/// silent wrong picks.
class ProductMatcher {
  const ProductMatcher();

  ProductMatch match(String query, List<Product> products) {
    final q = _normalize(query);
    if (q.isEmpty) return const ProductMatchNone();

    final exact = products.where((p) => _normalize(p.name) == q).toList();
    if (exact.length == 1) {
      // "Add Pepsi" with [Pepsi, Pepsi Zero, Pepsi Diet] on the shelf must
      // NOT silently take Pepsi: the name also prefixes other products, so
      // the cashier clarifies. A lone exact match executes immediately.
      final shadowed = products
          .where((p) =>
              p.id != exact.first.id && _normalize(p.name).contains(q))
          .toList();
      if (shadowed.isEmpty) return ProductMatchUnique(exact.first);
      return ProductMatchAmbiguous([exact.first, ..._byShortest(shadowed)]);
    }
    if (exact.isNotEmpty) return ProductMatchAmbiguous(exact);

    final bySku = products
        .where((p) => p.sku != null && p.sku!.toLowerCase() == q)
        .toList();
    if (bySku.length == 1) return ProductMatchUnique(bySku.first);
    if (bySku.isNotEmpty) return ProductMatchAmbiguous(bySku);

    final compact = q.replaceAll(' ', '');
    final noSpace = products
        .where((p) => _normalize(p.name).replaceAll(' ', '') == compact)
        .toList();
    if (noSpace.length == 1) return ProductMatchUnique(noSpace.first);
    if (noSpace.isNotEmpty) return ProductMatchAmbiguous(noSpace);

    final partial =
        products.where((p) => _normalize(p.name).contains(q)).toList();
    if (partial.length == 1) return ProductMatchUnique(partial.first);
    if (partial.isNotEmpty) {
      return ProductMatchAmbiguous(_byShortest(partial));
    }
    return const ProductMatchNone();
  }

  /// Shortest name first, then alphabetical — stable candidate order.
  List<Product> _byShortest(List<Product> products) {
    final sorted = List.of(products);
    sorted.sort((a, b) {
      final byLength = a.name.length.compareTo(b.name.length);
      return byLength != 0
          ? byLength
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  String _normalize(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
