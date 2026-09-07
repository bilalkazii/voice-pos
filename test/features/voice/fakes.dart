import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/products/domain/product.dart';
import 'package:voice_pos/features/products/domain/product_repository.dart';
import 'package:voice_pos/features/voice/domain/speech_services.dart';

/// Canned speech recognition: no microphone hardware needed.
class FakeSpeechService implements SpeechToTextService {
  FakeSpeechService({
    this.transcript,
    this.available = true,
    this.permissionGranted = true,
  });

  String? transcript;
  bool available;
  bool permissionGranted;
  int listenCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> initialize() async => available && permissionGranted;

  @override
  Future<bool> get hasPermission async => permissionGranted;

  @override
  Future<String?> listenOnce() async {
    listenCalls++;
    return transcript;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }
}

/// Recording TTS double: never plays audio.
class FakeFeedbackService implements VoiceFeedbackService {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

Product makeVoiceProduct({
  int id = 1,
  String name = 'Pepsi',
  String? sku,
  int price = 2000,
  int stock = 10,
  bool active = true,
}) {
  final now = DateTime(2026, 1, 1);
  return Product(
    id: id,
    name: name,
    sku: sku,
    sellingPricePaise: price,
    costPricePaise: null,
    stockQty: stock,
    lowStockThreshold: 2,
    isActive: active,
    createdAt: now,
    updatedAt: now,
  );
}

/// In-memory [ProductRepository] for voice tests: active-only catalog,
/// no database, no timers.
class FakeProductRepository implements ProductRepository {
  FakeProductRepository([List<Product>? initial])
      : _items = List.of(initial ?? const []);

  final List<Product> _items;
  int _nextId = 1000;

  List<Product> get _active => _items.where((p) => p.isActive).toList();

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
    final now = DateTime.now();
    final product = Product(
      id: _nextId++,
      name: name.trim(),
      sku: sku?.trim().isEmpty == true ? null : sku?.trim(),
      sellingPricePaise: sellingPricePaise,
      costPricePaise: costPricePaise,
      stockQty: stockQty,
      lowStockThreshold: lowStockThreshold,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
    _items.add(product);
    return product;
  }

  @override
  Future<Product?> getById(int id) async {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Product>> search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _active
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              (p.sku != null && p.sku!.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Future<List<Product>> getAllActive() async => _active;

  @override
  Stream<List<Product>> watchAll() => Stream.value(_active);

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
    final index = _items.indexWhere((p) => p.id == id);
    if (index < 0) throw ProductNotFoundFailure.forQuery('id $id');
    final updated = _items[index].copyWith(
      name: name.trim(),
      sku: sku,
      sellingPricePaise: sellingPricePaise,
      costPricePaise: costPricePaise,
      stockQty: stockQty,
      lowStockThreshold: lowStockThreshold,
      updatedAt: DateTime.now(),
    );
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> deactivate(int id) async {
    final index = _items.indexWhere((p) => p.id == id);
    if (index < 0) throw ProductNotFoundFailure.forQuery('id $id');
    _items[index] = _items[index].copyWith(isActive: false);
  }

  @override
  Future<Product> updateStock(int id, int newQty) async {
    if (newQty < 0) {
      throw const ValidationFailure(message: 'Stock cannot be negative.');
    }
    final index = _items.indexWhere((p) => p.id == id);
    if (index < 0) throw ProductNotFoundFailure.forQuery('id $id');
    _items[index] = _items[index].copyWith(stockQty: newQty);
    return _items[index];
  }

  @override
  Stream<List<Product>> watchLowStock() => Stream.value(
        _active.where((p) => p.isLowStock).toList(),
      );
}
