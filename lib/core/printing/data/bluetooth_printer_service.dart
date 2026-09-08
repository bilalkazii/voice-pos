import '../../../features/settings/domain/settings_repository.dart';
import '../bluetooth/bluetooth_transport.dart';
import '../domain/print_result.dart';
import '../domain/printer_service.dart';
import '../domain/receipt_data.dart';
import '../esc_pos/esc_pos_encoder.dart';

/// [PrinterService] over Classic-Bluetooth SPP for 58mm ESC/POS thermal
/// printers: Settings config → permission → availability → connect →
/// encode → write → disconnect. Connects per print job; never retains a
/// connection.
///
/// Checkout boundary (non-negotiable): this adapter only ever READS the
/// already-committed [ReceiptData]. It cannot roll back, recreate, or
/// re-deduct a sale — it holds no reference to checkout, cart, or the
/// database. [PrintSuccess] is returned only after the transport reports
/// the bytes written; every other outcome maps to [PrintUnavailable] (a
/// precondition: no config, no permission, BT off) or [PrintFailed].
class BluetoothPrinterService implements PrinterService {
  BluetoothPrinterService({
    required this.settings,
    required this.transport,
    this.encoder = const EscPosEncoder(),
    this.checkTimeout = const Duration(seconds: 5),
    this.connectTimeout = const Duration(seconds: 15),
    this.writeTimeout = const Duration(seconds: 20),
  });

  final SettingsRepository settings;
  final BluetoothTransport transport;
  final EscPosEncoder encoder;

  /// Bound for the cheap precondition queries (permission/availability) —
  /// the platform channel has been observed to hang on some devices.
  final Duration checkTimeout;
  final Duration connectTimeout;
  final Duration writeTimeout;

  @override
  Future<PrintResult> printReceipt(ReceiptData receipt) async {
    final String? address = await _configuredAddress();
    if (address == _loadFailed) {
      return const PrintFailed('Could not load printer configuration');
    }
    if (address == null) {
      return const PrintUnavailable('Printer not configured');
    }
    final bool permitted = await _guard(
      () => transport.hasPermission().timeout(checkTimeout),
    );
    if (!permitted) {
      final granted = await transport.requestPermission();
      if (!granted) {
        return const PrintUnavailable('Bluetooth permission denied');
      }
    }
    final bool enabled = await _guard(
      () => transport.isBluetoothEnabled().timeout(checkTimeout),
    );
    if (!enabled) {
      return const PrintUnavailable('Bluetooth is turned off');
    }

    final bool connected = await _guard(
      () => transport.connect(address).timeout(connectTimeout),
    );
    if (!connected) {
      return const PrintFailed('Could not connect to printer');
    }
    try {
      final bytes = encoder.encode(receipt);
      final bool written = await _guard(
        () => transport.writeBytes(bytes).timeout(writeTimeout),
      );
      if (!written) {
        return const PrintFailed('Failed to send data to printer');
      }
      return const PrintSuccess();
    } finally {
      // Cleanup must never mask the outcome or throw.
      await transport.disconnect();
    }
  }

  /// Reads the persisted printer address: null when unconfigured, and the
  /// [_loadFailed] sentinel when the settings database itself fails (so a
  /// storage failure surfaces as [PrintFailed], never as "unconfigured").
  Future<String?> _configuredAddress() async {
    try {
      final settingsData = await settings.load();
      final address = settingsData.selectedPrinterId;
      if (address == null || address.trim().isEmpty) return null;
      return address;
    } catch (_) {
      return _loadFailed;
    }
  }

  static const String _loadFailed = '__settings_load_failed__';

  /// Runs [action], converting timeouts and unexpected throws to false.
  Future<bool> _guard(Future<bool> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return false;
    }
  }
}
