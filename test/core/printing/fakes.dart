import 'dart:async';

import 'package:voice_pos/core/printing/bluetooth/bluetooth_transport.dart';
import 'package:voice_pos/core/printing/domain/print_result.dart';
import 'package:voice_pos/core/printing/domain/printer_service.dart';
import 'package:voice_pos/core/printing/domain/receipt_data.dart';

/// Deterministic fake printer service: plays back one scripted result per
/// call and records every receipt. Has no checkout/cart/database reference,
/// so it cannot create or mutate a sale by construction.
class FakePrinterService implements PrinterService {
  FakePrinterService(this.script);

  final List<PrintResult> script;
  final List<ReceiptData> printed = [];

  int get calls => printed.length;

  @override
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    printed.add(receipt);
    if (script.isEmpty) return const PrintFailed('No scripted result');
    return script.removeAt(0);
  }
}

/// Deterministic fake transport: every behavior is scripted, every call is
/// recorded. Hanging futures (never completing) model timeouts without any
/// sleeping — the adapter's own `.timeout()` bounds them.
class FakeBluetoothTransport implements BluetoothTransport {
  FakeBluetoothTransport({
    this.permissionGranted = true,
    this.bluetoothOn = true,
    this.paired = const [],
    this.connectResults = const [],
    this.writeResults = const [],
    this.hangConnect = false,
    this.hangWrite = false,
    this.throwOnWrite = false,
  });

  bool permissionGranted;
  bool bluetoothOn;
  List<BluetoothPrinterDevice> paired;
  List<bool> connectResults;
  List<bool> writeResults;
  bool hangConnect;
  bool hangWrite;
  bool throwOnWrite;

  int permissionRequests = 0;
  int connects = 0;
  int disconnects = 0;
  final List<List<int>> writtenBatches = [];
  String? lastConnectedAddress;

  @override
  Future<bool> isBluetoothEnabled() async => bluetoothOn;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permissionGranted;
  }

  @override
  Future<List<BluetoothPrinterDevice>> pairedDevices() async =>
      List.of(paired);

  @override
  Future<bool> connect(String address) async {
    connects++;
    lastConnectedAddress = address;
    if (hangConnect) return Completer<bool>().future;
    if (connectResults.isEmpty) return true;
    return connectResults.removeAt(0);
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    writtenBatches.add(List.of(bytes));
    if (hangWrite) return Completer<bool>().future;
    if (throwOnWrite) throw StateError('transport blew up');
    if (writeResults.isEmpty) return true;
    return writeResults.removeAt(0);
  }

  @override
  Future<void> disconnect() async {
    disconnects++;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }
}
