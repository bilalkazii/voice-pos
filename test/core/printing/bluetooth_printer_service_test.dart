import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart'
    hide Product, Sale, SaleItem;
import 'package:voice_pos/core/printing/data/bluetooth_printer_service.dart';
import 'package:voice_pos/core/printing/domain/print_result.dart';
import 'package:voice_pos/core/printing/domain/receipt_data.dart';
import 'package:voice_pos/core/printing/domain/receipt_mapper.dart';
import 'package:voice_pos/core/printing/esc_pos/esc_pos_encoder.dart';
import 'package:voice_pos/features/cart/domain/cart_service.dart';
import 'package:voice_pos/features/cart/domain/cart_state.dart';
import 'package:voice_pos/features/checkout/domain/checkout_service.dart';
import 'package:voice_pos/features/products/data/product_repository_impl.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';
import 'package:voice_pos/features/settings/domain/app_settings.dart';
import 'package:voice_pos/features/settings/domain/settings_repository.dart';

import 'fakes.dart';

const testAddress = '66:02:BD:06:18:7B';

ReceiptData sampleReceipt() {
  return ReceiptData(
    storeName: 'Kazi Mart',
    transactionNumber: 'VP-1788804734779-1822',
    createdAt: DateTime(2026, 9, 7, 21, 42),
    paymentMethod: 'cash',
    subtotalPaise: 8000,
    totalPaise: 8000,
    items: const [
      ReceiptLineItem(
        productName: 'Pepsi 500ml',
        sku: 'PEP-500',
        unitPricePaise: 4000,
        quantity: 2,
        lineTotalPaise: 8000,
      ),
    ],
  );
}

/// Settings repository that throws on load (storage failure).
class ThrowingSettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> load() => throw StateError('db gone');

  @override
  Stream<AppSettings> watch() => throw StateError('db gone');

  @override
  Future<void> saveStoreName(String name) => throw StateError('db gone');

  @override
  Future<void> setVoiceFeedbackEnabled(bool enabled) =>
      throw StateError('db gone');

  @override
  Future<void> setDefaultLowStockThreshold(int threshold) =>
      throw StateError('db gone');

  @override
  Future<void> setPrinterSelection({String? id, String? name}) =>
      throw StateError('db gone');
}

Future<DriftSettingsRepository> openSettingsRepo() async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return DriftSettingsRepository(db.settingsDao);
}

BluetoothPrinterService adapter({
  required SettingsRepository settings,
  required FakeBluetoothTransport transport,
}) {
  return BluetoothPrinterService(
    settings: settings,
    transport: transport,
    connectTimeout: const Duration(milliseconds: 50),
    writeTimeout: const Duration(milliseconds: 50),
  );
}

void main() {
  group('BluetoothPrinterService precondition mapping', () {
    test('no configured printer returns unavailable, transport untouched',
        () async {
      final settings = await openSettingsRepo();
      final transport = FakeBluetoothTransport();
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintUnavailable>());
      expect(result.message, contains('not configured'));
      expect(transport.connects, 0);
      expect(transport.permissionRequests, 0);
      expect(transport.writtenBatches, isEmpty);
    });

    test('permission denied returns unavailable without connecting',
        () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(permissionGranted: false);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintUnavailable>());
      expect(result.message, contains('permission'));
      expect(transport.permissionRequests, 1);
      expect(transport.connects, 0);
    });

    test('bluetooth off returns unavailable without connecting', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(bluetoothOn: false);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintUnavailable>());
      expect(result.message, contains('turned off'));
      expect(transport.connects, 0);
    });

    test('settings storage failure returns failed, not unavailable',
        () async {
      final transport = FakeBluetoothTransport();
      final service = adapter(
        settings: ThrowingSettingsRepository(),
        transport: transport,
      );

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(transport.connects, 0);
    });
  });

  group('BluetoothPrinterService transport failures', () {
    test('connection failure returns failed and disconnects', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(connectResults: [false]);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(result.message, contains('connect'));
      expect(transport.lastConnectedAddress, testAddress);
    });

    test('connection timeout returns failed', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(hangConnect: true);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(transport.disconnects, greaterThanOrEqualTo(0));
    });

    test('write failure returns failed and still disconnects', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(writeResults: [false]);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(result.message, contains('send'));
      expect(transport.disconnects, 1);
    });

    test('write throw returns failed and still disconnects', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(throwOnWrite: true);
      final service =
          adapter(settings: settings, transport: transport);

      final result = await service.printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(transport.disconnects, 1);
    });
  });

  group('BluetoothPrinterService success', () {
    test('reports success only after bytes are written, then disconnects',
        () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport();
      final service =
          adapter(settings: settings, transport: transport);
      final receipt = sampleReceipt();

      final result = await service.printReceipt(receipt);

      expect(result, isA<PrintSuccess>());
      expect(transport.connects, 1);
      expect(transport.writtenBatches.length, 1);
      expect(
        transport.writtenBatches.single,
        const EscPosEncoder().encode(receipt),
      );
      expect(transport.disconnects, 1);
    });

    test('identical receipts produce identical bytes on retry', () async {
      final settings = await openSettingsRepo();
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(
        writeResults: [false, true],
      );
      final service =
          adapter(settings: settings, transport: transport);
      final receipt = sampleReceipt();

      expect(await service.printReceipt(receipt), isA<PrintFailed>());
      expect(await service.printReceipt(receipt), isA<PrintSuccess>());

      expect(transport.writtenBatches.length, 2);
      expect(transport.writtenBatches[0], transport.writtenBatches[1]);
      expect(await settings.load(), isNotNull);
    });
  });

  group('BluetoothPrinterService checkout boundary', () {
    test('printing never touches sales or inventory', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final products = DriftProductRepository(db.productDao);
      final pepsi = await products.create(
        name: 'Pepsi 500ml',
        sku: 'PEP-500',
        sellingPricePaise: 4000,
        costPricePaise: null,
        stockQty: 10,
        lowStockThreshold: 2,
      );
      final cart = CartService.addProduct(
        const CartState(),
        pepsi,
        quantity: 2,
      );
      final sale = await CheckoutService(db).completeCashSale(cart);
      final settings = DriftSettingsRepository(db.settingsDao);
      await settings.setPrinterSelection(id: testAddress, name: 'T-58');
      final transport = FakeBluetoothTransport(
        writeResults: [false, true],
      );
      final service = BluetoothPrinterService(
        settings: settings,
        transport: transport,
        connectTimeout: const Duration(milliseconds: 50),
        writeTimeout: const Duration(milliseconds: 50),
      );
      final receipt = ReceiptMapper.toReceiptData(
        sale,
        storeName: 'Kazi Mart',
      );

      await service.printReceipt(receipt);
      await service.printReceipt(receipt);

      // Exactly one sale; inventory reflects only the checkout deduction.
      expect(await db.saleDao.saleCount(), 1);
      expect(
        (await products.getById(sale.items.first.productId))!.stockQty,
        8,
      );
      expect(receipt.transactionNumber, sale.sale.transactionNumber);
      expect(transport.writtenBatches.length, 2);
      expect(transport.writtenBatches[0], transport.writtenBatches[1]);
    });
  });
}
