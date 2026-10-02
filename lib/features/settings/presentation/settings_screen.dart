import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/printing/bluetooth/bluetooth_transport.dart';
import '../../../core/printing/domain/receipt_data.dart';
import '../../../core/printing/presentation/print_controller.dart';
import '../../../core/constants.dart';
import '../../../core/theme/tokens.dart';
import '../../voice/domain/voice_language.dart';
import '../domain/app_settings.dart';
import 'settings_providers.dart';

/// Settings & store configuration. All values persist locally in Drift;
/// the screen renders the live [settingsProvider] stream (loading spinner
/// until the first emission, error + retry on failure).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (s) => _SettingsBody(settings: s),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load settings.'),
                const SizedBox(height: AppTokens.space12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(settingsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.screenPadding),
      children: [
        _SectionTitle('Store'),
        const SizedBox(height: AppTokens.space8),
        _SettingsCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space4,
            ),
            leading: const Icon(Icons.store_outlined),
            title: const Text('Store Name'),
            subtitle: Text(settings.storeName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editStoreName(context, ref, settings.storeName),
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        _SectionTitle('Voice'),
        const SizedBox(height: AppTokens.space8),
        _SettingsCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space12,
                  vertical: AppTokens.space4,
                ),
                secondary: const Icon(Icons.mic_outlined),
                title: const Text('Voice Feedback'),
                subtitle:
                    const Text('Spoken confirmations for voice commands'),
                value: settings.voiceFeedbackEnabled,
                onChanged: (value) =>
                    _setVoiceFeedback(context, ref, value),
              ),
              const Divider(height: 1, indent: AppTokens.space12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space12,
                  vertical: AppTokens.space4,
                ),
                leading: const Icon(Icons.translate_outlined),
                title: const Text('Voice Language'),
                subtitle: Text(settings.voiceLanguage.label),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: () => _pickVoiceLanguage(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        _SectionTitle('Inventory'),
        const SizedBox(height: AppTokens.space8),
        _SettingsCard(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space4,
            ),
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Default Low Stock Threshold'),
            subtitle: Text(
              '${settings.defaultLowStockThreshold} (new products only)',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editThreshold(
              context,
              ref,
              settings.defaultLowStockThreshold,
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        _SectionTitle('Printer'),
        const SizedBox(height: AppTokens.space8),
        _PrinterSection(settings: settings),
        const SizedBox(height: AppTokens.space16),
        _SectionTitle('About'),
        const SizedBox(height: AppTokens.space8),
        const _SettingsCard(
          child: _AboutRow(),
        ),
        const SizedBox(height: AppTokens.space24),
      ],
    );
  }

  Future<void> _editStoreName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StoreNameDialog(current: current),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Store name saved.')),
      );
    }
  }

  Future<void> _editThreshold(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ThresholdDialog(current: current),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Threshold saved.')),
      );
    }
  }

  Future<void> _setVoiceFeedback(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .setVoiceFeedbackEnabled(enabled);
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    }
  }

  Future<void> _pickVoiceLanguage(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final chosen = await showDialog<VoiceLanguage>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Voice Language'),
        content: RadioGroup<VoiceLanguage>(
          groupValue: settings.voiceLanguage,
          onChanged: (value) {
            if (value != null) Navigator.of(context).pop(value);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final language in VoiceLanguage.values)
                RadioListTile<VoiceLanguage>(
                  title: Text(language.label),
                  value: language,
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !context.mounted) return;
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .setVoiceLanguage(chosen);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'Voice language saved.'),
      ),
    );
  }
}

