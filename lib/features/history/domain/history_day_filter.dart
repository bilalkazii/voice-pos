/// History date filter. V1 keeps it minimal: everything or just today.
/// A future phase can add arbitrary date ranges without redesign — the
/// provider only needs the start-of-day instant.
enum HistoryDayFilter {
  all,
  today;

  String get label => switch (this) {
        HistoryDayFilter.all => 'All',
        HistoryDayFilter.today => 'Today',
      };
}
