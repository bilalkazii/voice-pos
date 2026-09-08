import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/unavailable_printer_service.dart';
import '../domain/print_result.dart';
import '../domain/printer_service.dart';
import '../domain/receipt_data.dart';

/// The [PrinterService] in use. Phase 8A wires the honest
/// [UnavailablePrinterService]; a later hardware phase replaces this
/// single override with a Bluetooth/ESC-POS adapter — nothing else,
/// especially not [CheckoutService], changes.
final printerServiceProvider = Provider<PrinterService>(
  (ref) => const UnavailablePrinterService(),
);

/// Coordinates print attempts for ONE already-committed receipt.
///
/// Owns no sale/cart/database state — it only forwards the given
/// [ReceiptData] to the [PrinterService] and reports the outcome, so a
/// retry trivially reuses the same receipt and can never re-enter
/// checkout. Unexpected throws become [PrintFailed], never crashes.
///
/// State: `null` = never attempted, loading = printing, data = last
/// outcome. The loading intermediate guarantees consecutive identical
/// results still notify listeners.
class PrintController extends Notifier<AsyncValue<PrintResult?>> {
  @override
  AsyncValue<PrintResult?> build() => const AsyncData(null);

  /// Prints [receipt] and returns the outcome. Safe to call for every
  /// retry — each call prints the same committed data.
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    state = const AsyncLoading();
    try {
      final result =
          await ref.read(printerServiceProvider).printReceipt(receipt);
      state = AsyncData(result);
      return result;
    } catch (_) {
      const result = PrintFailed('Printing failed. Please try again.');
      state = const AsyncData(result);
      return result;
    }
  }

  void reset() {
    state = const AsyncData(null);
  }
}

final printControllerProvider =
    NotifierProvider<PrintController, AsyncValue<PrintResult?>>(
  PrintController.new,
);
