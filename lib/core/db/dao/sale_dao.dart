import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sale_tables.dart';

part 'sale_dao.g.dart';

/// Data access for completed sales. Works with Drift rows only — the
/// repository layer maps these to domain models.
///
/// Stock deduction lives here as a guarded raw update so the checkout
/// transaction can verify affected rows:
/// `UPDATE products SET stock_qty = stock_qty - ? WHERE id = ? AND
/// is_active = 1 AND stock_qty >= ?` — zero affected rows means the sale
/// must roll back.
/// A sale header plus its aggregate item count (SUM of line quantities),
/// produced by a single database-side JOIN + GROUP BY — no per-row N+1.
class SaleWithCount {
  const SaleWithCount({required this.sale, required this.itemCount});

  final Sale sale;
  final int itemCount;
}

/// One aggregated top-selling row (historical product identity + name).
class TopSellingRow {
  const TopSellingRow({
    required this.productId,
    required this.productName,
    required this.quantitySold,
  });

  final int productId;
  final String productName;
  final int quantitySold;
}

@DriftAccessor(tables: [Sales, SaleItems])
class SaleDao extends DatabaseAccessor<AppDatabase> with _$SaleDaoMixin {
  SaleDao(super.db);

  Future<int> createSale(SalesCompanion entry) {
    return into(sales).insert(entry);
  }

  Future<void> createSaleItems(List<SaleItemsCompanion> entries) {
    return batch((b) => b.insertAll(saleItems, entries));
  }

