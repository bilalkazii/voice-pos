/// A paired Classic-Bluetooth printer as reported by the platform:
/// display [name] plus the stable [address] (MAC) used to reconnect.
class BluetoothPrinterDevice {
  const BluetoothPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothPrinterDevice &&
          name == other.name &&
          address == other.address;

  @override
  int get hashCode => Object.hash(name, address);

  @override
  String toString() => 'BluetoothPrinterDevice(name: $name, address: $address)';
}

/// Narrow Classic-Bluetooth (SPP) transport for thermal printers. Pure
/// interface — the app only ever programs against this, so tests inject a
/// fake and no test needs Bluetooth hardware.
///
/// Contract: methods return plain results and never throw for EXPECTED
/// conditions (denied permission, BT off, no devices, connect/write
/// failure all surface as `false`/empty). Unexpected platform throws may
/// propagate; the [PrinterService] adapter converts them to [PrintFailed].
///
/// No background scanning: [pairedDevices] is a one-shot read of already
/// paired devices. Connections are short-lived per print job; [dispose]
/// releases anything held.
abstract class BluetoothTransport {
  /// Whether the platform reports Bluetooth as available and turned on.
  Future<bool> isBluetoothEnabled();

  /// Whether the runtime Bluetooth permission needed to operate is held.
  Future<bool> hasPermission();

  /// Requests the runtime Bluetooth permission. Returns true when granted.
  /// Never loops: a denial returns false exactly once per call.
  Future<bool> requestPermission();

  /// Already-paired devices (one-shot, no discovery scan).
  Future<List<BluetoothPrinterDevice>> pairedDevices();

  /// Opens an SPP connection to [address]. Returns true on success.
  Future<bool> connect(String address);

  /// Writes already-encoded bytes to the open connection.
  Future<bool> writeBytes(List<int> bytes);

  /// Closes the connection if open. Best-effort; never throws.
  Future<void> disconnect();

  /// Releases transport resources. Best-effort; never throws.
  Future<void> dispose();
}
