import 'package:flutter/material.dart';

/// Phase 0 placeholder. Sales history arrives in a later phase.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Text(
          'Sales history arrives in a later phase.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
