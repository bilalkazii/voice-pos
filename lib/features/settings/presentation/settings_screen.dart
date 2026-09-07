import 'package:flutter/material.dart';

/// Phase 0 placeholder. Settings arrive in a later phase.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Text(
          'Settings arrive in a later phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