/// Printer configuration section. Honest states only: a configured printer
/// means "selected for future prints", never "currently connected".
class _PrinterSection extends ConsumerWidget {
  const _PrinterSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = settings.selectedPrinterName;
    final address = settings.selectedPrinterId;
    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space12,
          vertical: AppTokens.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.print_outlined),
              title: const Text('Thermal Printer'),
              subtitle: address == null
                  ? const Text(
                      'Not configured\n'
                      'Pair your 58mm printer in Android Bluetooth settings, '
                      'then tap Set Up Printer.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name ?? address,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          address,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
              isThreeLine: address == null,
            ),
            if (address == null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _openSetup(context),
                  icon: const Icon(Icons.bluetooth_outlined),
                  label: const Text('SET UP PRINTER'),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _testPrint(context, ref),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('TEST PRINT'),
                  ),
                  TextButton.icon(
                    onPressed: () => _forget(context, ref),
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTokens.destructiveRed,
                    ),
                    label: const Text(
                      'FORGET',
                      style: TextStyle(color: AppTokens.destructiveRed),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSetup(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radiusSheet),
        ),
      ),
      builder: (_) => const _PrinterSetupSheet(),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer saved.')),
      );
    }
  }

  Future<void> _testPrint(BuildContext context, WidgetRef ref) async {
    // Synthetic test page through the real print path (config → encode →
    // transport). Zero totals keep it distinct from any real sale.
    final receipt = ReceiptData(
      storeName: ref.read(storeNameProvider),
      transactionNumber: 'TEST-PRINT',
      createdAt: DateTime.now(),
      paymentMethod: 'cash',
      subtotalPaise: 0,
      totalPaise: 0,
      items: const [],
    );
    final result = await ref
        .read(printControllerProvider.notifier)
        .printReceipt(receipt);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message.isEmpty ? 'Printed' : result.message,
          ),
        ),
      );
    }
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Forget printer?'),
        content: const Text(
          'The app will no longer attempt to print to this printer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTokens.destructiveRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .forgetPrinter();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failure?.message ?? 'Printer forgotten.'),
      ),
    );
  }
}

/// Bottom-sheet printer setup: permission → Bluetooth state → one-shot
/// paired-device list → select. No background scanning; one load on open
/// plus manual refresh. Never shows "Connected" — selection only.
class _PrinterSetupSheet extends ConsumerStatefulWidget {
  const _PrinterSetupSheet();

  @override
  ConsumerState<_PrinterSetupSheet> createState() =>
      _PrinterSetupSheetState();
}

enum _SetupPhase { checking, needPermission, bluetoothOff, error, ready }

class _PrinterSetupSheetState extends ConsumerState<_PrinterSetupSheet> {
  _SetupPhase _phase = _SetupPhase.checking;
  List<BluetoothPrinterDevice> _devices = const [];
  String _error = '';
  bool _saving = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  BluetoothTransport get _transport =>
      ref.read(bluetoothTransportProvider);

