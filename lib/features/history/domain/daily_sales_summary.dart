/// Compact per-day sales summary for the History card. Integer paise.
/// Derived from the day's committed sales — never a second write path.
class DailySalesSummary {
  const DailySalesSummary({required this.transactionCount, required this.totalPaise});

  final int transactionCount;
  final int totalPaise;

  bool get isEmpty => transactionCount == 0;
}
