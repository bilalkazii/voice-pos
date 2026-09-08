import 'dart:async';

import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'bluetooth_transport.dart';

/// [BluetoothTransport] over Classic-Bluetooth SPP via
/// `print_bluetooth_thermal` (Android thermal printers; paired-device
/// listing needs no location permission).
///
/// Construction performs zero platform work — safe to build in tests and
/// widget trees; every method guards platform throws AND platform hangs
/// (found hanging on some API 37 devices) by bounding each quick plugin
/// call with [quickCallTimeout], degrading to `false`/empty. Runtime
/// permission is requested through `permission_handler` only when the user
/// starts setup or printing.
class SppBluetoothTransport implements BluetoothTransport {
  const SppBluetoothTransport({this.quickCallTimeout = const Duration(seconds: 5)});

  /// Bound for the cheap plugin queries. The platform channel has been
  /// observed to never return on some devices; without this the printer
  /// setup sheet would spin forever.
  final Duration quickCallTimeout;

  Future<bool> _bounded(Future<bool> Function() action) async {
    try {
      return await action().timeout(quickCallTimeout);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isBluetoothEnabled() =>
      _bounded(() => PrintBluetoothThermal.bluetoothEnabled);

  @override
  Future<bool> hasPermission() =>
      _bounded(() => PrintBluetoothThermal.isPermissionBluetoothGranted);

  @override
  Future<bool> requestPermission() async {
    try {
      // BLUETOOTH_CONNECT (Android 12+). On older releases this permission
      // does not exist and the handler reports it granted.
      final status = await Permission.bluetoothConnect.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<BluetoothPrinterDevice>> pairedDevices() async {
    try {
      final bonded = await PrintBluetoothThermal.pairedBluetooths
          .timeout(quickCallTimeout);
      return [
        for (final device in bonded)
          if (device.macAdress.trim().isNotEmpty)
            BluetoothPrinterDevice(
              name: device.name.trim().isEmpty
                  ? device.macAdress.trim()
                  : device.name.trim(),
              address: device.macAdress.trim(),
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      return await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> writeBytes(List<int> bytes) async {
    try {
      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }
}
