import '../../../core/errors/failures.dart';

/// Immutable product domain model. Pure Dart — no Flutter, no Drift.
///
/// The UI and voice layers depend on this, never on generated row classes.
/// Money is integer paise throughout.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.sellingPricePaise,
    required this.costPricePaise,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final String? sku;
  final int sellingPricePaise;
  final int? costPricePaise;
  final int stockQty;
  final int lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Low-stock means at/under threshold. Callers filter `isActive` first —
  /// only active products appear in low-stock results.
  bool get isLowStock => stockQty <= lowStockThreshold;

  Product copyWith({
    int? id,
    String? name,
    String? sku,
    int? sellingPricePaise,
    int? costPricePaise,
    int? stockQty,
    int? lowStockThreshold,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      sellingPricePaise: sellingPricePaise ?? this.sellingPricePaise,
      costPricePaise: costPricePaise ?? this.costPricePaise,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validates product input fields. Throws [ValidationFailure] describing
  /// the first problem. Used by the repository before touching the database.
  static void validateFields({
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  }) {
    if (name.trim().isEmpty) {
      throw const ValidationFailure(message: 'Product name is required.');
    }
    if (name.trim().length > 100) {
      throw const ValidationFailure(
        message: 'Product name must be 100 characters or fewer.',
      );
    }
    if (sku != null && sku.trim().isEmpty) {
      throw const ValidationFailure(message: 'SKU cannot be blank.');
    }
    if (sellingPricePaise < 0) {
      throw const ValidationFailure(message: 'Price cannot be negative.');
    }
    if (costPricePaise != null && costPricePaise < 0) {
      throw const ValidationFailure(message: 'Cost price cannot be negative.');
    }
    if (stockQty < 0) {
      throw const ValidationFailure(message: 'Stock cannot be negative.');
    }
    if (lowStockThreshold < 0) {
      throw const ValidationFailure(
        message: 'Low-stock threshold cannot be negative.',
      );
    }
  }

  /// Converts a cashier-typed price (e.g. "112", "112.5", "112.00", "₹1,050.25")
  /// into integer paise using integer math only — never `double`.
  ///
  /// Returns `null` when the input is not a valid non-negative price.
  static int? tryParsePriceToPaise(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;
    text = text.replaceAll('₹', '').replaceAll(',', '').trim();
    final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) return null;
    final rupees = int.parse(match.group(1)!);
    final paise = int.parse((match.group(2) ?? '0').padRight(2, '0'));
    return rupees * 100 + paise;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          id == other.id &&
          name == other.name &&
          sku == other.sku &&
          sellingPricePaise == other.sellingPricePaise &&
          costPricePaise == other.costPricePaise &&
          stockQty == other.stockQty &&
          lowStockThreshold == other.lowStockThreshold &&
          isActive == other.isActive &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        sku,
        sellingPricePaise,
        costPricePaise,
        stockQty,
        lowStockThreshold,
        isActive,
        createdAt,
        updatedAt,
      );
}
