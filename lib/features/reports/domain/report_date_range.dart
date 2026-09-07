/// Simple device-local report date ranges for the dashboard. V1 keeps this
/// minimal; a future Custom picker can extend the enum without redesigning
/// the consumers (which only ever ask for [rangeFor]).
enum ReportDateRange {
  today,
  yesterday,
  last7days;

  String get label => switch (this) {
        ReportDateRange.today => 'Today',
        ReportDateRange.yesterday => 'Yesterday',
        ReportDateRange.last7days => 'Last 7 Days',
      };

  /// Resolves this range against a local [now] into a half-open interval:
  /// `start` inclusive, `end` exclusive. This avoids end-of-day timestamp
  /// bugs (a sale at 23:59 stays inside the day; a sale at the next day
  /// 00:00 belongs to the following range).
  ({DateTime start, DateTime end}) rangeFor(DateTime now) {
    final local = now.toLocal();
    final todayMidnight = DateTime(local.year, local.month, local.day);
    return switch (this) {
      ReportDateRange.today => (
          start: todayMidnight,
          end: todayMidnight.add(const Duration(days: 1)),
        ),
      ReportDateRange.yesterday => (
          start: todayMidnight.subtract(const Duration(days: 1)),
          end: todayMidnight,
        ),
      ReportDateRange.last7days => (
          start: todayMidnight.subtract(const Duration(days: 6)),
          end: todayMidnight.add(const Duration(days: 1)),
        ),
    };
  }
}