  Future<Sale?> getSaleById(int id) {
    return (select(sales)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Sale?> getSaleByTransactionNumber(String transactionNumber) {
    return (select(sales)
          ..where((t) => t.transactionNumber.equals(transactionNumber)))
        .getSingleOrNull();
  }

  Future<List<SaleItem>> getItemsForSale(int saleId) {
    return (select(saleItems)
          ..where((t) => t.saleId.equals(saleId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Most recent sales, newest first. History screens build on this.
  Future<List<Sale>> recentSales({int limit = 50}) {
    return (select(sales)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  Stream<List<Sale>> watchRecentSales({int limit = 50}) {
    return (select(sales)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .watch();
  }

  /// Reactive, bounded history query that composes optional filters and
  /// includes the item count via a JOIN:
  /// - [after]: only sales created at/after that instant (Today filter)
  /// - [transactionSearch]: case-insensitive partial match on the
  ///   transaction number (LIKE is case-insensitive for ASCII in SQLite)
  /// - created_at index is leveraged; ordered newest-first, capped at
  ///   [limit].
  ///
  /// The WHERE clauses add together (AND). Data stays reactive: a new
  /// commit in another flow appears without restarting the app.
  Stream<List<SaleWithCount>> watchSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit = 50,
  }) {
    final sumQty = saleItems.quantity.sum();
    return _buildSalesWithCountQuery(
      sumQty: sumQty,
      after: after,
      transactionSearch: transactionSearch,
      limit: limit,
    ).watch().map((rows) => _readSaleWithCount(rows, sumQty));
  }

  /// One-shot bounded history query with the same filters as
  /// [watchSalesWithCount].
  Future<List<SaleWithCount>> getSalesWithCount({
    DateTime? after,
    String? transactionSearch,
    int limit = 50,
  }) {
    final sumQty = saleItems.quantity.sum();
    return _buildSalesWithCountQuery(
      sumQty: sumQty,
      after: after,
      transactionSearch: transactionSearch,
      limit: limit,
    ).get().then((rows) => _readSaleWithCount(rows, sumQty));
  }

  JoinedSelectStatement<HasResultSet, dynamic> _buildSalesWithCountQuery({
    required Expression<int> sumQty,
    DateTime? after,
    String? transactionSearch,
    int limit = 50,
  }) {
    // Note: `.join(...)` returns a NEW statement, so it can't be part of a
    // cascade (cascades return the receiver). Assign it explicitly.
    final query = select(sales).join([
      leftOuterJoin(saleItems, saleItems.saleId.equalsExp(sales.id)),
    ]);
    query
      ..addColumns([sumQty])
      ..groupBy([sales.id])
      ..orderBy([OrderingTerm.desc(sales.createdAt)])
      ..limit(limit);
    if (after != null) {
      query.where(sales.createdAt.isBiggerOrEqualValue(after));
    }
    final trimmed = transactionSearch?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      query.where(sales.transactionNumber.like('%$trimmed%'));
    }
    return query;
  }

  List<SaleWithCount> _readSaleWithCount(
    List<TypedResult> rows,
    Expression<int> sumQty,
  ) {
    return rows
        .map(
          (row) => SaleWithCount(
            sale: row.readTable(sales),
            itemCount: row.read(sumQty) ?? 0,
          ),
        )
        .toList();
  }

  Future<int> saleCount() {
    return (selectOnly(sales)..addColumns([sales.id.count()]))
        .map((row) => row.read(sales.id.count()) ?? 0)
        .getSingle();
  }

  /// One-shot sales summary for a half-open date range
  /// (`created_at >= start AND created_at < end`), computed in SQLite.
  /// Returns total paise and transaction count; no sale rows are loaded
  /// into Dart.
  Future<({int totalSalesPaise, int transactionCount})> getSalesSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final total = sales.totalPaise.sum();
    final count = sales.id.count();
    final row = await (selectOnly(sales)
          ..addColumns([total, count])
          ..where(
            sales.createdAt.isBiggerOrEqualValue(start) &
                sales.createdAt.isSmallerThanValue(end),
          ))
        .getSingle();
    return (
      totalSalesPaise: row.read(total) ?? 0,
      transactionCount: row.read(count) ?? 0,
    );
  }

  /// Reactive sales summary for a half-open date range — updates live when
  /// a new sale commits, so the dashboard refreshes without a restart.
  Stream<({int totalSalesPaise, int transactionCount})> watchSalesSummary({
    required DateTime start,
    required DateTime end,
  }) {
    final total = sales.totalPaise.sum();
    final count = sales.id.count();
    return (selectOnly(sales)
          ..addColumns([total, count])
          ..where(
            sales.createdAt.isBiggerOrEqualValue(start) &
                sales.createdAt.isSmallerThanValue(end),
          ))
        .watchSingle()
        .map(
          (row) => (
            totalSalesPaise: row.read(total) ?? 0,
            transactionCount: row.read(count) ?? 0,
          ),
        );
  }

  /// Top-selling products for a half-open date range, aggregated in SQLite:
  /// group by the historical product identity + snapshot name, sum quantity,
  /// order by sold desc then name asc (deterministic ties), bounded by
  /// [limit].
  ///
  /// Uses `sale_items.product_name` directly — it NEVER joins the current
  /// Products table for the display name, so renamed/deactivated products
  /// still report under the name that was actually rung up.
  Future<List<TopSellingRow>> getTopSelling({
    required DateTime start,
    required DateTime end,
    int limit = 5,
  }) {
    return _topSellingSelect(
      start: start,
      end: end,
      limit: limit,
    ).get().then(_readTopSelling);
  }

  Stream<List<TopSellingRow>> watchTopSelling({
    required DateTime start,
    required DateTime end,
    int limit = 5,
  }) {
    return _topSellingSelect(
      start: start,
      end: end,
      limit: limit,
    ).watch().map(_readTopSelling);
  }

  Selectable<QueryRow> _topSellingSelect({
    required DateTime start,
    required DateTime end,
    required int limit,
  }) {
    return attachedDatabase.customSelect(
      'SELECT sale_items.product_id AS product_id, '
      'sale_items.product_name AS product_name, '
      'SUM(sale_items.quantity) AS sold '
      'FROM sale_items '
      'JOIN sales ON sales.id = sale_items.sale_id '
      'WHERE sales.created_at >= ? AND sales.created_at < ? '
      'GROUP BY sale_items.product_id, sale_items.product_name '
      'ORDER BY sold DESC, product_name ASC, product_id ASC '
      'LIMIT ?',
      variables: [
        Variable.withDateTime(start),
        Variable.withDateTime(end),
        Variable.withInt(limit),
      ],
      // Re-run the query whenever sales or sale_items change, so the
      // dashboard's top-selling list updates live after a new checkout.
      readsFrom: {sales, saleItems},
    );
  }

  List<TopSellingRow> _readTopSelling(List<QueryRow> rows) {
    return rows
        .map(
          (row) => TopSellingRow(
            productId: row.read<int>('product_id'),
            productName: row.read<String>('product_name'),
            quantitySold: row.read<int>('sold'),
          ),
        )
        .toList();
  }

  /// Atomically decrements stock, guarded against oversell and inactive
  /// products. Returns affected rows — the caller MUST treat 0 as failure
  /// and roll the surrounding transaction back.
  ///
  /// `updated_at` is bound as a Drift DateTime (integer storage, matching
  /// the table type) — never `CURRENT_TIMESTAMP`, which SQLite returns as
  /// text and Drift cannot read back.
  Future<int> deductStockGuarded(int productId, int quantity) {
    return attachedDatabase.customUpdate(
      'UPDATE products SET stock_qty = stock_qty - ?, updated_at = ? '
      'WHERE id = ? AND is_active = 1 AND stock_qty >= ?',
      variables: [
        Variable.withInt(quantity),
        Variable.withDateTime(DateTime.now()),
        Variable.withInt(productId),
        Variable.withInt(quantity),
      ],
      updates: {attachedDatabase.products},
    );
  }
}
