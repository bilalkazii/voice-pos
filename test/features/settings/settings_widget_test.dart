import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/core/errors/failures.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';
import 'package:voice_pos/features/settings/domain/app_settings.dart';
import 'package:voice_pos/features/settings/domain/settings_repository.dart';
import 'package:voice_pos/features/settings/presentation/settings_providers.dart';

import '../../test_utils.dart';

Future<AppDatabase> pumpSettings(
  WidgetTester tester, {
  Future<void> Function(SettingsRepository repo)? seed,
}) async {
  final db = openTestDb();
  if (seed != null) {
    await seed(DriftSettingsRepository(db.settingsDao));
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  await tester.tap(find.text('Settings').first);
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  return db;
}

/// Repository that fails every write — proves save errors surface instead
/// of being silently lost.
class _FailingSettingsRepository implements SettingsRepository {
  _FailingSettingsRepository(this._real);

  final SettingsRepository _real;

  @override
  Future<AppSettings> load() => _real.load();

  @override
  Stream<AppSettings> watch() => _real.watch();

  @override
  Future<void> saveStoreName(String name) async {
    AppSettings.validateStoreName(name);
    throw const DatabaseFailure(message: 'Could not save settings.');
  }

  @override
  Future<void> setVoiceFeedbackEnabled(bool enabled) =>
      _real.setVoiceFeedbackEnabled(enabled);

  @override
  Future<void> setDefaultLowStockThreshold(int threshold) =>
      _real.setDefaultLowStockThreshold(threshold);

  @override
  Future<void> setPrinterSelection({String? id, String? name}) =>
      _real.setPrinterSelection(id: id, name: name);
}

void main() {
  group('settings screen', () {
    testWidgets('shows loading spinner on first frame', (tester) async {
      final db = openTestDb();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const VoicePosApp(),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('Settings').first);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await pumpStreams(tester);
      await disposeAndCloseDb(tester, db);
    });

    testWidgets('renders sections with current values', (tester) async {
      final db = await pumpSettings(tester);

      expect(find.text('Settings'), findsWidgets);
      expect(find.text('Store Name'), findsOneWidget);
      expect(find.text('My Store'), findsOneWidget);
      expect(find.text('Voice Feedback'), findsOneWidget);
      expect(find.text('Default Low Stock Threshold'), findsOneWidget);
      expect(find.text('5 (new products only)'), findsOneWidget);
      expect(find.text('Thermal Printer'), findsOneWidget);
      // Subtitle is one Text with a newline; match by substring.
      expect(find.textContaining('Not configured'), findsOneWidget);
      expect(
        find.textContaining(
          'Pair your 58mm printer in Android Bluetooth settings, '
          'then tap Set Up Printer.',
        ),
        findsOneWidget,
      );
      expect(find.text('Voice POS'), findsNothing);
      // About section lives below the fold of the lazy list — scroll
      // until it builds, then assert.
      final aboutFinder = find.textContaining('Version ');
      await tester.scrollUntilVisible(aboutFinder, 400);
      await tester.pumpAndSettle();
      expect(find.text('Voice POS'), findsOneWidget);
      expect(aboutFinder, findsOneWidget);
      expect(find.textContaining('com.mizaantech.voice_pos'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('store name can be changed and persists', (tester) async {
      final db = await pumpSettings(tester);

      await tester.tap(find.text('Store Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bilal General Store');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Store name saved.'), findsOneWidget);
      expect(find.text('Bilal General Store'), findsOneWidget);
      final repo = DriftSettingsRepository(db.settingsDao);
      expect((await repo.load()).storeName, 'Bilal General Store');

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('blank store name shows validation, keeps old value',
        (tester) async {
      final db = await pumpSettings(tester);

      await tester.tap(find.text('Store Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Store name cannot be blank.'), findsOneWidget);
      final repo = DriftSettingsRepository(db.settingsDao);
      expect((await repo.load()).storeName, 'My Store');

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('voice feedback toggle flips and persists', (tester) async {
      final db = await pumpSettings(tester);
      final repo = DriftSettingsRepository(db.settingsDao);
      expect((await repo.load()).voiceFeedbackEnabled, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect((await repo.load()).voiceFeedbackEnabled, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect((await repo.load()).voiceFeedbackEnabled, isTrue);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('threshold can be changed, validates, and persists',
        (tester) async {
      final db = await pumpSettings(tester);

      await tester.tap(find.text('Default Low Stock Threshold'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Threshold saved.'), findsOneWidget);
      expect(find.text('12 (new products only)'), findsOneWidget);
      final repo = DriftSettingsRepository(db.settingsDao);
      expect((await repo.load()).defaultLowStockThreshold, 12);

      // Empty input is rejected with an inline error.
      await tester.tap(find.text('Default Low Stock Threshold'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a non-negative whole number.'),
        findsOneWidget,
      );
      expect((await repo.load()).defaultLowStockThreshold, 12);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('save failure surfaces an error instead of losing data',
        (tester) async {
      final db = openTestDb();
      final real = DriftSettingsRepository(db.settingsDao);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(
              _FailingSettingsRepository(real),
            ),
          ],
          child: const VoicePosApp(),
        ),
      );
      await pumpStreams(tester);
      await tester.tap(find.text('Settings').first);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      await tester.tap(find.text('Store Name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Shop That Fails');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save settings.'), findsOneWidget);
      expect((await real.load()).storeName, 'My Store');

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('no destructive settings actions exist', (tester) async {
      final db = await pumpSettings(tester);

      expect(find.text('Delete'), findsNothing);
      expect(find.text('Reset'), findsNothing);
      expect(find.text('Clear data'), findsNothing);
      expect(find.text('Wipe'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });
  });
}
