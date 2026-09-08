import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Start of the local-device day containing [now] (defaults to now).
/// Pure and deterministic — pass [now] in tests.
DateTime startOfToday([DateTime? now]) {
  final local = (now ?? DateTime.now()).toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Start of the current local day, refreshed just after each local
/// midnight so "Today" filters never go stale while the app stays open
/// across midnight.
///
/// A plain (non-autoDispose) provider like every other stream in the app.
/// Exactly one short-lived timer exists at a time and it fires once per
/// day, so there is no polling storm and no battery concern. The timer is
/// cancelled in `onDispose`, so nothing leaks past provider disposal.
class TodayStartNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    _schedule();
    return startOfToday();
  }

  void _schedule() {
    _timer?.cancel();
    final wait = startOfToday().add(const Duration(days: 1)).difference(
          DateTime.now(),
        ) +
        const Duration(seconds: 1);
    _timer = Timer(wait, () {
      if (!ref.mounted) return;
      state = startOfToday();
      _schedule();
    });
  }
}

final todayStartProvider =
    NotifierProvider<TodayStartNotifier, DateTime>(
  TodayStartNotifier.new,
);
