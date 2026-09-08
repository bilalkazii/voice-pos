import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/presentation/settings_providers.dart';
import '../bluetooth/bluetooth_transport.dart';
import '../bluetooth/spp_bluetooth_transport.dart';
import '../data/bluetooth_printer_service.dart';
import '../domain/print_result.dart';
import '../domain/printer_service.dart';
import '../domain/receipt_data.dart';

/// Short-lived SPP transport. Constructing it performs zero platform work;
/// every method degrades gracefully, so building this provider is safe in
/// widget tests (fakes override it wherever Bluetooth is exercised).
final bluetoothTransportProvider = Provider<BluetoothTransport>((ref) {
  const transport = SppBluetoothTransport();
  ref.onDispose(() => unawaited(transport.dispose()));
  return transport;
});

/// The [PrinterService] in use: the real Bluetooth/ESC-POS adapter reading
/// its configuration from Settings. With no printer configured it honestly
/// reports unavailable — [CheckoutService] and everything downstream is
/// untouched by printing.
final printerServiceProvider = Provider<PrinterService>(
  (ref) {
    return BluetoothPrinterService(
      settings: ref.watch(settingsRepositoryProvider),
      transport: ref.watch(bluetoothTransportProvider),
    );
  },
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
