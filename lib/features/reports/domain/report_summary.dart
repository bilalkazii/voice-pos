/// Aggregated metrics for a selected report date range. Integer paise only.
///
/// `averageBillPaise` is derived with deterministic integer rounding
/// (round-half-up) — never floating-point currency math. Zero transactions
/// yields ₹0.00, never a divide-by-zero.
class ReportSummary {
  const ReportSummary({
    required this.totalSalesPaise,
    required this.transactionCount,
  });

  final int totalSalesPaise;
  final int transactionCount;

  /// `totalSalesPaise / transactionCount`, rounded to the nearest paise,
  /// or 0 when there are no transactions.
  int get averageBillPaise {
    if (transactionCount <= 0) return 0;
    // Round-half-up integer division (both operands non-negative).
    return (totalSalesPaise * 2 + transactionCount) ~/ (2 * transactionCount);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportSummary &&
          totalSalesPaise == other.totalSalesPaise &&
          transactionCount == other.transactionCount;

  @override
  int get hashCode => Object.hash(totalSalesPaise, transactionCount);
}
