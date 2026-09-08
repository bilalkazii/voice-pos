import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants.dart';
import '../../../core/theme/tokens.dart';
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
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space4,
            ),
            secondary: const Icon(Icons.mic_outlined),
            title: const Text('Voice Feedback'),
            subtitle: const Text('Spoken confirmations for voice commands'),
            value: settings.voiceFeedbackEnabled,
            onChanged: (value) =>
                _setVoiceFeedback(context, ref, value),
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
        const _SettingsCard(
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppTokens.space12,
              vertical: AppTokens.space4,
            ),
            leading: Icon(Icons.print_outlined),
            title: Text('Thermal Printer'),
            subtitle: Text(
              'Not configured\n'
              'Printer support will be available when hardware '
              'integration is enabled.',
            ),
            isThreeLine: true,
          ),
        ),
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
