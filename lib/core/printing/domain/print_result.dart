/// Typed outcome of one print attempt. Pure Dart.
///
/// The three cases are structurally distinguishable so callers can never
/// confuse "no printer" with "printed" or "failed":
/// - [PrintSuccess] — a real adapter reported success.
/// - [PrintUnavailable] — no printer configured/connected; the sale is
///   unaffected and the user may retry later.
/// - [PrintFailed] — the attempt failed; the SAME receipt may be retried
///   without touching checkout, cart, or inventory.
sealed class PrintResult {
  const PrintResult();

  /// Human-readable message safe to show to a cashier.
  String get message => '';
}

/// A real printer adapter reported success.
final class PrintSuccess extends PrintResult {
  const PrintSuccess();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is PrintSuccess;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'PrintSuccess()';
}

/// No printer is configured or reachable. Never a success, never a failure
/// of the sale itself.
final class PrintUnavailable extends PrintResult {
  const PrintUnavailable([this.message = 'Printer not configured']);

  @override
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintUnavailable && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'PrintUnavailable(message: $message)';
}

/// The print attempt failed. Retry with the SAME [ReceiptData].
final class PrintFailed extends PrintResult {
  const PrintFailed([this.message = 'Printing failed']);

  @override
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintFailed && message == other.message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => 'PrintFailed(message: $message)';
}
