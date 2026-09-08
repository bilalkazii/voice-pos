import 'print_result.dart';
import 'receipt_data.dart';

/// Narrow printer abstraction. Accepts ONLY immutable receipt data for an
/// already-committed sale.
///
/// It must NEVER accept [CartState]-like mutable sale state, checkout
/// controllers/services, database transactions, or live product lookups —
/// the type system enforces this by exposing just [ReceiptData].
///
/// Implementations return a [PrintResult] for known outcomes. Unexpected
/// throws are converted to [PrintFailed] by the caller, never by the sale
/// layer — printing can neither roll back nor duplicate a transaction.
abstract class PrinterService {
  /// Attempts to print [receipt]. Must be idempotent with respect to the
  /// sale: calling it again with the same receipt must not create anything.
  Future<PrintResult> printReceipt(ReceiptData receipt);
}
