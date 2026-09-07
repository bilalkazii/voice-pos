import 'package:drift/drift.dart';

/// Completed-sale header (schema v2).
///
/// Money is ALWAYS integer paise — never floating point. `subtotalPaise`
/// and `totalPaise` are identical in V1 (no tax, discount, or fees); both
/// are stored so future phases can diverge them without migrating history.
///
/// `paymentMethod` stores the domain [PaymentMethod] value as text
/// (`'cash'` is the only V1 value). `transactionNumber` is UNIQUE and
/// generated locally at checkout (offline, no backend).
class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get transactionNumber =>
      text().named('transaction_number').unique()();

  TextColumn get paymentMethod => text().named('payment_method')();

  IntColumn get subtotalPaise => integer().named('subtotal_paise')();

  IntColumn get totalPaise => integer().named('total_paise')();

  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => const [
        'CHECK (subtotal_paise >= 0)',
        'CHECK (total_paise >= 0)',
      ];
}

/// One line of a completed sale (schema v2).
///
/// Snapshots — never live references: if a product is later renamed,
/// repriced, or deactivated, the recorded sale is unchanged. This is what
/// receipts and (future) history read.
class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId =>
      integer().named('sale_id').customConstraint('REFERENCES sales(id)')();

  IntColumn get productId => integer()
      .named('product_id')
      .customConstraint('REFERENCES products(id)')();

  /// Product name at the moment of sale.
  TextColumn get productName => text().named('product_name')();

  /// SKU at the moment of sale (nullable — SKU itself is optional).
  TextColumn get sku => text().named('sku').nullable()();

  /// Unit price charged (the cart's price snapshot, NOT the live product
  /// price — the customer saw this price on the bill).
  IntColumn get unitPricePaise => integer().named('unit_price_paise')();

  IntColumn get quantity => integer()();

  IntColumn get lineTotalPaise => integer().named('line_total_paise')();

  @override
  List<String> get customConstraints => const [
        'CHECK (unit_price_paise >= 0)',
        'CHECK (quantity >= 1)',
        'CHECK (line_total_paise >= 0)',
      ];
}
