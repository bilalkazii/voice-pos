import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_pos/app.dart';
import 'package:voice_pos/core/db/app_database.dart';
import 'package:voice_pos/core/printing/bluetooth/bluetooth_transport.dart';
import 'package:voice_pos/core/printing/presentation/print_controller.dart';
import 'package:voice_pos/features/products/presentation/products_providers.dart';
import 'package:voice_pos/features/settings/data/settings_repository_impl.dart';

import '../../test_utils.dart';
import '../../core/printing/fakes.dart';

const officePrinter = BluetoothPrinterDevice(
  name: 'Office-T58',
  address: '66:02:BD:06:18:7B',
);
const shopPrinter = BluetoothPrinterDevice(
  name: 'Shop-T58',
  address: '00:11:22:33:44:55',
);

/// Full app with an in-memory database and a scripted fake transport.
Future<AppDatabase> pumpSettings(
  WidgetTester tester, {
  FakeBluetoothTransport? transport,
}) async {
  final db = openTestDb();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (transport != null)
          bluetoothTransportProvider.overrideWithValue(transport),
      ],
      child: const VoicePosApp(),
    ),
  );
  await pumpStreams(tester);
  await tester.tap(find.text('Settings').first);
  await tester.pumpAndSettle();
  await pumpStreams(tester);
  return db;
}

Future<void> openSetup(WidgetTester tester) async {
  final setupButton = find.widgetWithText(TextButton, 'SET UP PRINTER');
  await tester.scrollUntilVisible(setupButton, 400);
  await tester.pumpAndSettle();
  await tester.tap(setupButton);
  await tester.pumpAndSettle();
  await pumpStreams(tester);
}

void main() {
  group('printer setup flow', () {
    testWidgets('unconfigured state offers setup', (tester) async {
      final db = await pumpSettings(
        tester,
        transport: FakeBluetoothTransport(),
      );

      expect(find.text('Thermal Printer'), findsOneWidget);
      expect(find.textContaining('Not configured'), findsOneWidget);
      expect(find.text('SET UP PRINTER'), findsOneWidget);
      expect(find.text('TEST PRINT'), findsNothing);
      expect(find.text('FORGET'), findsNothing);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('lists paired printers and saves the selection',
        (tester) async {
      final transport = FakeBluetoothTransport(
        paired: [officePrinter, shopPrinter],
      );
      final db = await pumpSettings(tester, transport: transport);
      await openSetup(tester);

      expect(find.text('Set Up Printer'), findsOneWidget);
      expect(find.text('Office-T58'), findsOneWidget);
      expect(find.text('66:02:BD:06:18:7B'), findsOneWidget);
      expect(find.text('Shop-T58'), findsOneWidget);

      await tester.tap(find.text('Shop-T58'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Printer saved.'), findsOneWidget);
      expect(find.text('Shop-T58'), findsOneWidget);
      expect(find.text('00:11:22:33:44:55'), findsOneWidget);
      expect(find.text('TEST PRINT'), findsOneWidget);
      expect(find.text('FORGET'), findsOneWidget);

      final loaded =
          await DriftSettingsRepository(db.settingsDao).load();
      expect(loaded.selectedPrinterId, '00:11:22:33:44:55');
      expect(loaded.selectedPrinterName, 'Shop-T58');

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('empty paired list explains pairing with refresh',
        (tester) async {
      final db = await pumpSettings(
        tester,
        transport: FakeBluetoothTransport(paired: const []),
      );
      await openSetup(tester);

      expect(find.textContaining('No paired printers found.'), findsOneWidget);
      expect(find.text('REFRESH'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('permission denied stays honest without looping',
        (tester) async {
      final transport = FakeBluetoothTransport(permissionGranted: false);
      final db = await pumpSettings(tester, transport: transport);
      await openSetup(tester);

      expect(
        find.text(
          'Bluetooth permission is needed to list paired printers.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'GRANT PERMISSION'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      // Denied again: honest error, exactly one request per tap, no loop.
      expect(find.textContaining('permission denied'), findsOneWidget);
      expect(transport.permissionRequests, 1);
      expect(find.text('RETRY'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('bluetooth off shows retry state', (tester) async {
      final db = await pumpSettings(
        tester,
        transport: FakeBluetoothTransport(bluetoothOn: false),
      );
      await openSetup(tester);

      expect(find.textContaining('turned off'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('forget clears back to unconfigured', (tester) async {
      final transport = FakeBluetoothTransport(paired: [officePrinter]);
      final db = await pumpSettings(tester, transport: transport);
      await openSetup(tester);
      await tester.tap(find.text('Office-T58'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);
      expect(find.text('TEST PRINT'), findsOneWidget);
      // Let the save-confirmation snackbar expire so the forget
      // confirmation snackbar is the visible one below.
      await expireSnackbars(tester);

      final forgetButton = find.text('FORGET');
      await tester.scrollUntilVisible(forgetButton, 400);
      await tester.pumpAndSettle();
      await tester.tap(forgetButton);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Forget'));
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Printer forgotten.'), findsOneWidget);
      expect(find.textContaining('Not configured'), findsOneWidget);
      expect(
        (await DriftSettingsRepository(db.settingsDao).load())
            .hasPrinterConfigured,
        isFalse,
      );

      await disposeAndCloseDb(tester, db);
    });
  });

  group('test print', () {
    testWidgets('successful test print reports Printed', (tester) async {
      final transport = FakeBluetoothTransport();
      final db = await pumpSettings(tester, transport: transport);
      await DriftSettingsRepository(db.settingsDao).setPrinterSelection(
        id: officePrinter.address,
        name: officePrinter.name,
      );
      await tester.pump();
      await pumpStreams(tester);

      final testPrintButton = find.text('TEST PRINT');
      await tester.scrollUntilVisible(testPrintButton, 400);
      await tester.pumpAndSettle();
      await tester.tap(testPrintButton);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Printed'), findsOneWidget);
      expect(transport.connects, 1);
      expect(transport.writtenBatches.length, 1);
      expect(transport.disconnects, 1);

      await disposeAndCloseDb(tester, db);
    });

    testWidgets('failed test print reports the failure, config intact',
        (tester) async {
      final transport = FakeBluetoothTransport(writeResults: [false]);
      final db = await pumpSettings(tester, transport: transport);
      await DriftSettingsRepository(db.settingsDao).setPrinterSelection(
        id: officePrinter.address,
        name: officePrinter.name,
      );
      await tester.pump();
      await pumpStreams(tester);

      final retryPrintButton = find.text('TEST PRINT');
      await tester.scrollUntilVisible(retryPrintButton, 400);
      await tester.pumpAndSettle();
      await tester.tap(retryPrintButton);
      await tester.pumpAndSettle();
      await pumpStreams(tester);

      expect(find.text('Failed to send data to printer'), findsOneWidget);
      expect(find.text('Office-T58'), findsOneWidget);

      await disposeAndCloseDb(tester, db);
    });
  });
}
