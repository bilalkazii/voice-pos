import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/utils/money.dart';
import 'package:voice_pos/features/reports/domain/report_date_range.dart';
import 'package:voice_pos/features/reports/domain/report_summary.dart';

void main() {
  group('ReportDateRange.rangeFor (half-open, device-local)', () {
    // Fixed reference "now" for deterministic boundary assertions.
    final now = DateTime(2026, 9, 7, 15, 30);

    test('today is [00:00 today, 00:00 tomorrow)', () {
      final r = ReportDateRange.today.rangeFor(now);
      expect(r.start, DateTime(2026, 9, 7, 0, 0));
      expect(r.end, DateTime(2026, 9, 8, 0, 0));
    });

    test('yesterday is [00:00 yesterday, 00:00 today)', () {
      final r = ReportDateRange.yesterday.rangeFor(now);
      expect(r.start, DateTime(2026, 9, 6, 0, 0));
      expect(r.end, DateTime(2026, 9, 7, 0, 0));
    });

    test('last 7 days includes today and the six days before (inclusive of today)', () {
      final r = ReportDateRange.last7days.rangeFor(now);
      expect(r.start, DateTime(2026, 9, 1, 0, 0)); // today - 6 days
      expect(r.end, DateTime(2026, 9, 8, 0, 0)); // today + 1 day (exclusive)
    });

    test('a sale at 23:59 stays inside today; a sale at 00:00 next day does not', () {
      final today = ReportDateRange.today.rangeFor(now);
      final dayWithSale = DateTime(2026, 9, 7, 23, 59);
      final nextDayMidnight = DateTime(2026, 9, 8, 0, 0);
      expect(dayWithSale.isBefore(today.end), isTrue);
      expect(dayWithSale.isBefore(today.end) && dayWithSale.isAfter(today.start),
          isTrue);
      expect(nextDayMidnight.isBefore(today.end), isFalse);
    });
  });

  group('ReportSummary.averageBillPaise (integer paise', () {
    test('exact division', () {
      const s = ReportSummary(totalSalesPaise: 60000, transactionCount: 3);
      expect(s.averageBillPaise, 20000); // ₹200.00
    });

    test('rounds half-up to nearest paise', () {
      // ₹4,250.00 / 18 = ₹236.111... -> ₹236.11
      const s = ReportSummary(totalSalesPaise: 425000, transactionCount: 18);
      expect(s.averageBillPaise, 23611);
    });

    test('zero transactions returns 0 (no divide by zero)', () {
      const s = ReportSummary(totalSalesPaise: 0, transactionCount: 0);
      expect(s.averageBillPaise, 0);
    });

    test('single transaction equals the total', () {
      const s = ReportSummary(totalSalesPaise: 1050, transactionCount: 1);
      expect(s.averageBillPaise, 1050);
    });

    test('money stays integer paise', () {
      expect(Money.formatPaise(0), '₹0.00');
      expect(Money.formatPaise(1000), '₹10.00');
      expect(Money.formatPaise(1050), '₹10.50');
      expect(Money.formatPaise(10025), '₹100.25');
    });
  });
}
