import '../domain/print_result.dart';
import '../domain/printer_service.dart';
import '../domain/receipt_data.dart';

/// Default Phase 8A implementation: honestly reports that no printer is
/// configured. It performs no I/O, keeps no state, and never pretends to
/// print — success can only come from a real hardware adapter in a later
/// phase. The committed sale is always unaffected.
class UnavailablePrinterService implements PrinterService {
  const UnavailablePrinterService();

  @override
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    return const PrintUnavailable('Printer not configured');
  }
}
