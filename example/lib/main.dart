import 'package:easy_upgrade/easy_upgrade.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'easy_upgrade example',
      home: EasyUpgrade(
        // Enabled in debug so you can actually exercise this when running
        // `flutter run` against an app that's on the store.
        enabledInDebug: true,
        onCheck: (info) =>
            debugPrint('easy_upgrade check: severity=${info.severity}'),
        onError: (e, st) => debugPrint('easy_upgrade error: $e'),
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('easy_upgrade')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Auto-check runs on launch.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final info = await EasyUpgrade.checkNow();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('check: ${info?.severity}')),
                );
              },
              child: const Text('Check now'),
            ),
          ],
        ),
      ),
    );
  }
}
