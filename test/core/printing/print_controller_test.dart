import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/printing/data/unavailable_printer_service.dart';
import 'package:voice_pos/core/printing/domain/print_result.dart';
import 'package:voice_pos/core/printing/domain/printer_service.dart';
import 'package:voice_pos/core/printing/domain/receipt_data.dart';
import 'package:voice_pos/core/printing/presentation/print_controller.dart';

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

/// Scripted fake: plays back one result per call and counts invocations.
class FakePrinterService implements PrinterService {
  FakePrinterService(this.script);

  final List<PrintResult> script;
  int calls = 0;

  @override
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    calls++;
    if (script.isEmpty) return const PrintFailed('No scripted result');
    return script.removeAt(0);
  }
}

/// Printer that throws instead of returning a result (misbehaving adapter).
class ThrowingPrinterService implements PrinterService {
  int calls = 0;

  @override
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    calls++;
    throw StateError('adapter blew up');
  }
}

void main() {
  group('PrintController', () {
    test('forwards the receipt and reports success', () async {
      final printer = FakePrinterService([const PrintSuccess()]);
      final container = ProviderContainer(
        overrides: [printerServiceProvider.overrideWithValue(printer)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(printControllerProvider.notifier)
          .printReceipt(sampleReceipt());

      expect(result, isA<PrintSuccess>());
      expect(printer.calls, 1);
      expect(
        container.read(printControllerProvider),
        const AsyncData<PrintResult?>(PrintSuccess()),
      );
    });

    test('reports failure without throwing', () async {
      final printer = FakePrinterService([
        const PrintFailed('No paper'),
      ]);
      final container = ProviderContainer(
        overrides: [printerServiceProvider.overrideWithValue(printer)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(printControllerProvider.notifier)
          .printReceipt(sampleReceipt());

      expect(result, const PrintFailed('No paper'));
      expect(
        container.read(printControllerProvider),
        const AsyncData<PrintResult?>(PrintFailed('No paper')),
      );
    });

    test('reports unavailable from the default service', () async {
      final container = ProviderContainer(
        overrides: [
          printerServiceProvider
              .overrideWithValue(const UnavailablePrinterService()),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(printControllerProvider.notifier)
          .printReceipt(sampleReceipt());

      expect(result, isA<PrintUnavailable>());
    });

    test('converts a throwing adapter into failure', () async {
      final printer = ThrowingPrinterService();
      final container = ProviderContainer(
        overrides: [printerServiceProvider.overrideWithValue(printer)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(printControllerProvider.notifier)
          .printReceipt(sampleReceipt());

      expect(result, isA<PrintFailed>());
      expect(printer.calls, 1);
    });

    test('retry re-invokes the service with the same receipt', () async {
      final printer = FakePrinterService([
        const PrintFailed('No paper'),
        const PrintSuccess(),
      ]);
      final container = ProviderContainer(
        overrides: [printerServiceProvider.overrideWithValue(printer)],
      );
      addTearDown(container.dispose);
      final controller =
          container.read(printControllerProvider.notifier);
      final receipt = sampleReceipt();

      expect(await controller.printReceipt(receipt), isA<PrintFailed>());
      expect(await controller.printReceipt(receipt), isA<PrintSuccess>());
      expect(printer.calls, 2);
    });
  });
}
