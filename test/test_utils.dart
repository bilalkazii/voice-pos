import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/core/db/app_database.dart';

/// Shared widget-test helpers for Drift-backed screens.
///
/// Background: Drift keeps `watch()` stream caches alive with an internal
/// zero-duration Timer after the last listener cancels, and `AppDatabase`
/// itself is a `StreamQueryStore` owner. Under `testWidgets`' FakeAsync
/// zone that timer only fires on pump, so:
/// - NEVER `await db.close()` with no pump running (it hangs), and never
///   rely on `addTearDown(db.close)` (teardowns run after the framework's
///   pending-timer verification).
/// - NEVER `pumpAndSettle()` while a loading spinner may be on screen —
///   use [pumpStreams] instead.
///
/// The recipe in [disposeAndCloseDb] (dispose tree → pump until close
/// completes) satisfies all three constraints.

/// Opens a fresh in-memory database. The caller MUST pass it to
/// [disposeAndCloseDb] at the end of the test — never `addTearDown`.
AppDatabase openTestDb() => AppDatabase(NativeDatabase.memory());

/// Flushes pending stream emissions (data arrives within a pump or two;
/// extra pumps are a cheap safety margin).
Future<void> pumpStreams(
  WidgetTester tester, {
  int rounds = 5,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.pump(step);
  }
}

/// End-of-test teardown for Drift widget tests: disposes the widget tree
/// (cancelling stream subscriptions), pumps until `db.close()` completes,
/// then pumps once more so no timer is pending at verification.
Future<void> disposeAndCloseDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(Container());
  var closed = false;
  final closeFuture = db.close().then((_) => closed = true);
  for (var i = 0; i < 50 && !closed; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await closeFuture;
  await tester.pump();
}
