import 'package:flutter/material.dart';

/// Phase 0 placeholder. Reports arrive in a later phase.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Center(
        child: Text(
          'Reports arrive in a later phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
