import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../core/db/app_database.dart' as db;
import '../../../core/db/dao/product_dao.dart';
import '../../../core/errors/failures.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

/// Drift-backed [ProductRepository]. All writes validate first, then rely on
/// SQL constraints (UNIQUE indexes, CHECKs) as the final guarantee — never
/// Dart-side checking alone.
class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._dao);

  final ProductDao _dao;

  @override
  Future<Product> create({
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  }) async {
    Product.validateFields(
      name: name,
      sku: sku,
      sellingPricePaise: sellingPricePaise,
      costPricePaise: costPricePaise,
      stockQty: stockQty,
      lowStockThreshold: lowStockThreshold,
    );
    try {
      final id = await _dao.create(
        db.ProductsCompanion.insert(
          name: name.trim(),
          sku: Value(_normalizeSku(sku)),
          sellingPricePaise: sellingPricePaise,
          costPricePaise: Value(costPricePaise),
          stockQty: Value(stockQty),
          lowStockThreshold: Value(lowStockThreshold),
        ),
      );
      final row = await _dao.getById(id);
      if (row == null) {
        throw const DatabaseFailure(
          message: 'Product could not be read after creation.',
        );
      }
      return _toDomain(row);
    } on Failure {
      rethrow;
    } on SqliteException catch (e) {
      throw _mapConstraintError(e, name: name.trim());
    }
  }

  @override
  Future<Product?> getById(int id) async {
    final row = await _dao.getById(id);
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Product>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final rows = await _dao.search(query);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<Product>> getAllActive() async {
    final rows = await _dao.getAllActive();
    return rows.map(_toDomain).toList();
  }

  @override
  Stream<List<Product>> watchAll() {    return _dao.watchAllActive().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  @override
  Future<Product> update({
    required int id,
    required String name,
    required String? sku,
    required int sellingPricePaise,
    required int? costPricePaise,
    required int stockQty,
    required int lowStockThreshold,
  }) async {
    Product.validateFields(
      name: name,
      sku: sku,
      sellingPricePaise: sellingPricePaise,
      costPricePaise: costPricePaise,
      stockQty: stockQty,
      lowStockThreshold: lowStockThreshold,
    );
    final existing = await _dao.getById(id);
    if (existing == null || !existing.isActive) {
      throw ProductNotFoundFailure.forQuery('id $id');
    }
    try {
      await _dao.updateProduct(
        id,
        db.ProductsCompanion(
          name: Value(name.trim()),
          sku: Value(_normalizeSku(sku)),
          sellingPricePaise: Value(sellingPricePaise),
          costPricePaise: Value(costPricePaise),
          stockQty: Value(stockQty),
          lowStockThreshold: Value(lowStockThreshold),
        ),
      );
      final row = await _dao.getById(id);
      if (row == null) {
        throw const DatabaseFailure(
          message: 'Product could not be read after update.',
        );
      }
      return _toDomain(row);
    } on Failure {
      rethrow;
    } on SqliteException catch (e) {
      throw _mapConstraintError(e, name: name.trim());
    }
  }

  @override
  Future<void> deactivate(int id) async {
    final existing = await _dao.getById(id);
    if (existing == null || !existing.isActive) {
      throw ProductNotFoundFailure.forQuery('id $id');
    }
    await _dao.deactivate(id);
  }

  @override
  Future<Product> updateStock(int id, int newQty) async {
    if (newQty < 0) {
      throw const ValidationFailure(message: 'Stock cannot be negative.');
    }
    final existing = await _dao.getById(id);
    if (existing == null || !existing.isActive) {
      throw ProductNotFoundFailure.forQuery('id $id');
    }
    try {
      await _dao.updateStock(id, newQty);
    } on SqliteException catch (e) {
      throw _mapConstraintError(e, name: existing.name);
    }
    final row = await _dao.getById(id);
    if (row == null) {
      throw const DatabaseFailure(
        message: 'Product could not be read after stock update.',
      );
    }
    return _toDomain(row);
  }

  @override
  Stream<List<Product>> watchLowStock() {
    return _dao.watchLowStock().map(
          (rows) => rows.map(_toDomain).toList(),
        );
  }

  /// Blank/whitespace SKU means "no SKU" — stored as NULL so the partial
  /// unique index ignores it.
  String? _normalizeSku(String? sku) {
    if (sku == null) return null;
    final trimmed = sku.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Product _toDomain(db.Product row) {
    return Product(
      id: row.id,
      name: row.name,
      sku: row.sku,
      sellingPricePaise: row.sellingPricePaise,
      costPricePaise: row.costPricePaise,
      stockQty: row.stockQty,
      lowStockThreshold: row.lowStockThreshold,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Failure _mapConstraintError(SqliteException e, {required String name}) {
    final message = e.message;
    if (message.contains('products_name_active_unique') ||
        (message.contains('UNIQUE constraint failed') &&
            message.contains('products.name'))) {
      return ValidationFailure(
        message: 'A product named "$name" already exists.',
      );
    }
    if (message.contains('products_sku_active_unique') ||
        (message.contains('UNIQUE constraint failed') &&
            message.contains('products.sku'))) {
      return const ValidationFailure(
        message: 'This SKU is already used by another product.',
      );
    }
    if (message.contains('CHECK constraint failed')) {
      return const ValidationFailure(
        message: 'Product values are out of allowed range.',
      );
    }
    return DatabaseFailure(message: 'Database error: ${e.message}');
  }
}
