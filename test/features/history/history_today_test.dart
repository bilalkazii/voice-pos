import 'dart:async';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/core/utils/today.dart';
import 'package:voice_pos/features/history/domain/history_day_filter.dart';
import 'package:voice_pos/features/history/presentation/history_providers.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/reports/domain/report_date_range.dart';
import 'package:voice_pos/features/reports/presentation/reports_providers.dart';

AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Seeds one sale with an explicit creation timestamp.
Future<void> seedSaleAt(
  AppDatabase db,
  String transactionNumber,
  DateTime createdAt,
) async {
  final productId = await db.productDao.create(
    ProductsCompanion.insert(name: 'Pepsi $transactionNumber', sellingPricePaise: 1000),
  );
  final saleId = await db.saleDao.createSale(
    SalesCompanion.insert(
      transactionNumber: transactionNumber,
      paymentMethod: 'cash',
      subtotalPaise: 1000,
      totalPaise: 1000,
      createdAt: Value(createdAt),
    ),
  );
  await db.saleDao.createSaleItems([
    SaleItemsCompanion.insert(
      saleId: saleId,
      productId: productId,
      productName: 'Pepsi $transactionNumber',
      unitPricePaise: 1000,
      quantity: 1,
      lineTotalPaise: 1000,
    ),
  ]);
}

/// First data emission of a stream provider, cancelling afterwards.
Future<T> firstData<T>(
  ProviderContainer container,
  StreamProvider<T> provider,
) {
  final completer = Completer<T>();
  late final ProviderSubscription<AsyncValue<T>> sub;
  sub = container.listen<AsyncValue<T>>(
    provider,
    (previous, next) {
      next.whenData((value) {
        if (!completer.isCompleted) {
          completer.complete(value);
          sub.close();
        }
      });
    },
  );
  return completer.future.timeout(const Duration(seconds: 10));
}

/// Fixed day-start with no timer — deterministic stand-in for
/// [TodayStartNotifier] (which would otherwise schedule a day-long timer).
class _FixedDay extends TodayStartNotifier {
  _FixedDay(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

void main() {
  group('startOfToday', () {
    test('returns local midnight for the given instant', () {
      expect(
        startOfToday(DateTime(2026, 9, 7, 23, 59, 59)),
        DateTime(2026, 9, 7, 0, 0),
      );
      expect(
        startOfToday(DateTime(2026, 9, 8, 0, 0, 0)),
        DateTime(2026, 9, 8, 0, 0),
      );
    });
  });

  group('reportRangeProvider follows the day boundary, not wall-clock', () {
    test('today/yesterday resolve against the overridden day', () {
      final container = ProviderContainer(
        overrides: [
          todayStartProvider.overrideWith(() => _FixedDay(DateTime(2026, 9, 7))),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(reportRangeProvider),
        (
          start: DateTime(2026, 9, 7),
          end: DateTime(2026, 9, 8),
        ),
      );

      container.read(reportDateRangeProvider.notifier).set(
            ReportDateRange.yesterday,
          );
      expect(
        container.read(reportRangeProvider),
        (
          start: DateTime(2026, 9, 6),
          end: DateTime(2026, 9, 7),
        ),
      );
    });
  });

  group('history Today filter follows the day boundary', () {
    test('sales move in/out of Today as the day rolls over', () async {
      // Sale A happened on Sep 7, sale B on Sep 6.
      Future<ProviderContainer> openAt(DateTime day) async {
        final db = openTestDb();
        await seedSaleAt(db, 'VP-A', DateTime(2026, 9, 7, 10));
        await seedSaleAt(db, 'VP-B', DateTime(2026, 9, 6, 10));
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            todayStartProvider.overrideWith(() => _FixedDay(day)),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        container
            .read(historyDayFilterProvider.notifier)
            .set(HistoryDayFilter.today);
        return container;
      }

      final beforeMidnight = await openAt(DateTime(2026, 9, 7));
      final todaysSales = await firstData(beforeMidnight, historySalesProvider);
      expect(
        todaysSales.map((s) => s.transactionNumber),
        ['VP-A'],
      );

      // Same database content, but the app is now "open" on Sep 8:
      // only the Sep-8 sale (none) qualifies — VP-A must NOT leak in from
      // a stale yesterday boundary.
      final afterMidnight = await openAt(DateTime(2026, 9, 8));
      final nextDaySales = await firstData(afterMidnight, historySalesProvider);
      expect(nextDaySales, isEmpty);
    });
  });
}