  Future<void> _load() async {
    setState(() {
      _phase = _SetupPhase.checking;
      _error = '';
    });
    final transport = _transport;
    final granted = await transport.hasPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() => _phase = _SetupPhase.needPermission);
      return;
    }
    await _loadDevices(transport);
  }

  Future<void> _loadDevices(BluetoothTransport transport) async {
    if (!await transport.isBluetoothEnabled()) {
      if (!mounted) return;
      setState(() => _phase = _SetupPhase.bluetoothOff);
      return;
    }
    try {
      final devices = await transport.pairedDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _phase = _SetupPhase.ready;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = _SetupPhase.error;
        _error = 'Could not list paired printers.';
        _refreshing = false;
      });
    }
  }

  Future<void> _grantPermission() async {
    final granted = await _transport.requestPermission();
    if (!mounted) return;
    if (granted) {
      await _load();
    } else {
      setState(() {
        _phase = _SetupPhase.error;
        _error = 'Bluetooth permission denied. '
            'Printing needs it to reach paired printers.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _loadDevices(_transport);
  }

  Future<void> _select(BluetoothPrinterDevice device) async {
    if (_saving) return;
    setState(() => _saving = true);
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .savePrinterSelection(address: device.address, name: device.name);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _phase = _SetupPhase.error;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set Up Printer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTokens.space4),
            const Text(
              'Pair your 58mm thermal printer in Android Bluetooth '
              'settings first, then select it below.',
            ),
            const SizedBox(height: AppTokens.space12),
            Flexible(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _SetupPhase.checking:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(AppTokens.space24),
            child: CircularProgressIndicator(),
          ),
        );
      case _SetupPhase.needPermission:
        return _MessageAction(
          message: 'Bluetooth permission is needed to list paired printers.',
          actionLabel: 'GRANT PERMISSION',
          onAction: _grantPermission,
        );
      case _SetupPhase.bluetoothOff:
        return _MessageAction(
          message: 'Bluetooth is turned off. Turn it on, then retry.',
          actionLabel: 'RETRY',
          onAction: _refresh,
        );
      case _SetupPhase.error:
        return _MessageAction(
          message: _error,
          actionLabel: 'RETRY',
          onAction: _load,
        );
      case _SetupPhase.ready:
        if (_devices.isEmpty) {
          return _MessageAction(
            message: 'No paired printers found. Pair your printer in '
                'Android Bluetooth settings first.',
            actionLabel: _refreshing ? 'REFRESHING…' : 'REFRESH',
            onAction: _refreshing ? null : _refresh,
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: _devices.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: AppTokens.space8),
          itemBuilder: (context, index) {
            final device = _devices[index];
            return Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                enabled: !_saving,
                leading: const Icon(Icons.print_outlined),
                title: Text(device.name),
                subtitle: Text(device.address),
                trailing: _saving
                    ? const SizedBox(
                        width: AppTokens.iconSmall,
                        height: AppTokens.iconSmall,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _saving ? null : () => _select(device),
              ),
            );
          },
        );
    }
  }
}

class _MessageAction extends StatelessWidget {
  const _MessageAction({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: AppTokens.space12),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Store-name editor. Owns its [TextEditingController] so disposal always
/// pairs with the dialog route lifecycle — never reused after dispose.
class _StoreNameDialog extends ConsumerStatefulWidget {
  const _StoreNameDialog({required this.current});

  final String current;

  @override
  ConsumerState<_StoreNameDialog> createState() => _StoreNameDialogState();
}

class _StoreNameDialogState extends ConsumerState<_StoreNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.current);
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = '';
    });
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .saveStoreName(_controller.text);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Store Name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: AppSettings.maxStoreNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'e.g. Bilal General Store',
          errorText: _error.isEmpty ? null : _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

/// Default-threshold editor. Owns its controller, like [_StoreNameDialog].
class _ThresholdDialog extends ConsumerStatefulWidget {
  const _ThresholdDialog({required this.current});

  final int current;

  @override
  ConsumerState<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends ConsumerState<_ThresholdDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.current}');
  String _error = '';
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0) {
      setState(() {
        _error = 'Enter a non-negative whole number.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    final failure = await ref
        .read(settingsControllerProvider.notifier)
        .setDefaultLowStockThreshold(parsed);
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _saving = false;
        _error = failure.message;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Default Low Stock Threshold'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Applies to new products only.'),
          const SizedBox(height: AppTokens.space8),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: 'e.g. 5',
              errorText: _error.isEmpty ? null : _error,
            ),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: child,
    );
  }
}

/// App name + runtime package version + package id. Falls back to the
/// compiled constants when platform info is unavailable (e.g. widget
/// tests), so the row never renders empty.
class _AboutRow extends StatelessWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _loadPackageInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppTokens.space12,
            vertical: AppTokens.space4,
          ),
          leading: const Icon(Icons.info_outline),
          title: Text(AppConstants.appName),
          subtitle: Text(
            'Version ${info?.version ?? AppConstants.appVersion}\n'
            '${info?.packageName ?? AppConstants.applicationId}',
          ),
          isThreeLine: true,
        );
      },
    );
  }

  Future<PackageInfo> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return PackageInfo(
        appName: AppConstants.appName,
        packageName: AppConstants.applicationId,
        version: AppConstants.appVersion,
        buildNumber: '',
      );
    }
  }
}
