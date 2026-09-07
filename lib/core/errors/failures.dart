/// Base failure type for Voice POS.
///
/// Keep this hierarchy small for V1. Failures carry only the data the UI
/// needs to show a message or, for ambiguous products, clarification options.
///
/// V1 has no Result/Either abstraction — features return values or throw/
/// return these failures through their state layer in later phases.
sealed class Failure {
  const Failure({required this.message});

  /// Human-readable message safe to show to a cashier.
  final String message;
}

/// No product matches the requested name or SKU.
class ProductNotFoundFailure extends Failure {
  const ProductNotFoundFailure({required super.message});

  /// The raw query (product name / SKU) that failed to match.
  factory ProductNotFoundFailure.forQuery(String query) =>
      ProductNotFoundFailure(message: 'Product not found: $query');
}

/// Multiple products match and the user must pick one.
/// Voice must never silently guess in this case.
class AmbiguousProductFailure extends Failure {
  const AmbiguousProductFailure({
    required super.message,
    required this.options,
  });

  /// Candidate product names shown for clarification.
  final List<String> options;
}

/// Requested quantity exceeds available stock.
class OutOfStockFailure extends Failure {
  const OutOfStockFailure({required super.message});
}

/// Checkout (or another cart operation) needs items but the cart is empty.
class EmptyCartFailure extends Failure {
  const EmptyCartFailure({super.message = 'Cart is empty'});
}

/// Bluetooth / thermal printer operation failed. The sale itself is never
/// rolled back because of this — printing is retried independently.
class PrinterFailure extends Failure {
  const PrinterFailure({required super.message});
}

/// Local database operation failed.
class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message});
}

/// Input validation failed (e.g. bad price, bad quantity, blank name).
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}
